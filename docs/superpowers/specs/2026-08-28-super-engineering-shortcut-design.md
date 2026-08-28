# super.engineering StopWatch Shortcut Design

**Date:** 2026-08-28

**Status:** Approved design; implementation and physical validation pending

**Target:** M5Stack StopWatch Dev Kit C152 with the optional USB microphone firmware

## Summary

Extend the existing macOS `CodexWatchCompanion` so a left swipe on the
StopWatch toggles between `super.engineering` and the application that was in
the foreground immediately before the toggle.

The chosen design reuses the firmware's existing vendor HID radial event. It
does not change or reflash firmware, does not call the `sc` CLI, and does not
read or mutate super.engineering workspaces, sessions, credentials, or
configuration.

This document records an approved design. It must not be treated as evidence
that the shortcut works until the implementation has been built, installed,
and observed on physical C152 hardware.

## Goals

- A single left swipe activates `super.engineering` from any ordinary foreground
  application.
- A subsequent left swipe while `super.engineering` is foreground returns to
  the previously recorded application.
- If `super.engineering` is not running, the first left swipe launches and
  activates it.
- The shortcut survives a StopWatch disconnect and reconnect without requiring
  a companion restart.
- Existing quota synchronization, automatic companion startup, USB microphone
  input, and the other StopWatch directions remain independent and continue to
  work.
- The listener consumes only the expected vendor HID report and does not record
  keyboard text or unrelated HID input.

## Non-goals

- Adding a dedicated firmware event or changing the BLE HID descriptor.
- Reflashing the StopWatch.
- Selecting a super.engineering workspace, model, agent, or chat.
- Creating a new super.engineering session.
- Calling `sc`, AppleScript, shell commands, or user-configurable commands.
- Providing a general-purpose application launcher or global shortcut system.
- Assigning behavior to up, right, or down swipes.

## Confirmed Environment Inputs

- The target application is installed as `super.engineering.app` and is
  identified by bundle identifier `com.zarifpour.superconductor`.
- The current StopWatch firmware emits radial vendor HID events with method
  `v.oai.rad` through report ID 6.
- A left press is represented by angle `a = 0.5` and distance `d = 1.0`; release
  uses `d = 0.0`.
- The vendor HID device is constrained by vendor ID `0x303A`, product ID
  `0x8360`, usage page `0xFF00`, and usage `1`.
- The installed companion runs continuously with `--watch` under a per-user
  LaunchAgent.

These inputs identify the intended integration points. The final implementation
must still verify actual runtime enumeration and behavior on the connected C152.

## Architecture

The companion gains two isolated responsibilities alongside its existing quota
sync loop:

1. `HIDShortcutListener` opens only the matching vendor HID interface, rebuilds
   framed JSON messages, recognizes a left-swipe press, and emits a logical
   shortcut event.
2. `SuperEngineeringToggler` receives that logical event and applies the
   foreground-application toggle policy through AppKit and `NSWorkspace`.

The listener and toggler must not be coupled to the Codex App Server client or
the BLE quota writer. A quota read/write failure must not stop HID listening,
and a HID or activation failure must not stop quota synchronization.

The HID listener is enabled only for normal continuous operation (`--watch`).
It remains disabled for one-shot quota writes, `--demo`, `--json-only`, and
bootloader operations so diagnostic commands preserve their current lifecycle
and permission surface.

## HID Input Processing

### Device matching

The listener matches all of the following before registering an input report
callback:

- vendor ID `0x303A`
- product ID `0x8360`
- usage page `0xFF00`
- usage `1`

Input reports are accepted only when they use report ID 6. Reports from other
keyboards, mice, HID collections, report IDs, or devices are ignored.

### Frame reconstruction

Report ID 6 carries a framed JSON fragment whose body starts with a fragment
marker and length followed by that many payload bytes. The listener maintains a
bounded receive buffer per connected matching device, appends validated fragment
payloads, and emits a message only after a newline terminator is received.

The receive buffer must be cleared when:

- a fragment marker or declared length is invalid;
- the accumulated message exceeds a small protocol-specific upper bound;
- JSON decoding fails at a completed newline-delimited message;
- the device disconnects.

Malformed input is discarded without invoking the application toggler. A later
well-formed message must be able to resynchronize without restarting the
companion.

### Gesture recognition and debouncing

A shortcut event is produced only when all of these conditions hold:

- `method` is exactly `v.oai.rad`;
- `params.a` is a finite number within a narrow tolerance of `0.5`;
- `params.d` is a finite number representing the press value `1.0`;
- the listener is armed for a new press;
- at least 800 milliseconds have elapsed since the previous accepted shortcut.

The matching `d = 0.0` release rearms the listener but does not trigger an
action. Non-finite values, missing fields, other directions, repeated press
frames, and unrelated methods are ignored. The release gate and cooldown work
together so one physical gesture produces at most one toggle, including when
reports are duplicated or arrive in a burst.

## Application Toggle Policy

Application discovery and activation use AppKit and `NSWorkspace`; no external
process or command interpreter is involved.

### Activating super.engineering

When the foreground application is not bundle ID
`com.zarifpour.superconductor`:

1. Record the current foreground application's process identifier and bundle
   identifier as the return target.
2. If super.engineering is already running, request activation of that running
   application.
3. Otherwise, locate the application by its bundle identifier and request that
   macOS launch and activate it.

The return target is updated only for a transition into super.engineering. The
companion itself and applications without a usable running-application identity
are not stored as return targets.

### Returning to the previous application

When the foreground application is super.engineering:

1. Prefer the previously recorded running application when its process
   identifier still refers to the same bundle identifier.
2. If that process no longer exists, do not launch a replacement application
   and do not select an arbitrary fallback.
3. Remain in super.engineering and report a bounded diagnostic message.

The remembered target may remain available after a failed return, allowing a
later gesture to succeed if the original process is still running but activation
temporarily failed.

### Activation failures

If super.engineering cannot be found, launched, or activated, the companion
performs no substitute action. It must not open a same-named application, run a
command, or alter any super.engineering state.

## Permissions and Privacy

The installed `CodexWatchCompanion.app` requires macOS Input Monitoring access
to receive vendor HID input. Bluetooth permission remains required for quota
synchronization.

Missing Input Monitoring permission degrades only the shortcut:

- the existing quota loop remains active;
- the listener emits a bounded, actionable warning rather than repeatedly
  flooding logs;
- no automated attempt is made to change System Settings.

The companion does not capture or retain keyboard text, clipboard data, prompts,
workspace contents, sessions, account data, or credentials. Logs are limited to
device connection state, shortcut recognition, activation/return outcome, and
actionable permission or application errors. They must not include user content
or a general stream of foreground-application activity.

## Failure Isolation and Recovery

- HID device removal clears only HID parsing state. Device addition causes the
  listener to register again automatically.
- Malformed HID input is discarded and resynchronized without terminating the
  continuous companion.
- Application activation errors are handled per gesture and do not terminate
  either the HID listener or quota loop.
- Codex App Server and BLE quota errors retain their current retry behavior and
  do not tear down the HID listener.
- Input Monitoring denial disables effective input delivery but does not block
  companion startup.

## ChatGPT Configuration

The existing ChatGPT mapping for Analog stick left must be unassigned before
physical validation. This avoids the same generic left event performing both a
ChatGPT action and the companion shortcut. Up, right, and down mappings remain
unchanged.

This is a user-visible configuration step; the companion does not edit ChatGPT
preferences itself.

## Testing Strategy

### Automated tests

The design requires testable boundaries around parsing and activation policy.
Tests cover at least:

- reconstruction of a JSON message split across multiple report fragments;
- more than one complete message across successive reports;
- invalid marker, invalid length, oversized buffer, malformed JSON, and
  recovery with a subsequent valid message;
- filtering by report ID, method, finite angle/distance, direction, and press
  versus release;
- repeated presses, release rearming, and the 800-millisecond cooldown;
- ordinary application to running super.engineering;
- ordinary application to launching super.engineering;
- super.engineering back to the exact recorded running application;
- stale process identifier and mismatched bundle identifier;
- missing super.engineering and failed activation;
- ensuring non-watch command modes do not start HID listening.

The application toggle policy should use an injectable workspace abstraction so
these cases can be tested without launching real applications.

### Build and regression checks

- Build the Swift package in release configuration.
- Run all companion tests.
- Exercise existing demo, JSON-only, and quota paths sufficiently to confirm the
  new continuous listener does not change their behavior.
- Verify the app wrapper remains correctly signed and the LaunchAgent still
  supplies its existing device identifier and Codex path without writing those
  local values into the repository.

### Physical C152 acceptance

After installing the rebuilt companion and granting Input Monitoring:

1. With ChatGPT foreground, one left swipe activates super.engineering.
2. A second left swipe returns to that ChatGPT process.
3. The same round trip works from Claude Code, Cursor, and another ordinary
   application.
4. When super.engineering is not running, a left swipe launches and activates
   it.
5. Rapid or duplicate input does not immediately toggle back.
6. If the recorded application exits, a left swipe from super.engineering does
   not open another application.
7. Disconnecting and reconnecting the StopWatch restores the shortcut without
   restarting the companion.
8. Up, right, and down controls still behave according to their unchanged
   ChatGPT mappings.
9. USB microphone enumeration and a short input capture remain successful.
10. Quota updates continue to reach the StopWatch, and the LaunchAgent still
    starts the companion after login or restart.

Build success alone is not sufficient. Results for companion build/tests,
installation/signing, Input Monitoring, HID recognition, application switching,
USB microphone, other controls, quota synchronization, and automatic startup
must be reported as separate validation layers.

## Installation and Rollback

Installation replaces only the locally installed companion app with a rebuilt,
signed version and restarts the existing per-user LaunchAgent. If macOS treats
the rebuilt executable as a new privacy identity, the user may need to remove
and re-add `CodexWatchCompanion.app` under Input Monitoring before restarting the
LaunchAgent.

No firmware upload is part of this change.

Rollback consists of stopping the LaunchAgent, restoring the previous signed
companion app, and starting the LaunchAgent again. Because the firmware and HID
descriptor are unchanged, no StopWatch recovery or reflash is needed.

## Key Risks and Mitigations

- **Duplicate gesture reports:** release gating plus an 800-millisecond cooldown.
- **Listening to unrelated input:** exact VID/PID/usage/report matching and
  method-level filtering.
- **Fragment desynchronization:** bounded per-device buffering with explicit
  reset and recovery rules.
- **Returning to the wrong application:** validate both process identifier and
  bundle identifier; never launch a fallback on return.
- **Shortcut failure affecting quota sync:** independent listener/toggler and
  quota lifecycles.
- **Privacy expansion:** no keyboard-text capture, content logging, shell, CLI,
  clipboard, or super.engineering state access.
- **ChatGPT double action:** explicitly unassign Analog stick left before
  acceptance testing.

## Approval Record

The user approved:

- a left-swipe trigger;
- direct companion HID listening (方案 A), without firmware changes;
- toggling back to the previous foreground application when super.engineering is
  already foreground;
- no-op behavior when the previous application has exited;
- the permission, failure-isolation, privacy, testing, installation, and
  physical acceptance design described above.
