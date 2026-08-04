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

The full sequence above has been observed on a physical C152 for the current
MVP, including both buttons, center Send, all four swipes, Agent status updates,
completion chime, haptics, and a real quota/reset snapshot. Repeat the sequence
after changes to the HID descriptor, input mapping, BLE services, or board
dependencies.

## Explicitly deferred

- StopWatch microphone as an audio input device
- StopWatch speaker for Voice Chat output
- USB HID compatibility
- OTA updater and rollback
- Multiple Bluetooth host slots
- Production-grade authenticated BLE transport
