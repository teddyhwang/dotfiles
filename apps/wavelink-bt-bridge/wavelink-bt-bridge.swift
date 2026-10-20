// wavelink-bt-bridge plays an Elgato Wave Link mix on a Bluetooth output.
//
// Wave Link 3.3 and later cannot use an output that runs at 44.1 kHz, which is
// the rate macOS uses for most Bluetooth headphones. Wave Link still publishes
// each mix as a 48 kHz virtual input device, such as "Elgato Wave Link
// Personal Mix". This helper reads that device, converts it to the rate of the
// headset, corrects the drift between the two clocks and plays the result on
// the headset.
//
// Wave Link captures app audio with a process tap on the macOS default output
// device. If the headset were the default output, Wave Link would also capture
// and mute the output of this helper and feed it back into the mix. While the
// bridge runs, the helper therefore moves the default output to another device.
// It moves the default output back when the bridge stops.
//
// The signal path follows Apple's CAPlayThrough sample: an IOProc on the input
// device writes into a ring buffer, and a Varispeed unit reads the ring buffer
// and feeds an AUHAL output unit. AUHAL converts the sample rate; Varispeed
// changes the playback rate slightly to keep the ring buffer at its target.

import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation
import Synchronization

// MARK: - Logging

let timestampFormatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  formatter.timeZone = .current
  return formatter
}()

func log(_ message: String) {
  print("\(timestampFormatter.string(from: Date())) \(message)")
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("wavelink-bt-bridge: \(message)\n".utf8))
  exit(2)
}

struct BridgeError: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}

func check(_ status: OSStatus, _ what: String) throws {
  guard status == noErr else {
    throw BridgeError("\(what) failed (OSStatus \(status), \(fourCC(UInt32(bitPattern: status))))")
  }
}

func fourCC(_ value: UInt32) -> String {
  let bytes = [24, 16, 8, 0].map { UInt8((value >> UInt32($0)) & 0xff) }
  guard bytes.allSatisfy({ $0 >= 32 && $0 < 127 }) else { return String(value) }
  return String(decoding: bytes, as: UTF8.self)
}

// MARK: - CoreAudio properties

enum HAL {
  static let system = AudioObjectID(kAudioObjectSystemObject)

  static func address(_ selector: AudioObjectPropertySelector,
                      _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
  }

  static func value<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                       scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, default fallback: T) -> T {
    var address = address(selector, scope)
    var result = fallback
    var size = UInt32(MemoryLayout<T>.size)
    let status = withUnsafeMutablePointer(to: &result) { AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0) }
    return status == noErr ? result : fallback
  }

  static func array<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                       scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, of _: T.Type) -> [T] {
    var address = address(selector, scope)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
    let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<T>.alignment)
    defer { buffer.deallocate() }
    guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, buffer) == noErr else { return [] }
    let count = Int(size) / MemoryLayout<T>.stride
    return Array(UnsafeBufferPointer(start: buffer.bindMemory(to: T.self, capacity: count), count: count))
  }

  static func string(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var address = address(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0) }
    guard status == noErr, let string = value?.takeRetainedValue() else { return nil }
    return string as String
  }

  static func streamFormats(_ device: AudioObjectID, _ scope: AudioObjectPropertyScope) -> [AudioStreamBasicDescription] {
    array(device, kAudioDevicePropertyStreams, scope: scope, of: AudioStreamID.self).map {
      value($0, kAudioStreamPropertyVirtualFormat, default: AudioStreamBasicDescription())
    }
  }
}

/// A snapshot of one audio device. The sample rate and buffer size are read
/// live, because the supervisor compares them with the running bridge.
struct Device: Equatable {
  let id: AudioObjectID
  let uid: String
  let name: String
  let transport: UInt32
  let inputChannels: Int
  let outputChannels: Int
  let isAlive: Bool

  var isBluetooth: Bool {
    transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
  }
  var isVirtual: Bool {
    transport == kAudioDeviceTransportTypeVirtual || transport == kAudioDeviceTransportTypeAggregate ||
      transport == kAudioDeviceTransportTypeAutoAggregate
  }
  var nominalRate: Double { HAL.value(id, kAudioDevicePropertyNominalSampleRate, default: 0.0) }
  var bufferFrames: Int { Int(HAL.value(id, kAudioDevicePropertyBufferFrameSize, default: UInt32(512))) }
  var label: String { "\"\(name)\"" }

  /// Clamps an IO buffer size to the range the device accepts.
  func clampedBufferFrames(_ frames: Int) -> UInt32 {
    let range = HAL.value(id, kAudioDevicePropertyBufferFrameSizeRange, default: AudioValueRange())
    guard range.mMaximum >= range.mMinimum, range.mMaximum > 0 else { return UInt32(frames) }
    return UInt32(min(max(Double(frames), range.mMinimum), range.mMaximum))
  }

  /// Sets the IO buffer size of this process. Each process has its own, so
  /// this does not change the buffer size of Wave Link or other apps.
  func setBufferFrames(_ frames: UInt32) -> OSStatus {
    var address = HAL.address(kAudioDevicePropertyBufferFrameSize)
    var value = frames
    return AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
  }

  static func all() -> [Device] {
    HAL.array(HAL.system, kAudioHardwarePropertyDevices, of: AudioObjectID.self).compactMap { id in
      guard let uid = HAL.string(id, kAudioDevicePropertyDeviceUID),
            let name = HAL.string(id, kAudioObjectPropertyName) else { return nil }
      let channels = { (scope: AudioObjectPropertyScope) in
        HAL.streamFormats(id, scope).reduce(0) { $0 + Int($1.mChannelsPerFrame) }
      }
      return Device(id: id, uid: uid, name: name,
                    transport: HAL.value(id, kAudioDevicePropertyTransportType, default: UInt32(0)),
                    inputChannels: channels(kAudioObjectPropertyScopeInput),
                    outputChannels: channels(kAudioObjectPropertyScopeOutput),
                    isAlive: HAL.value(id, kAudioDevicePropertyDeviceIsAlive, default: UInt32(0)) != 0)
    }
  }

  static var defaultOutputID: AudioObjectID {
    HAL.value(HAL.system, kAudioHardwarePropertyDefaultOutputDevice, default: AudioObjectID(kAudioObjectUnknown))
  }

  static func setDefaultOutput(_ device: Device) -> OSStatus {
    var address = HAL.address(kAudioHardwarePropertyDefaultOutputDevice)
    var value = device.id
    return AudioObjectSetPropertyData(HAL.system, &address, 0, nil, UInt32(MemoryLayout<AudioObjectID>.size), &value)
  }
}

// MARK: - Choices (pure, covered by --self-test)

/// Finds a device by UID, then exact name, then part of the name.
func findDevice(_ spec: String, in devices: [Device]) -> Device? {
  devices.first { $0.uid == spec } ?? devices.first { $0.name == spec } ??
    devices.first { $0.name.localizedCaseInsensitiveContains(spec) }
}

/// Picks the output: a named device, or for "auto" a connected Bluetooth
/// output. "auto" keeps its earlier choice while that device stays connected,
/// and otherwise prefers the macOS default output.
func chooseOutput(_ spec: String, devices: [Device], defaultID: AudioObjectID, previousUID: String?) -> Device? {
  let outputs = devices.filter { $0.outputChannels > 0 && $0.isAlive }
  guard spec == "auto" else { return findDevice(spec, in: outputs) }
  let bluetooth = outputs.filter(\.isBluetooth)
  if let previousUID, let device = bluetooth.first(where: { $0.uid == previousUID }) { return device }
  return bluetooth.first { $0.id == defaultID } ?? bluetooth.first
}

/// Picks the default output to use while the bridge runs. "auto" prefers
/// Elgato hardware, then built-in speakers, and never a Bluetooth or virtual
/// device.
func choosePark(_ spec: String, devices: [Device], headset: Device) -> Device? {
  let outputs = devices.filter { $0.outputChannels > 0 && $0.isAlive && $0.id != headset.id }
  switch spec {
  case "off": return nil
  case "auto":
    let hardware = outputs.filter { !$0.isBluetooth && !$0.isVirtual }
    return hardware.first { $0.name.localizedCaseInsensitiveContains("Wave") } ??
      hardware.first { $0.transport == kAudioDeviceTransportTypeBuiltIn } ?? hardware.first
  default: return findDevice(spec, in: outputs)
  }
}

/// Lists where Wave Link's own configuration sends audio to the device.
func waveLinkUses(_ config: [String: Any], deviceUID uid: String) -> [String] {
  var places: [String] = []
  if (config["mainOutput"] as? [String: Any])?["deviceID"] as? String == uid { places.append("its main output") }
  for mix in config["mixes"] as? [[String: Any]] ?? [] {
    let outputs = mix["outputs"] as? [[String: Any]] ?? []
    if outputs.contains(where: { $0["deviceID"] as? String == uid }) {
      places.append("an output of the \(mix["name"] as? String ?? "unnamed") mix")
    }
  }
  return places
}

/// Returns whether a process with this bundle ID is connected to CoreAudio,
/// or nil when the system cannot tell.
func audioProcessRunning(bundleID: String) -> Bool? {
  let processes = HAL.array(HAL.system, kAudioHardwarePropertyProcessObjectList, of: AudioObjectID.self)
  if processes.isEmpty { return nil }  // This process is always in the list when the property works.
  return processes.contains { HAL.string($0, kAudioProcessPropertyBundleID) == bundleID }
}

/// Reads Wave Link's configuration again only when the file changes.
final class WaveLinkConfig {
  static let path = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/com.elgato.WaveLink3/config.json").path
  private var modified: Date?
  private var config: [String: Any] = [:]

  func uses(deviceUID uid: String) -> [String] {
    let date = (try? FileManager.default.attributesOfItem(atPath: Self.path))?[.modificationDate] as? Date
    if date != modified {
      modified = date
      let data = FileManager.default.contents(atPath: Self.path) ?? Data()
      config = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
    return waveLinkUses(config, deviceUID: uid)
  }
}

// MARK: - Ring buffer

/// A single-producer, single-consumer ring buffer of stereo Float32 frames.
/// The input IOProc writes and the output render callback reads; neither side
/// locks or allocates.
final class FrameRing {
  let capacity: Int
  private let mask: Int
  private let storage: UnsafeMutablePointer<Float>
  private let writeCount = Atomic<Int>(0)
  private let readCount = Atomic<Int>(0)

  init(minimumFrames: Int) {
    var capacity = 1
    while capacity < minimumFrames { capacity <<= 1 }
    self.capacity = capacity
    mask = capacity - 1
    storage = .allocate(capacity: capacity * 2)
    storage.initialize(repeating: 0, count: capacity * 2)
  }

  deinit { storage.deallocate() }

  var totalWritten: Int { writeCount.load(ordering: .acquiring) }

  /// Frames waiting to be read. Either side may call this.
  var available: Int {
    let read = readCount.load(ordering: .acquiring)
    let written = writeCount.load(ordering: .acquiring)
    return max(0, min(capacity, written - read))
  }

  /// Producer only. Returns the number of frames stored; the rest are dropped.
  @discardableResult
  func write(frames: Int, left: UnsafePointer<Float>, leftStride: Int,
             right: UnsafePointer<Float>, rightStride: Int) -> Int {
    let written = writeCount.load(ordering: .relaxed)
    let read = readCount.load(ordering: .acquiring)
    let count = min(frames, capacity - (written - read))
    guard count > 0 else { return 0 }
    for index in 0..<count {
      let slot = ((written + index) & mask) << 1
      storage[slot] = left[index * leftStride]
      storage[slot + 1] = right[index * rightStride]
    }
    writeCount.store(written + count, ordering: .releasing)
    return count
  }

  /// Consumer only. Returns the number of frames copied.
  func read(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) -> Int {
    let read = readCount.load(ordering: .relaxed)
    let written = writeCount.load(ordering: .acquiring)
    let count = min(frames, written - read)
    guard count > 0 else { return 0 }
    for index in 0..<count {
      let slot = ((read + index) & mask) << 1
      left[index] = storage[slot]
      right[index] = storage[slot + 1]
    }
    readCount.store(read + count, ordering: .releasing)
    return count
  }

  /// Consumer only. Drops the oldest frames so that at most `keep` remain.
  @discardableResult
  func discard(keeping keep: Int) -> Int {
    let read = readCount.load(ordering: .relaxed)
    let written = writeCount.load(ordering: .acquiring)
    let drop = (written - read) - keep
    guard drop > 0 else { return 0 }
    readCount.store(read + drop, ordering: .releasing)
    return drop
  }
}

// MARK: - Drift control

/// Reads the ring buffer for the output side and keeps it at its target fill.
/// It waits for the target before it starts, starts again after an underrun,
/// drops frames after an output stall, and steers the playback rate so that
/// the output consumes frames exactly as fast as the input produces them.
final class Consumer {
  static let smoothingSeconds = 0.5
  /// Gains of the rate control. The fill error is in seconds and the rate
  /// change is a fraction, so the gains are per second and per second
  /// squared. An integral gain of a quarter of the square of the
  /// proportional gain damps the loop critically: it settles in about
  /// 4 / proportionalGain seconds, and the integral cancels the clock drift,
  /// so the buffer holds its target with no steady error.
  static let proportionalGain = 0.5
  static let integralGain = proportionalGain * proportionalGain / 4
  static let maxRateDeviation = 0.002
  /// Fill above the target beyond which the output must have stalled.
  static let stallSeconds = 0.04

  let ring: FrameRing
  let sampleRate: Double
  let targetFrames: Int
  /// Fill to start from. The input adds frames in bursts, so a fill read at a
  /// random moment lies up to one burst above the average that follows.
  /// Starting half a burst above the target keeps that average at or above
  /// the target; the rate control drains the rest.
  let startFrames: Int
  private var isRunning = false
  private var smoothedFill: Double
  private var integral = 0.0
  private var rate = 1.0

  // Read from other threads for status and tests.
  let underruns = Atomic<Int>(0)
  let droppedFrames = Atomic<Int>(0)
  /// The integral term, which converges on the drift between the two clocks.
  let driftPartsPerMillion = Atomic<Int>(0)
  let averageFillFrames = Atomic<Int>(0)
  private let lowestHeadroom = Atomic<Int>(Int.max)
  private let largestPull = Atomic<Int>(0)

  /// Returns the fewest frames left in the ring after a pull since the last
  /// call, or nil when there was no pull.
  func takeLowestHeadroom() -> Int? {
    let value = lowestHeadroom.exchange(Int.max, ordering: .relaxed)
    return value == Int.max ? nil : value
  }

  /// Returns the largest pull since the last call.
  func takeLargestPull() -> Int { largestPull.exchange(0, ordering: .relaxed) }

  init(ring: FrameRing, sampleRate: Double, targetFrames: Int, inputFrames: Int) {
    self.ring = ring
    self.sampleRate = sampleRate
    self.targetFrames = targetFrames
    startFrames = targetFrames + (inputFrames + 1) / 2
    smoothedFill = Double(targetFrames)
  }

  /// Fills `frames` frames of `left` and `right` and returns the playback
  /// rate for the next slice.
  func pull(frames: Int, left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>) -> Double {
    var available = ring.available
    if !isRunning {
      guard available >= startFrames else {
        left.update(repeating: 0, count: frames)
        right.update(repeating: 0, count: frames)
        return rate
      }
      ring.discard(keeping: startFrames)
      available = startFrames
      smoothedFill = Double(startFrames)
      isRunning = true
    } else if available > 2 * startFrames + Int(Self.stallSeconds * sampleRate) + frames {
      // The output stalled while the input kept writing. Go back to the start
      // fill instead of playing old audio late.
      droppedFrames.add(ring.discard(keeping: startFrames), ordering: .relaxed)
      available = startFrames
      smoothedFill = Double(startFrames)
    }
    if frames > largestPull.load(ordering: .relaxed) { largestPull.store(frames, ordering: .relaxed) }
    if available - frames < lowestHeadroom.load(ordering: .relaxed) {
      lowestHeadroom.store(available - frames, ordering: .relaxed)
    }

    let copied = ring.read(frames: frames, left: left, right: right)
    if copied < frames {
      (left + copied).update(repeating: 0, count: frames - copied)
      (right + copied).update(repeating: 0, count: frames - copied)
      underruns.add(1, ordering: .relaxed)
      isRunning = false
    }

    let seconds = Double(frames) / sampleRate
    smoothedFill += min(1, seconds / Self.smoothingSeconds) * (Double(available) - smoothedFill)
    let errorSeconds = (smoothedFill - Double(targetFrames)) / sampleRate
    let limit = Self.maxRateDeviation
    integral = max(-limit, min(limit, integral + Self.integralGain * errorSeconds * seconds))
    rate = 1 + max(-limit, min(limit, Self.proportionalGain * errorSeconds + integral))
    driftPartsPerMillion.store(Int((integral * 1_000_000).rounded()), ordering: .relaxed)
    averageFillFrames.store(Int(smoothedFill.rounded()), ordering: .relaxed)
    return rate
  }
}

// MARK: - Audio path

/// The highest input sample since the status report last read it.
final class PeakMeter {
  private let bits = Atomic<UInt32>(0)

  func record(_ value: Float) {
    if value.bitPattern > bits.load(ordering: .relaxed) { bits.store(value.bitPattern, ordering: .relaxed) }
  }

  func take() -> Float { Float(bitPattern: bits.exchange(0, ordering: .relaxed)) }
}

/// One running bridge from an input device to an output device.
final class Bridge {
  let input: Device
  let output: Device
  let sampleRate: Double
  let outputRate: Double
  let inputFrames: Int
  let outputFrames: Int
  let ring: FrameRing
  let consumer: Consumer
  let gain: Float
  let muted = Atomic<Bool>(false)
  let renderCount = Atomic<Int>(0)
  let inputPeak = PeakMeter()
  let varispeed: AudioUnit

  private let outputUnit: AudioUnit
  private var inputProc: AudioDeviceIOProcID?
  private var started = false

  /// Time added to the least safe fill, to cover IO threads that run late.
  static let marginSeconds = 0.002

  /// Returns the ring fill to hold before each pull. The output pulls
  /// `clientOutputFrames` at a time. The input adds `inputFrames` at a time,
  /// at a phase that drifts through every value, so the fill before a pull
  /// varies by `inputFrames`. The fill never runs dry when its average is
  /// half of that above the pull size; `nil` latency adds the margin to that.
  static func targetFrames(inputFrames: Int, clientOutputFrames: Double, sampleRate: Double,
                           latencySeconds: Double?) -> Int {
    let least = clientOutputFrames + Double(inputFrames) / 2
    let frames = latencySeconds.map { max($0 * sampleRate, least) } ?? least + marginSeconds * sampleRate
    return Int(frames.rounded(.up))
  }

  init(input: Device, output: Device, ioFrames: Int?, latencySeconds: Double?, gainDecibels: Double) throws {
    self.input = input
    self.output = output
    sampleRate = input.nominalRate
    outputRate = output.nominalRate
    guard sampleRate > 0, outputRate > 0 else { throw BridgeError("a device reports no sample rate") }
    for format in HAL.streamFormats(input.id, kAudioObjectPropertyScopeInput) {
      let isFloat = format.mFormatID == kAudioFormatLinearPCM && format.mFormatFlags & kAudioFormatFlagIsFloat != 0 &&
        format.mBitsPerChannel == 32
      guard isFloat else { throw BridgeError("\(input.label) does not deliver 32-bit float samples") }
    }

    let outputUnit = try Bridge.makeUnit(kAudioUnitType_Output, kAudioUnitSubType_HALOutput)
    var varispeed: AudioUnit?
    do {
      varispeed = try Bridge.makeUnit(kAudioUnitType_FormatConverter, kAudioUnitSubType_Varispeed)
      try Bridge.set(outputUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, UInt32(1),
                     "enabling output")
      try Bridge.set(outputUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, UInt32(0),
                     "disabling input")
      try Bridge.set(outputUnit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, output.id,
                     "selecting \(output.label)")
      // Smaller IO buffers mean smaller bursts on each side, so the ring can
      // hold less audio.
      if let ioFrames {
        try Bridge.set(outputUnit, kAudioDevicePropertyBufferFrameSize, kAudioUnitScope_Global, 0,
                       output.clampedBufferFrames(ioFrames), "setting the \(output.label) buffer size")
        try check(input.setBufferFrames(input.clampedBufferFrames(ioFrames)), "setting the \(input.label) buffer size")
      }
    } catch {
      if let varispeed { AudioComponentInstanceDispose(varispeed) }
      AudioComponentInstanceDispose(outputUnit)
      throw error
    }
    self.outputUnit = outputUnit
    self.varispeed = varispeed!

    inputFrames = input.bufferFrames
    outputFrames = output.bufferFrames
    let target = Bridge.targetFrames(inputFrames: inputFrames,
                                     clientOutputFrames: Double(outputFrames) * sampleRate / outputRate,
                                     sampleRate: sampleRate, latencySeconds: latencySeconds)
    ring = FrameRing(minimumFrames: max(32_768, 8 * target))
    consumer = Consumer(ring: ring, sampleRate: sampleRate, targetFrames: target, inputFrames: inputFrames)
    gain = Float(pow(10, gainDecibels / 20))
  }

  deinit {
    stop()
    AudioComponentInstanceDispose(varispeed)
    AudioComponentInstanceDispose(outputUnit)
  }

  private static func makeUnit(_ type: OSType, _ subtype: OSType) throws -> AudioUnit {
    var description = AudioComponentDescription(componentType: type, componentSubType: subtype,
                                                componentManufacturer: kAudioUnitManufacturer_Apple,
                                                componentFlags: 0, componentFlagsMask: 0)
    guard let component = AudioComponentFindNext(nil, &description) else {
      throw BridgeError("audio unit \(fourCC(subtype)) is missing")
    }
    var unit: AudioUnit?
    try check(AudioComponentInstanceNew(component, &unit), "creating audio unit \(fourCC(subtype))")
    guard let unit else { throw BridgeError("audio unit \(fourCC(subtype)) is missing") }
    return unit
  }

  private static func set<T>(_ unit: AudioUnit, _ property: AudioUnitPropertyID, _ scope: AudioUnitScope,
                             _ element: AudioUnitElement, _ value: T, _ what: String) throws {
    try withUnsafePointer(to: value) {
      try check(AudioUnitSetProperty(unit, property, scope, element, $0, UInt32(MemoryLayout<T>.size)), what)
    }
  }

  var targetMilliseconds: Double { Double(consumer.targetFrames) / sampleRate * 1000 }

  func start() throws {
    guard !started else { return }
    let clientFormat = AudioStreamBasicDescription(
      mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
      mFormatFlags: kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
      mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0)

    // AUHAL converts this client format to the device's own rate and layout.
    try Bridge.set(outputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, clientFormat,
                   "setting the output client format")
    try Bridge.set(varispeed, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, clientFormat,
                   "setting the Varispeed input format")
    try Bridge.set(varispeed, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, clientFormat,
                   "setting the Varispeed output format")
    try Bridge.set(varispeed, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, UInt32(8192),
                   "setting the Varispeed slice size")
    let callback = AURenderCallbackStruct(inputProc: renderCallback,
                                          inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
    try Bridge.set(varispeed, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, callback,
                   "setting the render callback")
    let connection = AudioUnitConnection(sourceAudioUnit: varispeed, sourceOutputNumber: 0, destInputNumber: 0)
    try Bridge.set(outputUnit, kAudioUnitProperty_MakeConnection, kAudioUnitScope_Input, 0, connection,
                   "connecting Varispeed to the output")
    try check(AudioUnitInitialize(varispeed), "initializing Varispeed")
    try check(AudioUnitInitialize(outputUnit), "initializing the output unit")

    let ring = self.ring
    let peak = inputPeak
    var procID: AudioDeviceIOProcID?
    try check(AudioDeviceCreateIOProcIDWithBlock(&procID, input.id, nil) { _, inputData, _, _, _ in
      // The HAL gives each stream one buffer of interleaved Float32 samples.
      let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: inputData))
      guard let first = buffers.first, first.mNumberChannels > 0,
            let left = first.mData?.assumingMemoryBound(to: Float.self) else { return }
      let leftStride = Int(first.mNumberChannels)
      let frames = Int(first.mDataByteSize) / (MemoryLayout<Float>.size * leftStride)
      var right = UnsafePointer(left)
      var rightStride = leftStride
      if leftStride >= 2 {
        right = UnsafePointer(left + 1)
      } else if buffers.count >= 2, buffers[1].mNumberChannels > 0,
                let second = buffers[1].mData?.assumingMemoryBound(to: Float.self) {
        right = UnsafePointer(second)
        rightStride = Int(buffers[1].mNumberChannels)
      }
      var loudest: Float = 0
      for index in 0..<frames { loudest = max(loudest, abs(left[index * leftStride]), abs(right[index * rightStride])) }
      peak.record(loudest)
      ring.write(frames: frames, left: left, leftStride: leftStride, right: right, rightStride: rightStride)
    }, "creating the input IOProc")
    inputProc = procID

    do {
      try check(AudioOutputUnitStart(outputUnit), "starting \(output.label)")
      try check(AudioDeviceStart(input.id, procID), "starting \(input.label)")
    } catch {
      stop()
      throw error
    }
    started = true
  }

  func stop() {
    if let inputProc {
      AudioDeviceStop(input.id, inputProc)
      AudioDeviceDestroyIOProcID(input.id, inputProc)
      self.inputProc = nil
    }
    AudioOutputUnitStop(outputUnit)
    AudioUnitUninitialize(outputUnit)
    AudioUnitUninitialize(varispeed)
    started = false
  }
}

/// Varispeed calls this on the output IO thread for each slice of input.
private let renderCallback: AURenderCallback = { refCon, _, _, _, frameCount, ioData in
  let bridge = Unmanaged<Bridge>.fromOpaque(refCon).takeUnretainedValue()
  guard let ioData else { return noErr }
  let buffers = UnsafeMutableAudioBufferListPointer(ioData)
  guard buffers.count >= 2, let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
        let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
  let frames = Int(frameCount)
  let rate = bridge.consumer.pull(frames: frames, left: left, right: right)
  if bridge.muted.load(ordering: .relaxed) {
    left.update(repeating: 0, count: frames)
    right.update(repeating: 0, count: frames)
  } else if bridge.gain != 1 {
    for index in 0..<frames {
      left[index] *= bridge.gain
      right[index] *= bridge.gain
    }
  }
  AudioUnitSetParameter(bridge.varispeed, kVarispeedParam_PlaybackRate, kAudioUnitScope_Global, 0,
                        AudioUnitParameterValue(rate), 0)
  bridge.renderCount.add(1, ordering: .relaxed)
  return noErr
}

// MARK: - Options

struct Options {
  var input = "Elgato Wave Link Personal Mix"
  var output = "auto"
  var park = "auto"
  var app: String? = "com.elgato.WaveLink3"
  var ioFrames: Int? = 64
  var latencySeconds: Double?
  var gainDecibels = 0.0
  var verbose = false

  static let usage = """
    Usage: wavelink-bt-bridge [options]
           wavelink-bt-bridge --list | --self-test

    Plays an Elgato Wave Link mix on a Bluetooth output that Wave Link cannot drive.

      --input DEVICE   Mix to play: a device UID, name or part of a name.
                       Default: "Elgato Wave Link Personal Mix".
      --output DEVICE  Output device, or "auto" for the first connected Bluetooth output.
                       Default: auto.
      --park DEVICE    Default output to use while the bridge runs, "auto" or "off".
                       Default: auto (Elgato hardware, then the built-in speakers).
      --app BUNDLE_ID  Bridge only while this app uses CoreAudio, or "none".
                       Default: com.elgato.WaveLink3. With the default, the bridge
                       also waits while Wave Link sends a mix to the output itself.
      --io-frames N    IO buffer size of both devices in frames, or "default" to keep
                       theirs. Smaller buffers lower the delay. Default: 64.
      --latency MS     Target buffer in milliseconds, or "auto" for the least that is
                       safe with the IO buffers. Default: auto.
      --gain DB        Gain for the mix in decibels. Default: 0.
      --verbose        Log buffer statistics every 5 seconds instead of every 10 minutes.
                       SIGUSR1 logs them at once.
      --list           List audio devices and exit.
      --self-test      Test the ring buffer, drift control and device choices without audio devices.
    """

  static func parse(_ arguments: [String]) -> (Options, command: String?) {
    var options = Options()
    var command: String?
    var iterator = arguments.makeIterator()
    func next(_ flag: String) -> String {
      guard let value = iterator.next() else { fail("\(flag) needs a value") }
      return value
    }
    while let argument = iterator.next() {
      switch argument {
      case "--input": options.input = next(argument)
      case "--output": options.output = next(argument)
      case "--park": options.park = next(argument)
      case "--app":
        let value = next(argument)
        options.app = value == "none" ? nil : value
      case "--io-frames":
        let value = next(argument)
        if value == "default" {
          options.ioFrames = nil
        } else {
          guard let frames = Int(value), frames >= 16, frames <= 4096 else { fail("--io-frames must be default or 16 to 4096") }
          options.ioFrames = frames
        }
      case "--latency":
        let value = next(argument)
        if value == "auto" {
          options.latencySeconds = nil
        } else {
          guard let ms = Double(value), ms >= 1, ms <= 1000 else { fail("--latency must be auto or 1 to 1000") }
          options.latencySeconds = ms / 1000
        }
      case "--gain":
        guard let value = Double(next(argument)), value >= -96, value <= 24 else { fail("--gain must be -96 to 24") }
        options.gainDecibels = value
      case "--verbose": options.verbose = true
      case "--list", "--self-test": command = argument
      case "-h", "--help":
        print(usage)
        exit(0)
      default: fail("unknown option \(argument)\n\(usage)")
      }
    }
    return (options, command)
  }

  var watchesWaveLink: Bool { app == "com.elgato.WaveLink3" }
}

// MARK: - Supervisor

/// Starts, stops and restarts the bridge as devices and apps come and go.
final class Supervisor {
  let options: Options
  private let waveLinkConfig = WaveLinkConfig()
  private var bridge: Bridge?
  private var chosenOutputUID: String?
  private var parked: (headsetUID: String, park: Device)?
  private var nextStartAttempt = Date.distantPast
  private var lastStatus = ""
  private var lastRenderCount = -1
  private var lastWritten = -1
  private var stalledTicks = 0
  private var lastReport = Date()
  private var reportedUnderruns = 0
  private var reportedDrops = 0
  private var microphoneRequested = false

  init(options: Options) { self.options = options }

  private func status(_ message: String) {
    guard message != lastStatus else { return }
    lastStatus = message
    log(message)
  }

  private func microphoneAllowed() -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized: return true
    case .notDetermined:
      if !microphoneRequested {
        microphoneRequested = true
        status("Asking for microphone access, which macOS requires to read the Wave Link mix")
        AVCaptureDevice.requestAccess(for: .audio) { granted in
          log(granted ? "Microphone access allowed" : "Microphone access denied")
        }
      }
      return false
    default:
      status("Waiting: microphone access is denied. Allow it in System Settings > Privacy & Security > Microphone")
      return false
    }
  }

  /// Returns why the bridge cannot run now, or nil when it can.
  private func blocker(appRunning: Bool, input: Device?, headset: Device?) -> String? {
    if !appRunning { return "Waiting for \(options.app ?? "the app") to start" }
    guard input != nil else { return "Waiting for the input \"\(options.input)\"" }
    guard let headset else {
      return options.output == "auto" ? "Waiting for a Bluetooth output" : "Waiting for the output \"\(options.output)\""
    }
    if options.watchesWaveLink {
      let uses = waveLinkConfig.uses(deviceUID: headset.uid)
      if !uses.isEmpty {
        return "Waiting: Wave Link uses \(headset.label) as \(uses.joined(separator: " and ")). " +
          "Choose another device there; Wave Link 3.3+ cannot drive it"
      }
    }
    return nil
  }

  func tick() {
    let devices = Device.all()
    let appRunning = options.app.map { audioProcessRunning(bundleID: $0) ?? true } ?? true
    let input = findDevice(options.input, in: devices.filter { $0.inputChannels > 0 && $0.isAlive })
    let headset = chooseOutput(options.output, devices: devices, defaultID: Device.defaultOutputID,
                               previousUID: chosenOutputUID)
    chosenOutputUID = headset?.uid
    let blocked = blocker(appRunning: appRunning, input: input, headset: headset)

    if let bridge {
      var reason: String?
      if let blocked { reason = blocked }
      else if input?.id != bridge.input.id || headset?.id != bridge.output.id { reason = "a device changed" }
      else if bridge.input.nominalRate != bridge.sampleRate || bridge.output.nominalRate != bridge.outputRate {
        reason = "a sample rate changed"
      } else {
        let renders = bridge.renderCount.load(ordering: .relaxed)
        let written = bridge.ring.totalWritten
        stalledTicks = renders == lastRenderCount || written == lastWritten ? stalledTicks + 1 : 0
        lastRenderCount = renders
        lastWritten = written
        if stalledTicks >= 3 {
          reason = "audio stopped flowing"
          nextStartAttempt = Date().addingTimeInterval(2)
        }
      }
      if let reason { stopBridge(because: reason) }
    }

    if bridge == nil {
      if let blocked {
        status(blocked)
      } else if let input, let headset, Date() >= nextStartAttempt, microphoneAllowed() {
        startBridge(input: input, headset: headset)
      }
    }

    updateDefaultOutput(devices)
    report()
  }

  private func startBridge(input: Device, headset: Device) {
    do {
      let bridge = try Bridge(input: input, output: headset, ioFrames: options.ioFrames,
                              latencySeconds: options.latencySeconds, gainDecibels: options.gainDecibels)
      bridge.muted.store(Device.defaultOutputID == headset.id, ordering: .relaxed)
      try bridge.start()
      self.bridge = bridge
      lastRenderCount = -1
      lastWritten = -1
      stalledTicks = 0
      reportedUnderruns = 0
      reportedDrops = 0
      status("Bridging \(input.label) (\(Int(bridge.sampleRate)) Hz) to \(headset.label) " +
             "(\(Int(bridge.outputRate)) Hz), IO buffers \(bridge.inputFrames)/\(bridge.outputFrames) frames, " +
             String(format: "target %.1f ms", bridge.targetMilliseconds))
    } catch {
      status("Could not start: \(error)")
      nextStartAttempt = Date().addingTimeInterval(5)
    }
  }

  private func stopBridge(because reason: String) {
    guard let bridge else { return }
    bridge.stop()
    self.bridge = nil
    status("Stopped: \(reason)")
  }

  private func updateDefaultOutput(_ devices: [Device]) {
    guard let bridge else {
      restoreDefaultOutput(devices)
      return
    }
    if Device.defaultOutputID == bridge.output.id,
       let park = choosePark(options.park, devices: devices, headset: bridge.output) {
      if Device.setDefaultOutput(park) == noErr {
        log("Moved the macOS default output from \(bridge.output.label) to \(park.label), " +
            "so Wave Link does not capture the bridge")
        parked = (bridge.output.uid, park)
      }
    }
    let mute = Device.defaultOutputID == bridge.output.id
    if mute != bridge.muted.load(ordering: .relaxed) {
      bridge.muted.store(mute, ordering: .relaxed)
      log(mute ? "Muted: \(bridge.output.label) is the macOS default output, so Wave Link would capture the bridge"
               : "Unmuted")
    }
  }

  /// Gives the default output back to the headset, unless someone chose
  /// another device in the meantime. While the headset is disconnected, it
  /// waits for the headset to come back.
  private func restoreDefaultOutput(_ devices: [Device]) {
    guard let parked else { return }
    guard Device.defaultOutputID == parked.park.id else {
      self.parked = nil
      return
    }
    guard let headset = devices.first(where: { $0.uid == parked.headsetUID && $0.isAlive && $0.outputChannels > 0 })
    else { return }
    if Device.setDefaultOutput(headset) == noErr {
      self.parked = nil
      log("Moved the macOS default output back to \(headset.label)")
    }
  }

  /// Logs underruns as they happen, and buffer statistics every 10 minutes,
  /// every 5 seconds with --verbose, or now when `force` is set.
  func report(force: Bool = false) {
    guard let bridge else {
      if force { log("Status: \(lastStatus)") }
      return
    }
    let underruns = bridge.consumer.underruns.load(ordering: .relaxed)
    let drops = bridge.consumer.droppedFrames.load(ordering: .relaxed)
    if underruns != reportedUnderruns || drops != reportedDrops {
      log("Buffer: \(underruns - reportedUnderruns) underruns and \(drops - reportedDrops) dropped frames " +
          "since the last report")
      reportedUnderruns = underruns
      reportedDrops = drops
    }
    guard force || Date().timeIntervalSince(lastReport) >= (options.verbose ? 5 : 600) else { return }
    lastReport = Date()
    let milliseconds = { (frames: Int) in Double(frames) / bridge.sampleRate * 1000 }
    let fill = milliseconds(bridge.consumer.averageFillFrames.load(ordering: .relaxed))
    let headroom = bridge.consumer.takeLowestHeadroom().map { String(format: "%.1f ms", milliseconds($0)) } ?? "none"
    let peak = bridge.inputPeak.take()
    let peakText = peak > 0 ? String(format: "%.1f dBFS", 20 * log10(Double(peak))) : "silent"
    log(String(format: "Status: buffer %.1f ms (target %.1f ms), lowest headroom %@, largest pull %d frames, " +
               "clock drift %+d ppm, input peak %@", fill, bridge.targetMilliseconds, headroom,
               bridge.consumer.takeLargestPull(), bridge.consumer.driftPartsPerMillion.load(ordering: .relaxed), peakText))
  }

  func shutdown() {
    stopBridge(because: "shutting down")
    restoreDefaultOutput(Device.all())
  }
}

// MARK: - Commands

func listDevices(_ options: Options) {
  let access: String
  switch AVCaptureDevice.authorizationStatus(for: .audio) {
  case .authorized: access = "allowed"
  case .notDetermined: access = "not asked yet"
  default: access = "denied"
  }
  print("Microphone access (needed to read the mix): \(access)")
  if let app = options.app {
    let running = audioProcessRunning(bundleID: app).map { $0 ? "yes" : "no" } ?? "unknown"
    print("\(app) connected to CoreAudio: \(running)")
  }
  let defaultID = Device.defaultOutputID
  let config = WaveLinkConfig()
  for device in Device.all() {
    let marker = device.id == defaultID ? " [default output]" : ""
    print("\(device.label)\(marker)\n  uid \(device.uid), transport \(fourCC(device.transport)), " +
          "\(Int(device.nominalRate)) Hz, \(device.inputChannels) in, \(device.outputChannels) out")
    let uses = device.outputChannels > 0 ? config.uses(deviceUID: device.uid) : []
    if !uses.isEmpty { print("  Wave Link uses it as \(uses.joined(separator: " and "))") }
  }
}

/// Tests the ring buffer, the drift control and the device choices without
/// audio hardware.
func selfTest() -> Bool {
  var passed = true
  func expect(_ condition: Bool, _ message: String) {
    if !condition {
      print("FAIL: \(message)")
      passed = false
    }
  }

  // The ring keeps frames in order across many wraps and never overfills.
  let ring = FrameRing(minimumFrames: 1000)
  expect(ring.capacity == 1024, "capacity rounds up to a power of two")
  var nextWrite = 0
  var nextRead = 0
  let source = UnsafeMutablePointer<Float>.allocate(capacity: 2 * 700)
  let left = UnsafeMutablePointer<Float>.allocate(capacity: 4096)
  let right = UnsafeMutablePointer<Float>.allocate(capacity: 4096)
  defer { source.deallocate(); left.deallocate(); right.deallocate() }
  var generator = SystemRandomNumberGenerator()
  ringLoop: for _ in 0..<20_000 {
    let frames = Int.random(in: 1...700, using: &generator)
    for index in 0..<frames {
      source[index * 2] = Float(nextWrite + index)
      source[index * 2 + 1] = -Float(nextWrite + index)
    }
    nextWrite += ring.write(frames: frames, left: source, leftStride: 2, right: source + 1, rightStride: 2)
    expect(ring.available <= ring.capacity, "the ring never holds more than its capacity")
    let read = ring.read(frames: Int.random(in: 1...700, using: &generator), left: left, right: right)
    for index in 0..<read where left[index] != Float(nextRead + index) || right[index] != -left[index] {
      expect(false, "frame \(nextRead + index) came out as \(left[index])")
      break ringLoop
    }
    nextRead += read
    if nextWrite > 1 << 23 { break }  // Stay inside the range where Float counts exactly.
  }

  // With the least safe target, the rate control holds the buffer without
  // underruns for several IO buffer sizes, both directions of drift, and IO
  // threads that run up to `late` seconds late.
  for (ioFrames, late) in [(512, 0.001), (128, 0.001), (64, 0.0005)] {
    for drift in [-500.0, 0, 500] {
      let inputRate = 48_000.0, outputRate = 44_100.0
      let clientOutputFrames = Double(ioFrames) * inputRate / outputRate
      let target = Bridge.targetFrames(inputFrames: ioFrames, clientOutputFrames: clientOutputFrames,
                                       sampleRate: inputRate, latencySeconds: nil)
      let ring = FrameRing(minimumFrames: 32_768)
      let consumer = Consumer(ring: ring, sampleRate: inputRate, targetFrames: target, inputFrames: ioFrames)
      let block = UnsafeMutablePointer<Float>.allocate(capacity: 2 * ioFrames)
      block.initialize(repeating: 0.25, count: 2 * ioFrames)
      defer { block.deallocate() }
      let inputPeriod = Double(ioFrames) / (inputRate * (1 + drift / 1_000_000))
      let outputPeriod = Double(ioFrames) / outputRate
      var nextInput = 0.0, nextOutput = 0.0, inputAt = 0.0, outputAt = 0.0, rate = 1.0, owed = 0.0
      var underruns = 0
      while min(inputAt, outputAt) < 120 {
        if inputAt <= outputAt {
          ring.write(frames: ioFrames, left: block, leftStride: 2, right: block + 1, rightStride: 2)
          nextInput += inputPeriod
          inputAt = nextInput + Double.random(in: 0...late, using: &generator)
        } else {
          owed += clientOutputFrames * rate
          let frames = Int(owed)
          owed -= Double(frames)
          let before = consumer.underruns.load(ordering: .relaxed)
          rate = consumer.pull(frames: frames, left: left, right: right)
          underruns += consumer.underruns.load(ordering: .relaxed) - before
          nextOutput += outputPeriod
          outputAt = nextOutput + Double.random(in: 0...late, using: &generator)
        }
      }
      let targetMs = Double(target) / inputRate * 1000
      let fillMs = Double(consumer.averageFillFrames.load(ordering: .relaxed)) / inputRate * 1000
      let ppm = consumer.driftPartsPerMillion.load(ordering: .relaxed)
      print(String(format: "IO %3d frames, drift %+4.0f ppm: buffer %5.2f ms (target %5.2f), measured %+4d ppm, %d underruns",
                   ioFrames, drift, fillMs, targetMs, ppm, underruns))
      expect(underruns == 0, "no underruns with \(ioFrames) frames at \(drift) ppm")
      expect(abs(fillMs - targetMs) < 0.5, "the buffer holds its target with \(ioFrames) frames at \(drift) ppm")
      expect(abs(Double(ppm) - drift) < 20, "the rate control measures the drift with \(ioFrames) frames at \(drift) ppm")
    }
  }

  // Device choices.
  func device(_ id: AudioObjectID, _ name: String, _ transport: UInt32, input: Int = 0, output: Int = 2,
              alive: Bool = true) -> Device {
    Device(id: id, uid: "uid-\(id)", name: name, transport: transport, inputChannels: input, outputChannels: output,
           isAlive: alive)
  }
  let mix = device(1, "Elgato Wave Link Personal Mix", kAudioDeviceTransportTypeVirtual, input: 2, output: 0)
  let headsetInput = device(2, "Bose NC 700 HP", kAudioDeviceTransportTypeBluetooth, input: 1, output: 0)
  let headset = device(3, "Bose NC 700 HP", kAudioDeviceTransportTypeBluetooth)
  let airPods = device(4, "AirPods", kAudioDeviceTransportTypeBluetoothLE)
  let speakers = device(5, "MacBook Pro Speakers", kAudioDeviceTransportTypeBuiltIn)
  let waveXLR = device(6, "Elgato Wave XLR", kAudioDeviceTransportTypeUSB, input: 1)
  let monitor = device(7, "C49RG9x", kAudioDeviceTransportTypeDisplayPort)
  let gone = device(8, "Old Headset", kAudioDeviceTransportTypeBluetooth, alive: false)
  let all = [mix, headsetInput, gone, speakers, monitor, airPods, headset, waveXLR]

  expect(findDevice("uid-6", in: all) == waveXLR, "a UID finds its device")
  expect(findDevice("wave link personal", in: all) == mix, "part of a name finds its device")
  expect(chooseOutput("auto", devices: all, defaultID: 3, previousUID: nil) == headset,
         "auto prefers the Bluetooth default output and skips inputs and dead devices")
  expect(chooseOutput("auto", devices: all, defaultID: 5, previousUID: nil) == airPods,
         "auto takes the first Bluetooth output when the default is not Bluetooth")
  expect(chooseOutput("auto", devices: all, defaultID: 6, previousUID: "uid-3") == headset,
         "auto keeps its earlier choice after the default output moves")
  expect(chooseOutput("auto", devices: [mix, speakers], defaultID: 5, previousUID: "uid-3") == nil,
         "auto finds nothing without a Bluetooth output")
  expect(chooseOutput("Bose", devices: all, defaultID: 5, previousUID: nil) == headset,
         "a named output skips the input device of the same name")
  expect(choosePark("auto", devices: all, headset: headset) == waveXLR, "auto parks on Elgato hardware first")
  expect(choosePark("auto", devices: [headset, airPods, monitor, speakers], headset: headset) == speakers,
         "auto parks on the built-in speakers next and never on Bluetooth")
  expect(choosePark("off", devices: all, headset: headset) == nil, "off never parks")
  expect(choosePark("C49", devices: all, headset: headset) == monitor, "a named park device is used")

  let config: [String: Any] = [
    "mainOutput": ["deviceID": "uid-3"],
    "mixes": [
      ["name": "Personal Mix", "outputs": [["deviceID": "loopback"], ["deviceID": "uid-3"]]],
      ["name": "Stream Mix", "outputs": [["deviceID": "loopback-2"]]],
    ],
  ]
  expect(waveLinkUses(config, deviceUID: "uid-3") == ["its main output", "an output of the Personal Mix mix"],
         "the Wave Link check finds the main output and mix outputs")
  expect(waveLinkUses(config, deviceUID: "uid-6").isEmpty, "the Wave Link check ignores other devices")
  expect(waveLinkUses([:], deviceUID: "uid-3").isEmpty, "the Wave Link check accepts a missing config")

  print(passed ? "Self-test passed" : "Self-test failed")
  return passed
}

@main
enum Main {
  static func main() {
    setlinebuf(stdout)
    let (options, command) = Options.parse(Array(CommandLine.arguments.dropFirst()))
    switch command {
    case "--list":
      listDevices(options)
      return
    case "--self-test":
      exit(selfTest() ? 0 : 1)
    default: break
    }

    let supervisor = Supervisor(options: options)
    let main = DispatchQueue.main
    var listeners: [(AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
      var address = HAL.address(selector)
      let block: AudioObjectPropertyListenerBlock = { _, _ in supervisor.tick() }
      AudioObjectAddPropertyListenerBlock(HAL.system, &address, main, block)
      listeners.append((address, block))
    }
    let timer = DispatchSource.makeTimerSource(queue: main)
    timer.schedule(deadline: .now(), repeating: 1)
    timer.setEventHandler { supervisor.tick() }
    timer.resume()

    var signals: [DispatchSourceSignal] = []
    for number in [SIGINT, SIGTERM, SIGHUP] {
      signal(number, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: number, queue: main)
      source.setEventHandler {
        timer.cancel()
        for (address, block) in listeners {
          var address = address
          AudioObjectRemovePropertyListenerBlock(HAL.system, &address, main, block)
        }
        supervisor.shutdown()
        exit(0)
      }
      source.resume()
      signals.append(source)
    }
    signal(SIGUSR1, SIG_IGN)
    let statusSignal = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: main)
    statusSignal.setEventHandler { supervisor.report(force: true) }
    statusSignal.resume()
    signals.append(statusSignal)
    log("Started (input \"\(options.input)\", output \(options.output), park \(options.park))")
    withExtendedLifetime((timer, signals)) { RunLoop.main.run() }
  }
}
