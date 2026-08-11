# C152 port and validation checklist

## Completed in source

- Use M5Stack's official PlatformIO target shape for StopWatch.
- Require the current M5Unified/M5GFX path that includes M5StopWatch support.
- Render to a PSRAM-backed 466 x 466 canvas.
- Map physical-left `M5.BtnA` to Mic key `ACT10` and physical-right `M5.BtnB`
  to configurable Command Key 4 (`ACT09`).
- Retain the upstream vendor HID report ID 6 transport.
- Add a separate private quota write service.
- Map the center touch target to Send key `ACT12`.
- Map full-screen swipes to the four normalized analog-stick directions.
- Complete a clean PlatformIO release build with pinned dependencies.
- Preserve real StopWatch power mapping: M5IOE1 G8 is the shared L3B rail, G5
  is AMOLED reset, and G4 is touch reset.
- Track Codex host activity separately from BLE connection count and quota
  companion freshness.

## Before first flash

- Keep the dependency commits pinned. The first clean build used M5Unified
  `4fb4447`, M5GFX `729297d`, M5PM1 `be9a545`, and M5IOE1 `846eec7`.
- Inspect flash size and PSRAM allocation.
- Download or document the official factory-firmware recovery procedure.
- Resolve the exact connected C152 serial path and confirm its Espressif VID/PID.

## Physical validation order

1. Flash and verify serial marker `CODEX_MICRO_STOPWATCH_READY`.
2. Verify display geometry, brightness, and no circular-edge clipping.
3. Verify BtnA/BtnB press and release in serial logs.
4. Pair in macOS Bluetooth settings using a clean pairing record.
5. Confirm ChatGPT Desktop exposes **Settings > Codex Micro**.
6. Send `device.status` and require a valid round trip.
7. Set **Microphone key** to **Push to talk**.
8. Assign Command Key 4 to **Toggle voice chat**, then verify left PTT and right
   Voice Chat with the Mac mic.
9. Verify all six Agent status colors and breathing updates.
10. Write a synthetic quota snapshot through CoreBluetooth and verify countdown.
11. Only then connect the companion to the live App Server rate-limit feed.
12. Verify the battery percentage, charging bolt, Dock color, and all four
    health combinations, including `CODEX LIVE` together with `SYNC STALE`.
13. On battery, short-click the red button for desk sleep. Confirm AMOLED,
    speaker, and motor power are off while a real Agent completion still wakes
    the display and plays the chime. In the USB-mic image, verify that an
    active host capture skips the chime without interrupting audio, while an
    idle host permits the local chime and restores microphone capture. Repeat
    at least 100 sleep/wake cycles.
14. With USB power attached, confirm Dock Mode uses the longer idle policy and
    a full battery still remains in Dock Mode even when not actively charging.
15. Unplug USB and rapidly double-click the red power button. Confirm the
    on-screen warning, true PM1 shutdown, missed BLE notifications, and cold
    start from the power button and from VIN insertion. Repeat with the
    six-second center-dial fallback. Confirm a long red-button hold still enters
    the hardware recovery/download path.

The full sequence above has been observed on a physical C152 for the current
MVP, including both buttons, center Send, all four swipes, Agent status updates,
completion chime, haptics, and a real quota/reset snapshot. Repeat the sequence
after changes to the HID descriptor, input mapping, BLE services, or board
dependencies.

The original MVP observations above predate the new power lifecycle. Build and
native-preview validation do not count as physical proof for steps 12-15; those
must be recorded separately on C152 before the feature is described as
hardware-validated.

## Explicitly deferred

- StopWatch speaker for Voice Chat output
- USB HID compatibility
- OTA updater and rollback
- Multiple Bluetooth host slots
- Production-grade authenticated BLE transport
- IMU motion wake and scheduled RTC wake for Travel Mode

## Optional USB microphone validation

The `usb-mic` PlatformIO project is intentionally separate from the default
image and package cache. Its source build is complete; physical validation must
be reported independently:

1. Confirm the exact C152 upload port and factory-recovery path.
2. Flash the optional environment.
3. Confirm macOS enumerates `Codex StopWatch Mic` as 48 kHz mono input.
4. Open and close several short temporary recordings, verify each contains
   nonzero microphone PCM, and check that `usbaudiod` does not report
   `excessive zero length packets` for the StopWatch. Do not use the ratio of
   ffmpeg payload duration to wall time as a pass/fail signal: AVFoundation on
   current macOS reports the same reduced ratio for known-good 48 kHz devices.
5. Run `scripts/hid_inspect.swift` to require exactly one `303A:8360` vendor
   HID interface with output report 6, then confirm
   `scripts/hid_rpc_probe.swift` can exchange a status RPC. Generic BLE pairing
   alone is not a successful HID validation.
6. Run `scripts/hid_input_probe.swift` and require at least one real input
   report from a physical or touch control.
7. Re-check BLE pairing, both physical buttons, touch Send, swipes, Agent
   status, quota updates, and haptics. The local completion chime may play only
   while the host microphone stream is idle; it must remain silent while the
   host is actively streaming microphone audio.
