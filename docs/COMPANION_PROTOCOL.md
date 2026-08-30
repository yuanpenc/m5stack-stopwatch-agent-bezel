# Mac companion to StopWatch protocol

This is a project-owned protocol. It is not part of Codex Micro.

## GATT

| Item | UUID |
| --- | --- |
| Service | `7f0d4e66-2ac2-4a71-bfbe-4ef61a0e5c01` |
| Quota write characteristic | `7f0d4e66-2ac2-4a71-bfbe-4ef61a0e5c02` |

The characteristic accepts Write and Write Without Response over an encrypted,
bonded BLE link. The first companion write therefore uses the same BLE bond as
HID. Payloads are UTF-8 JSON and must be no larger than 512 bytes.

## Snapshot schema

```json
{
  "remaining_percent": 26,
  "reset_in_seconds": 356400
}
```

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `remaining_percent` | number | yes | Clamped to 0 through 100 |
| `reset_in_seconds` | integer | yes | Relative countdown avoids a watch clock dependency |

## Companion behavior

1. Start or attach to a local Codex App Server using the user's existing local
   ChatGPT/Codex login context.
2. Call `account/rateLimits/read` at startup and after a rate-limit update.
3. Choose the primary Codex bucket explicitly; do not silently substitute a
   Spark or secondary bucket.
4. Convert the reset timestamp to `reset_in_seconds` at send time.
5. Require the Mac-specific CoreBluetooth UUID captured during the demo-only
   binding step, scan for that exact paired peripheral, discover this service,
   and write one complete JSON object. Never send real account quota to the
   first matching advertiser.
6. Refresh at most once per minute unless the App Server sends a change event.

Agent status and all button actions deliberately stay on the native Codex Micro
HID channel.

## Foreground workspace mode over HID

The optional USB-microphone firmware accepts one project-owned control RPC over
vendor Report ID 6. This channel changes only the rendered workspace mode; it
does not carry quota data or application content.

The macOS report passed to `IOHIDDeviceSetReport` is always 64 bytes:

| Offset | Value |
| --- | --- |
| 0 | Report ID `0x06` |
| 1 | RPC fragment marker `0x02` |
| 2 | UTF-8 payload length, 0 through 61 |
| 3 through 63 | Payload bytes followed by zero padding |

Requests are newline-terminated UTF-8 JSON. Payloads longer than 61 bytes are
split on byte boundaries into consecutive reports. HOGP normally strips the
report ID before delivering the 63-byte report body; the firmware accepts both
the stripped body and the full 64-byte form.

The only valid requests are:

```json
{"method":"host.workspace_mode","params":{"mode":"super","ttl_ms":15000},"id":1}
{"method":"host.workspace_mode","params":{"mode":"codex"},"id":2}
```

`super` requires exactly `ttl_ms: 15000`. `codex` permits only the `mode`
field. Missing fields, extra fields, wrong types, negative/floating/overflowing
TTL values, and any other TTL are rejected as `-32602 Invalid params` without
changing or renewing the lease.

The first valid `super` request owns the lease for its HID connection. The same
connection may renew it; another connection cannot take over or refresh it.
Any valid `codex` request exits safely, the owner's disconnect exits
immediately, and otherwise the firmware exits after 15 seconds using
wrap-safe `millis()` arithmetic. Renewals do not redraw an unchanged screen.
This method is classified as control-only: it never marks the Codex host RPC as
observed and cannot synthesize the `CODEX LIVE` state.

The companion watches the exact foreground bundle identifier
`com.zarifpour.superconductor`. It sends `super` immediately on entry and every
5 seconds thereafter, sends `codex` once on exit or orderly shutdown, and
immediately synchronizes each newly attached device. Output failures are
retried by later heartbeats and logged at most once per 60 seconds; they do not
stop HID input, quota refresh, or the main RunLoop. Foreground observation,
timers, and HID output exist only in a real `--watch` run.

While the display sleeps, mode changes update state without waking it. In
`SUPER` mode, firmware accepts only four radial swipes and the existing power /
Travel Mode behavior; Agent, Send, microphone/voice controls, and ChatGPT
physical buttons are isolated until the Codex dashboard returns.

This RPC sends only a fixed mode enum, fixed TTL, and request number. It never
contains project names, session titles, windows, Spaces, workspace data,
credentials, prompts, conversation content, or arbitrary display text. The
companion does not log report payloads or device identifiers for this channel.

## Optional maintenance request

Only the USB-microphone image accepts this write-with-response request:

```json
{"op":"enter_bootloader","version":1,"confirm":true}
```

The firmware accepts it only while USB power is present and only from the same
BLE peer that completed a valid Codex HID RPC in the current connection epoch.
It checks USB power again after a short delay before restarting into the
ESP32-S3 serial bootloader. The default wireless image ignores this operation.

An ATT acknowledgement proves delivery, not a restart. The companion reports
success only after the BLE link disconnects; the flashing workflow must still
discover and verify the newly enumerated `/dev/cu.*` port.

Do not send account identifiers, access tokens, prompts, task text, project or
session metadata, window/Space/workspace state, or other private content to the
watch.
