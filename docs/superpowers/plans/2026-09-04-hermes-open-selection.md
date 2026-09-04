# Hermes Open Selection Implementation Plan

**Status:** Implemented, installed and agreed physical acceptance complete.
See the [final acceptance record](2026-09-04-hermes-open-physical-acceptance.md)
for observed results and limits; original implementation constraints below
describe the pre-installation phase.

> **For agentic workers:** Use `executing-plans` in this session, serially,
> with test-driven development and no subagents.

**Goal:** Preserve existing Hermes up/down browsing and use right swipe to
commit the highlighted session with a Control press/release, labeled OPEN.

**Architecture:** Only the existing fixed-command Companion mapping and the
shared renderer's Hermes label change. Exact foreground/PID validation remains
in the emitter. No Hermes extension, plugin or sidebar metadata access.

**Tech Stack:** Swift/AppKit/CoreGraphics, C++ shared framebuffer renderer,
SwiftPM fixed macOS 15.4 SDK, native tests and USB-mic PlatformIO.

## Approved scope and constraints

- Baseline `d66984f`, `feature/hermes-desktop-workspace`.
- User canceled source extension, requested right-swipe opening, physically
  confirmed pressing/releasing Control opens the highlighted session, and
  approved implementation. This supersedes the project-sidebar extension plan.
- Keep Hermes Control-Shift-Tab / Control-Tab unchanged. Right is no longer
  Command-T and never sends Enter. Left/SUPER/Codex are unchanged.
- Control uses key code 59: down with `.maskControl`, up with empty flags.
  CoreGraphics creates modifier `flagsChanged` events for that key; do not
  force them into ordinary key-down/up events or leave Control set on release.
- Only exact foreground `com.nousresearch.hermes` receives the fixed pair.
  Keep permission checks, release gating, 800ms debounce and no auto-retry.
- Do not inspect whether the picker is open. Hermes owns selection and confirm
  semantics; with no picker, no new-Tab or message-send key is emitted.
  Version-dependent application behavior still needs physical acceptance.
- No application source/config access, plugin installation, global events,
  new protocol, LaunchAgent changes, app replacement, push or merge.
- Save new builds separately; existing backups remain. Installation and flash
  require separate review, with fresh exact-port approval before flashing.

## Task 1: Fixed confirmation pair

**Files:** `companion/Sources/CodexWatchCompanion/WorkspaceAppProfile.swift`,
`SuperEngineeringKeyEmitter.swift`, and corresponding router/emitter tests.

- [x] Change the emitter test expectation for the old right command to two
  strokes: `(59, true, .maskControl)` then `(59, false, [])`; retain literal
  expectations for both Tab browsing chords and cross-app rejection.
- [x] Run the temporary Swift test-body harness and observe a behavioral RED:
  existing right mapping sends key 17 / Command instead of the expected pair.
- [x] Rename `newHermesTab` to `confirmHermesSelection` in profiles and tests.
- [x] Implement the right pair with separate release flags; other commands
  continue to use their original flags on both down and up.
- [x] Run all actual test bodies in the temporary harness, and attempt XCTest.
  Preserve an environment failure separately; do not call the harness XCTest.
- [x] Review the fixed command, foreground/PID guards and no-retry boundary;
  commit the Companion change independently.

## Task 2: OPEN renderer label

**Files:** `include/SuperWorkspaceUi.h`,
`simulator/super_workspace_ui_test.cpp`, `artifacts/hermes-workspace-preview.png`.

- [x] First assert the actual rendered HERMES strings include OPEN and exclude
  NEW and PROJECT; observe failure against the old renderer.
- [x] Replace only the Hermes-specific right label with OPEN.
- [x] Compile and execute all 11 native tests with `-Wall -Wextra -Werror`.
- [x] Build native preview and render HERMES normal, right-active, charging,
  unknown/full battery, offline and power overlay; inspect label bounds.
- [x] Build USB-mic, inspect diagnostics and record firmware fingerprint.
- [x] Review the label-only renderer change and commit it independently.

## Task 3: Documentation and release verification

**Files:** `README.md`, `README.zh-CN.md`, `companion/README.md`, this plan,
and status annotations on the superseded sidebar design/capability gate.

- [x] Replace new-Tab guidance with browse/confirm guidance in both languages.
  Explain that native picker order is not guaranteed to be project-tree order.
- [x] Mark the canceled Hermes extension explicitly; do not erase historical
  evidence or leave an active instruction to create its source worktree.
- [x] Build Companion release using macOS 15.4 SDK and private scratch/cache.
- [x] Run synthetic `--demo --json-only` and verify JSON structure without
  contacting the real account or recording its quota values.
- [x] Review full baseline diff and `git diff --check`; commit documentation
  and generated preview. Report code, builds and hardware separately.
- [x] Show the OPEN preview and stop before installed-app replacement/flash;
  the user subsequently approved installation and the freshly resolved port.

## Physical acceptance after separately authorized installation

- [x] In Hermes, up/down selects the expected highlighted item; right opens it.
- [x] Repeated right does not create sessions or send draft text.
- [x] Without a picker, right does not send or alter draft text.
- [x] Left leaves Hermes; SUPER right remains next Tab; Codex original controls
  remain intact; no background action or stuck Control modifier.
- [x] USB microphone, workspace lease and quota behavior remain functional.

Keyboard confirmation and installed physical swipe acceptance were separate
checks. The user subsequently confirmed all items above on the installed C152.

## Verification record

- Companion source commit: `69ee116`; renderer/preview commit: `3bd2ff5`.
- RED observed: emitter returned key 17/Command instead of key 59/Control with
  empty release flags; renderer omitted OPEN. Both failed before implementation.
- GREEN: all 53 temporary Swift test bodies passed, including router/emitter,
  decoder, lifecycle, writer/coordinator, RunLoop and quota-retry coverage. This
  is a test-body harness, not a complete XCTest runner.
- All 11 native test executables passed with `-Wall -Wextra -Werror`.
- Native preview built and seven HERMES scenarios rendered and inspected at
  466x466. One existing third-party M5GFX VLA warning remains in native build.
- USB-mic build passed, both environments successful, no warning/error diagnostics.
- First Swift release attempt selected the default SDK for manifest/toolchain
  work and failed due to the known compiler/SDK mismatch. Explicit SDKROOT and
  private module/cache paths fixed this; release passed with warnings as errors.
- Full `swift test` was attempted with the fixed SDK and remains unavailable:
  `no such module 'XCTest'`. It is not marked passing.
- Synthetic `--demo --json-only` returned a valid JSON object. No real account
  quota request was made by this smoke test.
- Serial specification and source review found no blocking change: only the
  Hermes right command and label differ, down/up browsing flags are preserved,
  and foreground/permission handling remains unchanged. No Hermes data access
  or new listener/timer was introduced. `git diff --check` passed.
- Firmware SHA-256:
  `a6a685cc8ee857b37faa912a58d7dcce1b12a3fdde5d154f2e18227b351a917f`.
- Unsigned build executable SHA-256 (installation signing will change it):
  `e81b795add2f2134477ce0ead2b925f5360b01c102a82b6a5ed488e52317fc25`.
- At implementation closeout this revision had not been installed or flashed.
  The separately authorized installation and agreed physical checks are now
  complete; see the final acceptance record linked above. Recovery backups
  remain private and retained. No push or merge was performed.
