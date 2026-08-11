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

Do not send account identifiers, access tokens, prompts, task text, or other
private content to the watch.
