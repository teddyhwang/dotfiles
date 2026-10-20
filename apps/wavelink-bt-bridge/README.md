# wavelink-bt-bridge

`wavelink-bt-bridge` plays an Elgato Wave Link mix on Bluetooth headphones.

## Why it exists

Wave Link 3.3.0 and later on macOS cannot use an output that runs at 44.1 kHz.
macOS runs most Bluetooth headphones at 44.1 kHz. When you select such a
headset as an output, Wave Link plays nothing. It also rebuilds its audio
device several times per second until the headset disconnects. Wave Link
3.2.2 converted the sample rate for each output, but the new audio engine does
not. Elgato support says that only 48 kHz devices are supported.

Wave Link still publishes each mix as a 48 kHz virtual input device, for
example "Elgato Wave Link Personal Mix". The helper reads that device. It
converts the audio to the rate of the headset, corrects the drift between the
two clocks and plays the result on the headset.

## How it works

- An IOProc on the mix device writes into a ring buffer. A Varispeed unit
  reads the ring buffer and feeds an AUHAL output unit on the headset. This is
  the design of Apple's CAPlayThrough sample.
- AUHAL converts 48 kHz to the rate of the headset. Varispeed changes the
  playback rate by a few parts per million. This keeps the ring buffer at its
  target.
- The helper uses IO buffers of 64 frames on both devices, instead of the
  usual 512. Each process has its own IO buffer size, so this does not change
  Wave Link. With small buffers, each side moves only a little audio at a time.
  The ring buffer then needs only about 4.5 ms: one pull of the output, half
  a burst of the input, and a margin of 2 ms plus a quarter of an input burst
  for IO threads that run late and for the dip while the rate control learns
  the drift.
- A rate control with an integral term measures the drift between the two
  clocks and cancels it, so the buffer holds its target exactly.
- Wave Link captures app audio with a process tap on the macOS default output.
  If the headset were the default output, Wave Link would also capture and
  mute the helper. The audio would then feed back into the mix. While the
  bridge runs, the helper moves the default output to another device: Elgato
  hardware first, then the built-in speakers. Wave Link mutes app audio there
  and mixes it. When the bridge stops, the helper moves the default output
  back to the headset.
- The helper bridges only while all of these are true:
  - Wave Link is running.
  - A Bluetooth output is connected.
  - Wave Link does not send audio to that headset itself.
  - Wave Link's main output is the trigger device. By default that is the
    device that the default output moves to: Elgato hardware first, then the
    built-in speakers. `--trigger DEVICE` chooses another one, and
    `--trigger any` bridges with any main output.
- Bluetooth outputs accept IO buffers no smaller than about 256 frames and run
  their IO thread less regularly, so the ring holds one more output buffer for
  them. Each underrun raises the target by about half an output buffer, up to
  40 ms.
- When a device or a sample rate changes, the helper restarts the bridge.

## Set up Wave Link

1. Remove the headset from the outputs of every mix in Wave Link, and never
   choose it as the main output.
2. Keep the headset connected to the Mac over Bluetooth.
3. Choose where to listen with Wave Link's main output:
   - **Wave XLR** (the trigger device): the helper plays the Personal Mix on
     the headset. Nothing plays from the Wave XLR unless something is plugged
     into its headphone jack.
   - **Any other device**, for example a USB speaker: Wave Link plays the mix
     there only, and the helper stays idle.

The helper notices a change of main output within about a second. While it is
idle, its log says why and what to choose.

## Install

```sh
./scripts/wavelink_bt_bridge.sh            # build, self-test and start the launch agent
./scripts/wavelink_bt_bridge.sh build      # build into ~/.local/bin only
./scripts/wavelink_bt_bridge.sh uninstall  # stop the agent and remove its files
```

`setup.sh` does not run this script. The build needs the Xcode Command Line
Tools.

When the helper first reads the mix, macOS asks you to allow microphone access
for `wavelink-bt-bridge`. Allow it. macOS asks again after each rebuild that
changes the binary.

## Use

- **Log:** `~/Library/Logs/wavelink-bt-bridge.log`. Each change of state and
  each buffer underrun is logged. Buffer statistics are logged every 10
  minutes. To log them now, run
  `launchctl kill SIGUSR1 gui/$(id -u)/localhost.wavelink-bt-bridge`.
- **Statistics:** "lowest headroom" is the least audio that was left in the
  buffer after a pull. If it gets near 0 ms, or underruns are logged, raise
  `--io-frames` or `--latency`.
- **Devices:** `wavelink-bt-bridge --list` shows the devices, the microphone
  access, and where Wave Link uses each output.
- **Test:** `wavelink-bt-bridge --self-test` tests the ring buffer, the drift
  control and the device choices without audio devices.
- **Options:** `wavelink-bt-bridge --help` lists them. Use `--verbose` to log
  statistics every 5 seconds.

## Limits

- The volume keys change the volume of the macOS default output, which is not
  the headset while the bridge runs. Use the buttons on the headset or the mix
  volume in Wave Link.
- If you select the headset as the macOS output while the bridge runs, the
  helper moves the output away again.
- The bridge adds about 22 ms to the latency of a Bose NC 700: 1.3 ms for the
  input IO buffer, 5.8 ms for the 256-frame output IO buffer and about 15 ms
  in the ring buffer. For a wired output it adds about 7 ms. Bluetooth itself
  adds much more; macOS reports about 180 ms for a Bose NC 700.
- If an app uses the microphone of the headset, macOS switches the headset to
  a lower-quality call mode. The helper follows the new sample rate.
