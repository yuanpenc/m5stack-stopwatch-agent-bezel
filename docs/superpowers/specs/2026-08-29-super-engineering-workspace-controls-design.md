# super.engineering Dedicated Workspace Controls Design

**Date:** 2026-08-29

**Status:** Approved interaction and architecture; written-spec review pending

**Target:** M5Stack StopWatch Dev Kit C152 with the installed USB microphone firmware

## Summary

Extend the installed macOS `CodexWatchCompanion` so the StopWatch enters a
dedicated macOS Space for super.engineering and navigates that application's
projects and session tabs without taking the existing up, down, and right
gestures away from ChatGPT.

The implementation builds on the physically validated left-swipe shortcut. It
does not modify or reflash firmware. It uses super.engineering's own configurable
keyboard-shortcut actions and sends fixed key combinations only to the exact
foreground super.engineering process. It does not read project names, session
titles, conversation content, or super.engineering configuration files.

## Goals

- A left swipe from another application activates super.engineering and follows
  it to the macOS Space to which the user assigned the application.
- A left swipe while super.engineering is foreground returns to the exact
  previously foreground application and its Space.
- While super.engineering is foreground, up and down move to the previous and
  next project, and right moves to the next session tab with the application's
  normal wraparound behavior.
- While any other application is foreground, the companion ignores up, down,
  and right so ChatGPT's existing mappings continue to work.
- Existing quota synchronization, automatic startup, device reconnect, USB
  microphone input, and physical buttons remain independent.

## Non-goals

- Creating, deleting, ordering, or naming macOS Spaces programmatically.
- Using private CoreGraphics Services or undocumented Space-management APIs.
- Reading or selecting projects or sessions by name.
- Reading conversation text, prompts, terminal output, files, workspaces,
  credentials, or configuration files.
- Calling `sc`, a shell, AppleScript, or user-configurable commands.
- Providing an arbitrary keyboard macro or general application automation
  system.
- Adding previous-session navigation in this first iteration; right swipe moves
  forward and wraps using super.engineering's native Next Tab action.

## Confirmed Environment Inputs

- The physical C152 emits `v.oai.rad` reports for left, up, down, and right on
  report ID 6.
- The macOS IOHID callback supplies a 64-byte raw report containing the report
  ID as its first byte; the companion already normalizes this physical shape.
- super.engineering is identified only by bundle identifier
  `com.zarifpour.superconductor`.
- A local inspection of the installed application binary confirmed native,
  configurable actions for Previous Project, Next Project, Previous Tab, and
  Next Tab.
- The user approved macOS Accessibility permission for the companion.
- ChatGPT keeps its existing up, down, and right mappings. Only Analog stick
  left remains unassigned in ChatGPT.

## Dedicated Space Setup

The user creates a normal macOS Space, opens super.engineering there, and uses
the Dock's **Options → Assign To → This Desktop** setting. The companion does
not create or enumerate Spaces.

`NSRunningApplication.activate(options: [])` remains the entry mechanism. macOS
is responsible for following the assigned application to its Space. Returning
activates the remembered process identity; macOS likewise returns to that
application's Space.

If the application is not assigned to a dedicated Space, left swipe still
activates and returns correctly but no dedicated-desktop claim is made.

## Gesture Model

The pure HID decoder produces one of four logical radial events:

| Physical gesture | Angle | Companion behavior |
| --- | ---: | --- |
| Right | `0.00` | Next session tab when super.engineering is foreground |
| Down | `0.25` | Next project when super.engineering is foreground |
| Left | `0.50` | Enter or exit super.engineering |
| Up | `0.75` | Previous project when super.engineering is foreground |

All directions require the existing finite-number checks, narrow angle and
distance tolerances, press/release gate, per-device parsing state, and
800-millisecond accepted-gesture cooldown. One physical gesture emits at most
one logical event.

Left retains the current toggle behavior regardless of the foreground
application. Up, down, and right are context gated. When super.engineering is
not foreground, those events become companion no-ops and produce no routine log
traffic.

## Application Commands

The following fixed combinations are configured in super.engineering's own
**Keyboard Shortcuts** settings:

| super.engineering action | Fixed combination |
| --- | --- |
| Previous Project | `Control-Option-Up` |
| Next Project | `Control-Option-Down` |
| Next Tab | `Control-Option-Right` |

The companion does not read the application's shortcut configuration. Setup and
acceptance verify that these combinations invoke the intended native actions.

For each up, down, or right event, the command router:

1. reads only the current foreground application's PID and bundle identifier;
2. requires the bundle identifier to equal
   `com.zarifpour.superconductor`;
3. revalidates that the PID still belongs to that bundle identifier;
4. posts an arrow key-down and key-up pair carrying the fixed Control and Option
   modifier flags only to that PID through the public CoreGraphics event API.

The events are not posted as global keyboard input. The router does not search
menus, inspect accessibility labels, enumerate projects, or inspect tabs.

## Permissions and Privacy

Input Monitoring remains required for receiving StopWatch HID reports.
Accessibility permission is additionally required to deliver the three fixed
key combinations to super.engineering.

Missing Accessibility permission degrades only project and tab navigation:

- left-swipe activation and return remain available;
- quota synchronization and USB microphone input remain available;
- the companion emits one bounded, actionable warning per process lifetime;
- no automated attempt is made to change System Settings.

Logs may contain only the generic outcomes `previous project`, `next project`,
`next tab`, permission unavailable, target no longer foreground, and key-event
delivery failure. They must not contain application titles, project names,
session titles, UI labels, keyboard text, or content.

## Failure Isolation

- If super.engineering loses foreground status between the gesture and command
  delivery, the command is cancelled.
- If the PID exits or is reused by another bundle, the command is cancelled.
- A navigation failure does not change the remembered return application and
  does not stop HID listening or quota synchronization.
- Repeated or burst reports remain bounded by release gating and cooldown.
- Device removal clears only that device's decoder. Reconnection starts with a
  fresh decoder without restarting the companion.
- ChatGPT retains its existing up, down, and right mappings. Physical acceptance
  must prove that those mappings do not perform a visible background action
  while super.engineering is foreground. If they do, the feature remains
  unaccepted; the companion must not silently rewrite ChatGPT preferences.

## Component Boundaries

### Radial gesture decoder

Extends the pure decoder from one event to four typed direction events. It owns
framing, validation, release gating, cooldown, and resynchronization but knows
nothing about applications or key events.

### Foreground command router

Receives typed gestures. It sends left to the existing application toggler and
context-gates the other directions using an injectable foreground-application
adapter. It owns no HID or quota lifecycle.

### Process-targeted key emitter

Converts the three navigation commands to fixed CoreGraphics key sequences. It
revalidates the target identity before posting and exposes a small injectable
interface for tests. It cannot emit arbitrary caller-supplied keys or commands.

## Automated Testing

Tests and the temporary production-source harness cover:

- all four angles and rejection of angles outside tolerance;
- 64-byte physical macOS report normalization;
- release gating and the 800-millisecond cooldown across directions;
- malformed fragments, wrong report IDs, oversized buffers, and recovery;
- left always reaching the existing toggler;
- up, down, and right being ignored outside super.engineering;
- exact PID and bundle revalidation before each command;
- fixed mapping to `Control-Option-Up`, `Control-Option-Down`, and
  `Control-Option-Right`;
- arrow down/up ordering and modifier flags on both events;
- Accessibility denial warning once without interrupting other lifecycles;
- watch-only listener gating and quota-cycle retry isolation.

The current host lacks a usable XCTest module in its installed Command Line
Tools. XCTest source remains authoritative, while final verification also uses
a warning-free release build and temporary production-source harnesses. Harness
results are not described as full XCTest execution.

## Physical Acceptance

Validation is reported as separate layers:

1. **Space setup:** super.engineering is assigned to a dedicated Space.
2. **Shortcut setup:** the three fixed combinations are configured and work
   from the physical keyboard.
3. **Permissions:** Input Monitoring and Accessibility are both enabled for the
   installed companion identity.
4. **Entry and return:** left enters the super.engineering Space and returns to
   the exact previous application and Space.
5. **Project navigation:** up and down visibly select the previous and next
   project.
6. **Session navigation:** right visibly advances through session tabs and
   wraps according to super.engineering behavior.
7. **ChatGPT compatibility:** after returning, ChatGPT's up, down, and right
   mappings still work; no visible background ChatGPT action occurs while
   super.engineering is foreground.
8. **Robustness:** rapid duplicates do not double-advance, and disconnect plus
   reconnect restores controls without restarting the companion.
9. **Regression:** USB microphone enumeration and short capture, quota update,
   LaunchAgent running state, and automatic-start configuration remain valid.

No unobserved physical result is reported as verified.

## Installation and Rollback

Installation rebuilds the existing local companion, preserves a signed backup,
replaces only its executable, signs the local app, and restarts the existing
LaunchAgent without changing its device identifier, Codex path, or log paths.

Space assignment and super.engineering keyboard shortcuts are user-visible
setup actions. Changing macOS Accessibility settings requires action-time user
confirmation.

Rollback restores the preserved companion app and restarts the same
LaunchAgent. The user may then set the Dock assignment to None and reset the
three super.engineering shortcuts. No firmware rollback or device recovery is
required.

## Approval Record

The user approved:

- a manually prepared, dedicated macOS Space for super.engineering;
- Accessibility permission for process-targeted navigation;
- left for enter/exit, up/down for previous/next project, and right for next
  session tab;
- keeping ChatGPT's up, down, and right mappings while context-gating companion
  navigation to foreground super.engineering;
- the permission, privacy, failure-isolation, testing, installation, and
  rollback design above.
