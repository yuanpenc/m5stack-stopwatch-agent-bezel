# StopWatch SUPER Workspace Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task in the current session. Steps use checkbox (`- [ ]`) syntax for tracking. Do not use subagents for this execution.

**Goal:** Add an automatically synchronized physical `SUPER` workspace screen to the USB-microphone C152 while preserving the existing Codex dashboard and companion behaviors.

**Architecture:** The macOS companion observes the exact foreground super.engineering bundle and sends a fixed-enum workspace mode over the existing report-ID 6 HID Output channel. The USB-microphone firmware owns a connection-bound 15-second SUPER lease, selects a dedicated renderer, and isolates non-workspace controls while that lease is active.

**Tech Stack:** C++17, ArduinoJson 6, ESP32-S3/Arduino, PlatformIO, M5GFX, Swift 5.10 language mode, AppKit/NSWorkspace, IOKit.hid, Swift Package Manager, XCTest source, macOS 14+

**Implementation baseline:** Branch `feature/super-engineering-shortcut`, commit `6dcb13b`.

## Global Constraints

- Target only the M5Stack StopWatch Dev Kit C152 running the USB microphone firmware.
- Do not change or flash the default non-microphone image for this feature.
- Preserve VID `0x303A`, PID `0x8360`, usage page `0xFF00`, usage `1`, report ID `6`, 64-byte macOS reports, and 61-byte JSON fragments.
- Use only `host.workspace_mode` with fixed `codex` and `super` enum values; never accept caller-provided display text.
- Use a five-second companion heartbeat and an exact fifteen-second firmware lease.
- Identify super.engineering only as `com.zarifpour.superconductor`.
- Do not use the quota BLE channel, AppleScript, shell commands, private Space APIs, UI scraping, or arbitrary macros.
- Never read or transmit projects, sessions, windows, workspaces, prompts, content, credentials, identifiers, or report dumps.
- Keep Input Monitoring, Accessibility, quota synchronization, USB audio, automatic startup, and existing shortcut routing independent.
- Preserve the current LaunchAgent, CoreBluetooth UUID, Codex path, log configuration, and signed app identity.
- Keep backups, generated apps, device identifiers, logs, captures, and harnesses outside Git.
- Treat source tests, harnesses, builds, installation, and physical C152 observations as separate validation layers.
- Never reuse a historical serial port. Resolve the exact current `/dev/cu.*` port and obtain explicit confirmation immediately before flashing.

---

### Task 1: Approve the specification and establish a recoverable baseline

**Files:**
- Modify: `docs/superpowers/specs/2026-08-30-super-engineering-stopwatch-workspace-design.md`
- Create: `docs/superpowers/plans/2026-08-30-super-engineering-stopwatch-workspace.md`

- [ ] Mark the reviewed specification Approved and save this plan.
- [ ] Verify the branch, baseline commit, worktree isolation, and clean starting state.
- [ ] Build the current USB-microphone image before production-code changes.
- [ ] Save the current `firmware.bin` and SHA-256 in a private `mktemp` directory under `/private/tmp`.
- [ ] Confirm the documented factory recovery path remains available without entering download mode or flashing.
- [ ] Commit as `docs: approve and plan stopwatch super workspace screen`.

### Task 2: Add the firmware workspace RPC and lease

**Files:**
- Create: `include/WorkspaceMode.h`
- Modify: `include/HostRpcRequest.h`
- Modify: `include/CodexMicroBle.h`
- Modify: `src/CodexMicroBle.cpp`
- Create: `simulator/workspace_mode_test.cpp`
- Modify: `simulator/host_rpc_request_test.cpp`
- Modify: `scripts/hid_rpc_probe.swift`

**Interfaces:**

```cpp
namespace workspace_mode {
constexpr std::uint32_t kLeaseMs = 15000;
enum class Mode : std::uint8_t { Codex, Super };
enum class Command : std::uint8_t { Invalid, Codex, Super };
Command parse(JsonObjectConst params);
class Lease {
 public:
  bool apply(Command command, std::uint16_t connectionId,
             std::uint32_t nowMs);
  bool disconnect(std::uint16_t connectionId);
  bool expire(std::uint32_t nowMs);
  Mode mode() const;
};
}
```

- [ ] Write failing native tests for strict parsing, ownership, refresh, disconnect, expiry, and rollover.
- [ ] Verify RED because the new header, method, and enum do not exist.
- [ ] Implement strict parameters and the connection-bound lease.
- [ ] Split RPC handling into `Unsupported`, `ControlOnly`, and `HostActivity`; workspace messages must never promote Codex liveness.
- [ ] Return `-32602 Invalid params` for malformed workspace parameters.
- [ ] Add fixed diagnostic probe modes for SUPER and Codex.
- [ ] Run native tests, warning checks, and the USB-microphone build.
- [ ] Review and commit as `feat: add stopwatch workspace mode lease`.

### Task 3: Add the dedicated SUPER renderer

**Files:**
- Create: `include/SuperWorkspaceUi.h`
- Create: `simulator/super_workspace_ui_test.cpp`
- Modify: `simulator/preview_main.cpp`

- [ ] Write failing tests for the four action labels, distinct visual state, battery/connection inputs, and lack of project/session/quota data.
- [ ] Verify RED because the renderer does not exist.
- [ ] Implement the dedicated `SUPER` renderer with `LEFT BACK`, `UP PREV PROJECT`, `DOWN NEXT PROJECT`, and `RIGHT NEXT TAB`.
- [ ] Preserve minimal battery, charging, connection, swipe feedback, and power-overlay rendering.
- [ ] Add a native `super` preview written only to `/private/tmp`.
- [ ] Verify native tests and preview layout, then review and commit as `feat: render super engineering workspace screen`.

### Task 4: Integrate firmware mode selection and input isolation

**Files:**
- Create: `include/WorkspaceInputPolicy.h`
- Create: `simulator/workspace_input_policy_test.cpp`
- Modify: `src/main.cpp`

- [ ] Write failing policy tests proving SUPER allows four swipes and power behavior but blocks Agent, Send, and both ChatGPT physical buttons.
- [ ] Verify RED because the policy does not exist.
- [ ] Refresh workspace state immediately after `codex.poll()` and before input handling.
- [ ] Select the SUPER or Codex renderer without waking a sleeping display.
- [ ] Release active non-SUPER HID states and clear transient UI when entering SUPER.
- [ ] Preserve swipe haptics, the red power key, and center long-hold travel power-off; center short release must not send.
- [ ] Silently track Agent state while SUPER is active so old completions do not fire on return.
- [ ] Run native tests, preview, and a warning-free USB-microphone build.
- [ ] Review and commit as `feat: isolate controls in stopwatch super mode`.

### Task 5: Add the companion HID Output writer

**Files:**
- Create: `companion/Sources/CodexWatchCompanion/WorkspaceModeHIDWriter.swift`
- Create: `companion/Tests/CodexWatchCompanionTests/WorkspaceModeHIDWriterTests.swift`
- Modify: `companion/Sources/CodexWatchCompanion/HIDShortcutListener.swift`
- Modify: `companion/Tests/CodexWatchCompanionTests/HIDShortcutDecoderTests.swift`

**Interfaces:**

```swift
enum StopwatchWorkspaceMode: Equatable { case codex, super }

@MainActor
protocol StopwatchHIDOutputDevice: AnyObject {
    var deviceKey: UInt { get }
    func setOutputReport(reportID: Int, bytes: [UInt8]) -> IOReturn
}

@MainActor
protocol WorkspaceModeSending: AnyObject {
    var deviceKey: UInt { get }
    func send(_ mode: StopwatchWorkspaceMode) -> Bool
}
```

- [ ] Write failing XCTest source and a supplemental harness for exact framing, fragmentation, request IDs, failures, and device lifetime.
- [ ] Verify RED before implementing production types.
- [ ] Implement fixed RPC serialization and 64-byte report output to the exact matched IOHIDDevice.
- [ ] Maintain per-device decoder and writer state; stop late callbacks and stale writes safely.
- [ ] Run focused tests/harnesses and a warning-free release compile.
- [ ] Review and commit as `feat: send stopwatch workspace mode over HID`.

### Task 6: Follow foreground super.engineering in the real watch lifecycle

**Files:**
- Create: `companion/Sources/CodexWatchCompanion/WorkspaceModeCoordinator.swift`
- Create: `companion/Tests/CodexWatchCompanionTests/WorkspaceModeCoordinatorTests.swift`
- Modify: `companion/Sources/CodexWatchCompanion/main.swift`
- Modify: `companion/Tests/CodexWatchCompanionTests/CompanionRuntimeTests.swift`

- [ ] Write failing tests with injectable foreground observation, scheduling, uptime, and senders.
- [ ] Verify RED before implementing the coordinator.
- [ ] Send the current mode on start and device attach; heartbeat SUPER every five seconds and send Codex once on exit.
- [ ] Keep per-device senders, reconnect synchronization, MainActor serialization, and a 60-second failure-warning limit.
- [ ] On stop, best-effort Codex before cancelling observation and HID lifecycle.
- [ ] Start the feature only in real `--watch` mode; preserve quota retry and existing shortcut behavior.
- [ ] Run runtime tests/harnesses, release build, and mode smoke tests.
- [ ] Review and commit as `feat: follow super engineering on stopwatch display`.

### Task 7: Document and verify the complete branch

**Files:**
- Modify: `companion/README.md`
- Modify: `docs/COMPANION_PROTOCOL.md`

- [ ] Document the SUPER screen, 5/15-second lease, permissions, sleep behavior, isolation, diagnostics, privacy, and rollback.
- [ ] Run every native test, native preview, warning-free USB-microphone build, pinned-SDK companion release build, available XCTest, and supplemental harnesses.
- [ ] Run `--json-only`, watch-mode gating, RunLoop, callback-lifetime, warning-limit, and quota-retry smoke checks.
- [ ] Review `6dcb13b..HEAD` for HID lifetime, MainActor, strict parsing, rollover, ownership, input release, USB audio, privacy, and logs.
- [ ] Fix each finding with a reproducing test and focused commit, then repeat affected verification.
- [ ] Commit documentation as `docs: explain stopwatch super workspace screen`.

### Task 8: Install, flash, and physically accept

- [ ] Build and hash the final USB-microphone firmware; do not modify or flash the default image.
- [ ] Enter download mode, resolve the newly enumerated exact `/dev/cu.*` port, report it, and obtain explicit confirmation before upload.
- [ ] Flash only the confirmed port and verify USB audio, short capture, BLE, HID/RPC, and the screen as separate layers.
- [ ] Back up the signed local companion, replace only its executable, re-sign, and restart the existing LaunchAgent without rewriting local configuration.
- [ ] Physically verify foreground following, every exit route, sleeping-display behavior, four gestures, input isolation/restoration, cooldown, lease timeout, reconnect, microphone, quota, ChatGPT compatibility, and automatic startup.
- [ ] Mark every unobserved physical result unverified.
- [ ] Restore the saved companion and baseline USB-microphone firmware if a critical regression appears.
