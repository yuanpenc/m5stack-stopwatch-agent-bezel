# super.engineering StopWatch Workspace Screen Design

**Date:** 2026-08-30

**Status:** Draft for review

**Target:** M5Stack StopWatch Dev Kit C152 running the installed USB microphone firmware, plus the existing macOS `CodexWatchCompanion`

## Summary

When super.engineering becomes the foreground macOS application, the physical
StopWatch switches from the Codex dashboard to a dedicated `SUPER` screen. The
screen presents only the four workspace gestures already implemented by the
companion: return, previous project, next project, and next session tab.

The companion follows foreground-application changes and sends a small,
fixed-enum workspace-mode message to the exact matched C152 over the existing
vendor HID report ID 6 channel. A five-second heartbeat and a fifteen-second
firmware lease prevent the watch from remaining in SUPER mode if an exit update
is lost or the companion stops. No project name, session name, window title,
conversation content, workspace data, or credential crosses the HID channel.

This feature extends both the companion and the USB microphone firmware, so the
physical device must eventually be rebuilt and reflashed. A flash is not part
of design approval and must still follow the repository's separate recovery,
port-resolution, confirmation, and physical-verification requirements.

## Goals

- Automatically show a dedicated physical `SUPER` screen whenever
  `com.zarifpour.superconductor` is the foreground application.
- Automatically restore the normal Codex dashboard when that application
  leaves the foreground, regardless of how the user switched applications.
- Make the four available gestures legible directly on the watch without
  exposing project or session information.
- Isolate SUPER mode so unrelated Codex and ChatGPT controls cannot be invoked
  accidentally.
- Recover safely from a lost exit message, companion restart, device removal,
  or HID write failure.
- Preserve quota synchronization, USB microphone behavior, the existing
  foreground command router, and automatic companion startup.

## Non-goals

- Reading or displaying project names, session names, window titles, tab
  labels, prompts, conversation content, files, workspaces, or credentials.
- Creating or managing macOS Spaces; the existing manual Space assignment
  remains unchanged.
- Changing the existing super.engineering keyboard shortcuts or gesture-to-
  command mappings.
- Implementing a general remote-display, arbitrary-text, or macro protocol.
- Using the private quota BLE service for screen-mode synchronization.
- Waking a sleeping StopWatch display merely because the foreground
  application changed.
- Modifying the default non-microphone firmware target in this iteration.

## User Experience

### Codex mode

The existing Codex dashboard and all existing controls behave as they do now.
Entering or leaving SUPER mode must not reset quota state, health state,
battery state, or other dashboard data.

### SUPER mode

The dedicated screen uses a visually distinct palette and contains:

- the title `SUPER`;
- `LEFT  BACK`;
- `UP  PREV PROJECT`;
- `DOWN  NEXT PROJECT`;
- `RIGHT  NEXT TAB`;
- minimal battery and host-connection status.

It deliberately omits Codex quota, Agent buttons, Agent state, project names,
and session names. The exact typography and placement may adapt to the existing
display primitives, but all four labels must remain readable without scrolling
and the screen must be visually distinguishable from the Codex dashboard.

The firmware redraws immediately when the display is awake. If the display is
asleep, it records the latest mode without forcing a wake; the next normal wake
renders the correct screen. This avoids adding foreground-following battery
drain.

### Input isolation

While SUPER mode is active:

| Control | Behavior |
| --- | --- |
| Swipe left | Existing companion route returns from super.engineering |
| Swipe up | Existing companion route selects the previous project |
| Swipe down | Existing companion route selects the next project |
| Swipe right | Existing companion route selects the next session tab |
| Power control | Retains its existing power and travel behavior |
| Six Agent touch targets | Disabled |
| Center Send touch target | Disabled |
| Left physical ChatGPT button | Disabled |
| Right physical ChatGPT button | Disabled |

Valid swipes retain the existing haptic response. Disabled controls must not
emit HID actions, change Agent state, or provide a success haptic. Returning to
Codex mode restores all existing controls automatically.

## Architecture and Data Flow

### Companion foreground coordinator

A `WorkspaceModeCoordinator` runs only in the companion's real `--watch` mode.
It observes foreground-application changes through `NSWorkspace` on the main
run loop and compares only the foreground bundle identifier with
`com.zarifpour.superconductor`.

The coordinator maintains the desired mode:

- exact bundle match: `super`;
- every other foreground state, including no resolved application: `codex`.

It sends the desired mode immediately when the foreground state changes. While
the desired mode is `super`, it refreshes the lease every five seconds. It also
resends the current desired mode after a matching C152 reconnects and when the
watch lifecycle starts, so companion and firmware restart order does not leave
them permanently out of sync.

Foreground observation and timer callbacks are serialized on `MainActor`.
HID writes use the listener's exact matched device instance rather than opening
or selecting a second device by product name.

### HID output transport

The design reuses the existing vendor HID channel because it already supports
macOS-to-device output reports and applies the exact C152 identity match:

- vendor ID `0x303A`;
- product ID `0x8360`;
- usage page `0xFF00`;
- usage `1`;
- report ID `6`.

Messages use the established 64-byte framing:

```text
[report ID 0x06][STX 0x02][payload length][UTF-8 JSON fragment][zero padding]
```

The transport uses `IOHIDDeviceSetReport` with an Output report. Serialization,
61-byte fragmentation, newline termination, length validation, and the OS call
remain behind a narrow injectable writer so framing and failure behavior can be
tested without a physical device. The full macOS buffer includes report ID 6;
the firmware continues accepting both report-ID-included raw reports and the
63-byte HOGP body because BLE stacks may strip the ID.

The private quota GATT service is not used. Keeping workspace display state on
the vendor HID path avoids coupling the screen to quota discovery, pairing,
account data, or the currently unreliable BLE quota connection.

### RPC contract

The only new method is `host.workspace_mode`.

Enter or refresh SUPER mode:

```json
{"method":"host.workspace_mode","params":{"mode":"super","ttl_ms":15000},"id":1}
```

Restore Codex mode:

```json
{"method":"host.workspace_mode","params":{"mode":"codex"},"id":2}
```

Requirements:

- `mode` accepts only the fixed strings `super` and `codex`.
- `super` requires `ttl_ms`; the initial implementation accepts only the
  protocol constant `15000` to avoid turning the message into a general lease
  controller.
- `params` must be an object. SUPER parameters contain exactly `mode` and
  `ttl_ms`; Codex parameters contain exactly `mode`. Missing or additional
  parameter keys are rejected.
- Request identifiers increase for diagnostics but responses are not used as a
  second state machine. Successful `IOHIDDeviceSetReport`, repeated heartbeats,
  and the firmware lease provide delivery and recovery semantics.
- JSON-RPC response reports contain no `method` and therefore remain ignored by
  the existing radial-event decoder.

Only fixed mode values are transmitted. No caller-supplied display text or
application metadata is permitted.

### Firmware workspace state

The USB microphone firmware adds a two-value `WorkspaceMode` state:

- `Codex`;
- `Super`, carrying only the last valid heartbeat time and the fixed lease
  duration.

A valid `super` request sets SUPER mode and refreshes its lease. A valid `codex`
request restores Codex mode immediately. The main loop checks expiration with
wrap-safe unsigned elapsed-time arithmetic; after fifteen seconds without a
valid SUPER refresh, it restores Codex mode and redraws if the screen is awake.

The firmware records the connection ID that supplied the current SUPER lease.
Disconnecting that exact host connection clears SUPER mode immediately; another
connection cannot inherit or refresh its state accidentally. A lost exit report
while the owning HID connection remains present is covered by the fifteen-
second lease. Invalid or malformed requests do not refresh the lease.

`host.workspace_mode` is control-plane display state, not evidence that Codex
itself is alive. Handling this method must therefore not call the existing
Codex host-activity promotion path or set `hostRpcObserved`. The RPC dispatch
boundary must distinguish a message being handled from a message that counts
as Codex host activity.

The renderer selects either the existing Codex dashboard or a dedicated SUPER
renderer from the workspace mode. Both renderers consume common battery and
connection indicators without owning protocol or input-routing state.

## Lifecycle and State Transitions

| Event | Companion action | Firmware result |
| --- | --- | --- |
| Companion starts, super.engineering foreground | Send `super` immediately | Show/store SUPER; start 15 s lease |
| Companion starts, another app foreground | Send `codex` immediately | Show/store Codex |
| super.engineering becomes foreground | Send `super`; begin 5 s heartbeat | Show SUPER and refresh lease |
| Another app becomes foreground | Stop heartbeat; send `codex` | Restore Codex immediately |
| Matching C152 reconnects | Resend current desired mode | Reconcile with actual foreground state |
| HID device disconnects | Drop only that device writer/state | Restore Codex immediately |
| One heartbeat write fails | Rate-limited warning; retry next cycle | Existing lease continues until timeout |
| No valid heartbeat for 15 s | No companion assumption required | Restore Codex automatically |
| Display sleeps or wakes | Do not force wake | Store mode; render current mode on wake |

The existing gesture decoder, 800-millisecond global accepted-gesture
cooldown, per-device input decoder, targeted command emitter, and application
toggler remain unchanged. Workspace-mode synchronization is an adjacent output
responsibility of the real watch lifecycle.

## Failure Isolation and Logging

- HID output errors emit a bounded, rate-limited warning and do not stop input
  reports, foreground routing, quota retry, USB microphone operation, or the
  companion run loop.
- A foreground transition during a write may produce a stale message, but the
  next immediate transition send or five-second heartbeat reconciles it; the
  firmware lease bounds stale SUPER state.
- Removing one matched device clears only that device's decoder and writer.
  Reconnection creates fresh per-device state and triggers a mode resend.
- Unsupported firmware may reject or ignore the method. The companion continues
  operating its existing gestures; a successful transport write is never
  treated as physical confirmation that the screen changed.
- Malformed JSON, wrong report ID, invalid method, invalid mode, invalid TTL,
  and oversized payloads do not change workspace mode.
- Routine heartbeat success is not logged. Warnings are rate-limited to avoid a
  five-second log flood.
- Logs may contain the fixed mode words `super` and `codex` and generic delivery
  outcomes. They must not include project names, session names, titles,
  workspaces, credentials, device UUIDs, or report payload dumps.

## Permissions and Privacy

No new macOS permission is required beyond the companion's existing Input
Monitoring and Accessibility permissions. The mode writer uses the already
matched HID device and does not use AppleScript, shell commands, private Space
APIs, screen scraping, Accessibility UI inspection, or application content.

The foreground coordinator reads only the bundle identifier needed for exact
application classification. It does not inspect titles, menus, tabs, project
lists, session lists, filesystem state, or super.engineering configuration.

## Automated Verification

### Firmware tests

- Parse valid `super` and `codex` requests.
- Reject missing, unknown, or non-string modes and missing, negative,
  non-integral, wrong, or overflowing TTL values.
- Prove that only valid SUPER messages refresh the lease.
- Prove wrap-safe fifteen-second expiration, owning-connection isolation, and
  immediate owner-disconnect reset.
- Prove `host.workspace_mode` does not promote Codex liveness.
- Prove SUPER input isolation and complete restoration in Codex mode.
- Exercise awake redraw and asleep state retention.
- Render a native preview or equivalent deterministic screen check for all four
  action labels and the absence of quota and Agent controls.

### Companion tests

- Serialize both fixed RPC shapes within the report-size limit.
- Verify exact report ID, STX byte, payload length, UTF-8 bytes, and padding.
- Reject an absent or stale matched device writer.
- Map exact foreground bundle identifiers to the correct desired mode.
- Verify immediate transition sends, five-second SUPER heartbeats, no Codex
  heartbeat, startup sync, reconnect sync, and timer cancellation.
- Verify foreground and HID callbacks remain serialized through the main run
  loop and `MainActor` boundary.
- Verify repeated write failures are warning-limited and do not terminate the
  watch lifecycle or quota retries.
- Verify `--json-only` and other non-watch modes never start observation,
  heartbeat timers, or HID output.

The repository keeps authoritative XCTest and native test sources. If the
installed Command Line Tools still cannot load XCTest, temporary production-
source harnesses provide additional RED/GREEN evidence, but their results are
reported explicitly as harness results rather than full XCTest execution.

### Build and smoke checks

- Warning-free USB microphone firmware build.
- Warning-free companion release build.
- Companion `--json-only` smoke test.
- Watch-mode gating, responsive run-loop, input callback lifecycle, output
  callback lifecycle, and quota-failure retry harnesses.
- Review the full branch diff for HID lifetime safety, MainActor isolation,
  lease arithmetic, privacy boundaries, and regressions in existing controls.

## Installation and Physical Acceptance

Implementation completion does not imply physical validation. Installation
requires the established C152 workflow:

1. Preserve a known factory-firmware recovery path.
2. Build the isolated USB microphone firmware target.
3. Resolve the exact newly connected `/dev/cu.*` device immediately before
   upload and obtain explicit user confirmation for that exact port.
4. Flash only after confirmation, then verify USB audio enumeration, HID/RPC,
   BLE behavior, and controls separately because this image has no normal USB
   serial console.
5. Back up the installed signed companion, replace only its executable,
   re-sign it, and restart the existing LaunchAgent without rewriting the
   device UUID, Codex path, or log configuration.

Physical acceptance must separately observe:

- foreground super.engineering changes the awake watch to the SUPER screen;
- leaving through left swipe, Command-Tab, Dock, or another normal macOS route
  restores the Codex screen;
- a mode change while the display sleeps appears correctly on the next wake
  without the transition waking the display;
- all four SUPER gestures invoke their accepted actions;
- Agent targets, Send, and both ChatGPT physical buttons produce no action in
  SUPER mode and recover fully in Codex mode;
- duplicate suppression remains effective;
- stopping the companion or withholding heartbeats restores Codex within the
  designed fifteen-second bound;
- disconnect and reconnect reconcile to the actual foreground application;
- Input Monitoring, Accessibility, quota updates, automatic startup, and the
  existing macOS Space workflow remain functional;
- USB microphone enumeration and a short input capture show no regression;
- ChatGPT's existing up, down, and right behavior still works after returning
  to Codex mode.

Every unobserved physical result remains explicitly marked unverified.

## Rollback

- Restore the preserved signed companion and restart the same LaunchAgent.
- Flash the preserved previous USB microphone firmware through the same exact-
  port confirmation and recovery-safe workflow.
- The existing manual macOS Space assignment and super.engineering shortcut
  configuration may remain; neither depends on the new physical screen.
- No account state, application preferences, project data, or session data is
  migrated by this feature.

## Approval Record

The user approved the following design decisions before this document was
written:

- reuse report ID 6 HID Output RPC rather than the private quota BLE service;
- follow the foreground application automatically using the exact
  `com.zarifpour.superconductor` bundle identifier;
- show a lightweight SUPER screen containing fixed four-direction actions but
  no project or session names;
- isolate SUPER mode to the four swipes and power behavior;
- refresh SUPER mode every five seconds and restore Codex after fifteen seconds
  without a heartbeat;
- store foreground mode changes while the display sleeps without forcing a
  wake;
- keep mode synchronization independent from Codex liveness, quota, USB audio,
  and the existing shortcut router.

Final document approval remains pending review of this committed specification.
