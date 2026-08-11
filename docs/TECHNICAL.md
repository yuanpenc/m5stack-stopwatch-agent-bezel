# Technical protocol notes

The compatibility transport was developed with
[`imliubo/codex-micro-4-core2`](https://github.com/imliubo/codex-micro-4-core2)
as an implementation reference and targets an undocumented interface.

## BLE HID identity

| Field | Value |
| --- | --- |
| Device name | `Codex Micro` |
| Manufacturer | `Work Louder` |
| VID / PID | `0x303A` / `0x8360` |
| PnP source | `0x02` |
| Usage page | Vendor Defined `0xFF00` |
| Report ID | `6` |
| Input / Output body | 63 bytes each |

These identifiers are emitted solely for interoperability. They are not owned
or assigned to this project.

## Framing

Each BLE HOGP report body is:

```text
[0x02][payload length 0..61][UTF-8 JSON fragment][zero padding]
```

Outgoing JSON is newline-terminated and fragmented into 61-byte chunks. The
host and device exchange JSON-RPC-like messages.

## Methods used here

| Direction | Method | Purpose |
| --- | --- | --- |
| Device to host | `v.oai.hid` | Agent or command-key press/release |
| Device to host | `v.oai.rad` | Analog-direction event |
| Host to device | `sys.version` | Firmware version |
| Host to device | `device.status` | Profile, layer, battery, charging |
| Host to device | `v.oai.thstatus` | Six Agent status colors/effects |
| Host to device | `v.oai.rgbcfg` | Ambient/key light configuration |
| Host to device | `host.focused_app` | Focus notification, acknowledged |

`v.oai.rad` uses normalized turns and a press/release distance pair. The
StopWatch gesture recognizer locks to one direction after 52 pixels and sends:

| Swipe | Angle on press/release | Distance on press | Distance on release |
| --- | ---: | ---: | ---: |
| Right | `0.00` | `1.0` | `0.0` |
| Down | `0.25` | `1.0` | `0.0` |
| Left | `0.50` | `1.0` | `0.0` |
| Up | `0.75` | `1.0` | `0.0` |

The firmware does not assign actions to these directions. ChatGPT Desktop owns
the four user-configurable analog-stick mappings.

The original wide Mic key spans two switches, but the ChatGPT Desktop layout
used for physical validation exposed one combined Mic-key assignment. This port
therefore maps the left C152 button to Mic key `ACT10` and the right C152 button
to configurable Command Key 4 (`ACT09`). Assign `ACT09` to Toggle voice chat on
the host. The center touch target uses Send key `ACT12`.

## Connection and power telemetry

`BLE ONLY` is derived from the BLE server's reconciled live connection count.
`CODEX LIVE` additionally requires a complete, parseable host RPC with a
non-empty method in the current 0-to-connected epoch and expires after five
minutes without another host RPC. The companion's private GATT write never
counts as Codex liveness. Quota data independently becomes `SYNC STALE` after
three minutes; invalid JSON does not refresh that timer.

Battery level is sampled every 30 seconds. Charge state and VIN are sampled
every two seconds. Dock detection uses two consecutive samples with 4.0 V
entry and 3.5 V exit thresholds, rather than charge state, because a full
battery may stop charging while USB power remains present.

On the default image, desk sleep sends CO5300 Sleep In, releases QSPI, disables
physical M5IOE1 G8 (zero-based expander pin 7), and leaves BLE polling active.
Wake restores G8, pulses physical G5 (zero-based pin 4), and replays the pinned
panel initialization through the existing framebuffer. The build-time M5GFX
patch is exact-match and idempotent. Travel Mode releases held HID controls,
shows an offline warning, stops local feedback, and issues `M5PM1::shutdown()`.
It is normally triggered by a firmware-detected red-button double-click. PM1's
immediate hardware double-off is disabled and read back at boot so the clean
path runs first. A six-second center-dial hold is the fallback; red-button long
hold remains the hardware recovery/download gesture. PM1 power-button or VIN
insertion starts a cold boot. IMU motion and scheduled RTC wake are not
configured in this release.

## Observed limitations

- The protocol is private and may change without notice.
- The default firmware implements BLE HOGP only. The isolated optional target
  adds a standard microphone-only USB Audio Class interface; it is not part of
  the emulated Codex Micro protocol and does not expose USB HID or a speaker.
- The optional target pins Arduino-ESP32 3.3.11 and builds its own Bluedroid
  libraries before linking USB Audio. NimBLE's duplicate HID Report handling
  was not compatible with the Codex Desktop output-report handshake.
- USB capture uses two 10 ms I2S slots and a two-block, latest-wins handoff
  queue. Capture and USB transmission run in separate tasks so host
  back-pressure does not hold M5Unified's recording slots. Short USB writes
  retain their unwritten offset, while a full handoff queue drops the oldest
  complete block and records the discontinuity. The stream starts at TinyUSB's
  half-FIFO flow-control target and tops that target up with silence until the
  first post-enable PCM block arrives, so macOS receives valid packets without
  overfilling the FIFO during its USB Audio lock-delay window.
- The USB microphone configures the ES8311 for 24 dB analog PGA gain, 24 dB
  ADC scale, +6 dB ADC digital volume, and unity M5Unified software gain. The
  firmware writes and reads back all three codec gain registers after
  M5Unified's one-time sample-rate restart. This preserves the nominal level
  while giving speech peaks more analog headroom than the previous profile.
- Pairing is BLE `Just Works` bonding.
- One host is supported.
- No Codex quota data exists in this vendor protocol; see
  [COMPANION_PROTOCOL.md](COMPANION_PROTOCOL.md).
