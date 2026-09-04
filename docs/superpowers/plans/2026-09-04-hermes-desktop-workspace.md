# Hermes Desktop Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use executing-plans in this session. Do not use subagents. Steps below are tracked as implementation proceeds.

**Goal:** Add HERMES, three-app left-swipe cycling, borderless shared controls and a 12-color gesture palette without modifying the installed system.

**Architecture:** Extend the existing lease and foreground coordinator, route neutral direction events through fixed app profiles, and share the existing firmware renderer. Keep palette state local and drawing pure.

**Tech Stack:** C++17, ArduinoJson 6, M5GFX, USB-mic PlatformIO, SwiftPM/macOS 14+, AppKit, IOKit HID, CoreGraphics.

## Global constraints

- Spec: `docs/superpowers/specs/2026-09-04-hermes-desktop-workspace-design.md`.
- Branch `feature/hermes-desktop-workspace`; source baseline `3c955f3`.
- Exact app IDs: `com.openai.codex`, `com.zarifpour.superconductor`, `com.nousresearch.hermes`.
- Report ID 6, full reports 64 bytes, payload fragments 61 bytes; unchanged radial wire protocol.
- Heartbeat 5 seconds, lease 15000ms, visual/decoder cooldown 800ms, write log interval 60 seconds.
- No account/application content, global keys, runtime shell/AppleScript, private Space API, audio output endpoints, installation, flash, push or merge.
- Use private temporary scratch paths for builds/harness; preserve XCTest source and report SDK/XCTest limitations separately.

## Task 1 — Three-mode lease

Files: `include/WorkspaceMode.h`, `simulator/workspace_mode_test.cpp`, `simulator/workspace_input_policy_test.cpp`, `scripts/hid_rpc_probe.swift`.

Interface: add `Mode::Hermes` and `Command::Hermes`; retain `parse`, `Lease::apply`, `disconnect`, `expire`, `mode`.

- [x] Write failing assertions for `parse({mode:hermes,ttl_ms:15000})`, invalid Hermes TTL/extra keys, owner SUPER↔HERMES transitions, other-owner denial, deadline, disconnect and rollover.
- [x] Compile/run with `clang++ -std=c++17 -Wall -Wextra -Werror -Iinclude -I<ArduinoJson/src> simulator/workspace_mode_test.cpp -o <scratch>/workspace-mode`.
- [x] Extend strict parser and lease without changing RPC disposition or wire framing. Owner checks apply to every non-Codex mode: `if (mode_ != Mode::Codex && ownerConnectionId_ != connectionId) return false;`.
- [x] Verify policy applies equally to Hermes; add fixed `--workspace-hermes` diagnostic and probe self-test.
- [x] Run native tests, review diff, commit `feat: add Hermes workspace lease`.

## Task 2 — Pure palette and shared renderer

Files: new `include/WorkspacePalette.h`, new `simulator/workspace_palette_test.cpp`; `include/SuperWorkspaceUi.h`, `simulator/super_workspace_ui_test.cpp`, `simulator/preview_main.cpp`.

Interfaces: `workspace_palette::Palette::acceptSwipe(uint32_t nowMs, Random next)` returns whether colors changed; `colors()` returns four RGB565 values. Shared UI State adds fixed profile enum and four border colors.

- [x] Failing tests: four distinct in-pool RGB565 values, each changes, random source called exactly four times, 799ms rejected/800ms accepted, rollover, stable getters; use deterministic RNG.
- [x] Implement bounded per-position candidate selection excluding used colors and that position's previous color. No renderer randomness.
- [x] Failing renderer tests: CYCLE/NEW text, no independent center outline, untouched triangle base geometry, stable label colors, no project/session/quota fields. Use a recording surface for actual renderer calls.
- [x] Implement profile-dependent title/right label, center interior fill only, retained power/status/battery. Fit Hermes title without changing Codex font behavior.
- [x] Add Hermes preview scenarios and generate native framebuffer previews to scratch, inspect corners and text visually.
- [x] Run palette/UI tests and commit `feat: share workspace controls with gesture color palettes`.

## Task 3 — Firmware integration

Files: `src/main.cpp`, input policy tests, `include/WorkspaceMode.h` helpers if needed.

- [x] Test `isDirectional(mode)` and mode transition/Agent baseline decisions for all mode pairs; fail before adding helpers.
- [x] Replace SUPER-only active checks with SUPER/HERMES. Transfer fixed profile and palette colors into UI State.
- [x] Call palette acceptance once after classifying a real swipe, never in render/heartbeat/foreground handling. Keep joystick release and haptics unchanged.
- [x] Retain poll→snapshot→transition→input ordering, release held inputs, synchronize Agent baseline whenever entering/leaving/staying directional modes, preserve sleep and power behavior.
- [x] Run all native tests and `pio run -d usb-mic`; check changed code warnings and default target preprocessing isolation.
- [x] Review integration and commit `feat: integrate Hermes controls on C152`.

## Task 4 — Profiles, neutral directions and app cycling

Files: new `WorkspaceAppProfile.swift`, new `WorkspaceCycleController.swift`; existing HID decoder, command router, key emitter, workspace application adapter; corresponding XCTest files.

Interfaces: `CompanionShortcutEvent` has `.left/.up/.down/.right`. `WorkspaceAppProfile` maps exact bundle IDs to `.codex/.super/.hermes`, next target and fixed command; `WorkspaceCycling.cycle()`; controller `start()/stop()` owns request observer and 3-second timeout.

- [x] Write XCTest expectations for four decoded angles, full circular sequence, unknown-frontmost→Codex, pending-request suppression, rejection, failed launch, timeout, external activation, stale completions after stop/restart.
- [x] Attempt `swift test --package-path companion --sdk <15.4-sdk> --scratch-path <scratch>`. If XCTest unavailable, execute the same behavior cases in clearly labeled temporary harnesses.
- [x] Implement generation-guarded cycle controller using WorkspaceApplications, observer and scheduler. Activate existing processes with `activate(options: [])`; no previous-app restoration.
- [x] Router maps exact current foreground to fixed commands: SUPER arrows with Ctrl-Option; Hermes Ctrl-Shift-Tab/Ctrl-Tab/Cmd-T. Emitter revalidates exact PID/bundle/foreground before posting down/up pairs.
- [x] Assert no events for non-target/stale PID, no automatic command retry, once-only Accessibility warning and left operation without Accessibility.
- [x] Keep compatibility concerns confined to runtime IDs/wire protocol, not obsolete internal SUPER event names. Review and commit `feat: cycle desktop apps and route Hermes shortcuts`.

## Task 5 — Writer, coordinator and watch lifecycle

Files: `WorkspaceModeHIDWriter.swift`, `WorkspaceModeCoordinator.swift`, `main.swift`, coordinator/writer/runtime XCTest.

- [x] Failing tests for Hermes RPC bytes, SUPER→HERMES immediate write plus updated heartbeat, reconnect current mode, bounded Codex retry, cancel old retry on new mode, stale timer callbacks after restart.
- [x] Add `.hermes` and fixed request string. Resolve desired mode from profile, keep one repeating lease timer reading latest mode.
- [x] Retry failed Codex devices at most twice at 5-second intervals; cancel on success/detach/new foreground/stop. Log failures once per 60 seconds.
- [x] Wire cycle controller start/stop inside real watch only; stop controller/coordinator before HID listener. Keep quota loop and RunLoop behavior unchanged.
- [x] Run release with warnings as errors, mode/RunLoop/lifecycle tests and json-only smoke. Commit `feat: synchronize Hermes screen in watch mode`.

## Task 6 — Docs, full verification and branch review

Files: `README.md`, `README.zh-CN.md`, `companion/README.md`, `docs/COMPANION_PROTOCOL.md`, curated native previews, plan evidence.

- [x] Update three-workspace controls/images, prerequisites, failure semantics, unchanged privacy boundaries, 12-color local feedback and two-component rollback.
- [x] Run all native tests, native preview and USB-mic build. Run HID RPC self-test, USB-mic self-test, Swift release, XCTest attempt, available harness suite and json-only/mode smoke tests.
- [x] Review entire `3c955f3..HEAD` for ownership, lifecycle, stale callbacks, failed writes, key release, no background injection, sleep and audio boundaries. Reproduce/fix any blocking findings separately.
- [x] Record actual results by layer, commit `docs: explain three workspace controls and validation`.
- [x] Preserve branch/worktree and artifacts; report installation/physical acceptance pending. Do not flash or change installed companion under this plan.

## Evidence

Implementation was performed serially in this session. Source/test tasks and
documentation are complete; no installation, flash, push, merge or cleanup was
performed. Detailed results and environment limits are recorded in
[validation evidence](2026-09-04-hermes-desktop-workspace-validation.md).

| Task | Commit / evidence |
| --- | --- |
| 1 | `c978f80`: strict Hermes parse/lease and fixed diagnostic; native/probe RED→GREEN |
| 2 | `c904870`: bounded palette and actual renderer-call tests; native RED→GREEN and framebuffer |
| 3 | `8cc8136`: C152 integration, transition helpers and isolated USB build |
| 4 | `6cf0b5d`: cycle/router/emitter; temporary harness caught and verified stale-observer fix |
| 5 | `359c878`: Hermes writer/coordinator, bounded retries and watch lifecycle |
| Review fix | `b03c2f0`: disabled directional touch wake; policy RED→GREEN, USB rebuild |
| 6 | This documentation commit; 10 native tests, 53 temporary Swift test bodies, builds and smoke checks |

Checked XCTest steps mean **attempted**, not passed. Full XCTest is unavailable
because the installed Command Line Tools lack the XCTest module. Hardware
acceptance remains outstanding and is not represented by these checkboxes.
