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

## Observed limitations

- The protocol is private and may change without notice.
- The current firmware implements BLE HOGP only, not the original USB composite
  descriptor.
- Pairing is BLE `Just Works` bonding.
- One host is supported.
- No Codex quota data exists in this vendor protocol; see
  [COMPANION_PROTOCOL.md](COMPANION_PROTOCOL.md).
