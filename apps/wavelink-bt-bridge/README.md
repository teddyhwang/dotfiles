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
  target of 50 ms.
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
- When a device or a sample rate changes, the helper restarts the bridge.

## Set up Wave Link

1. In Wave Link, set the main output to a 48 kHz device, for example the
   Wave XLR.
2. Remove the headset from the outputs of every mix.
3. Keep the headset connected to the Mac over Bluetooth.

While Wave Link still uses the headset, the helper waits and logs where Wave
Link uses it.

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
  each buffer underrun is logged. Buffer statistics are logged every hour.
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
- The bridge adds about 50 ms to the latency of the headset.
- If an app uses the microphone of the headset, macOS switches the headset to
  a lower-quality call mode. The helper follows the new sample rate.
