# super.engineering Dedicated Workspace Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the physically validated C152 left-swipe toggle so up/down navigate super.engineering projects and right advances session tabs, while preserving ChatGPT's existing up/down/right mappings outside foreground super.engineering.

**Architecture:** Expand the pure HID decoder to typed radial events, route them on the MainActor, and deliver only three fixed Control-Option-arrow sequences to the exact foreground `com.zarifpour.superconductor` PID. The existing AppKit toggler remains responsible for left-swipe entry/return and macOS follows the application's user-assigned Space; HID, quota, microphone, and LaunchAgent lifecycles remain independent.

**Tech Stack:** Swift 5.10, Swift Package Manager, XCTest source, AppKit/NSWorkspace, ApplicationServices/CoreGraphics, Carbon virtual key codes, IOKit.hid, macOS 14+

**Implementation baseline:** Branch `feature/super-engineering-shortcut`, commit `ba11fd4`.

## Global Constraints

- Target only the M5Stack StopWatch Dev Kit C152 with the already installed USB microphone firmware. Do not modify, build, upload, or reflash firmware.
- Keep the existing exact HID match: VID `0x303A`, PID `0x8360`, usage page `0xFF00`, usage `1`, report ID `6`, including the validated 64-byte macOS callback normalization.
- Decode only finite `v.oai.rad` values near angles `0.00`, `0.25`, `0.50`, and `0.75`; preserve the existing distance tolerances, press/release gate, per-device decoder, reset behavior, and 800-millisecond accepted-event cooldown.
- Identify super.engineering only by bundle identifier `com.zarifpour.superconductor`. Revalidate the exact PID/bundle pair before every navigation delivery.
- Emit only `Control-Option-Up`, `Control-Option-Down`, and `Control-Option-Right`; do not expose an arbitrary macro or caller-supplied key API.
- Never invoke `sc`, a shell, AppleScript, private Space APIs, menu scraping, screen coordinates, or Accessibility UI inspection.
- Never read project names, session titles, prompts, conversation content, files, workspaces, credentials, clipboard data, or super.engineering/ChatGPT preferences.
- Require Accessibility only for up/down/right delivery. Missing permission warns once per companion process and must not disable left toggle, HID reconnection, quota sync, or microphone input.
- Companion navigation is a no-op unless the exact foreground app is super.engineering. ChatGPT retains its own up/down/right handling; only Analog stick left remains unbound there.
- Preserve the existing LaunchAgent, device UUID, Codex executable path, log paths, and signed-app identity. Keep all machine-specific values, app backups, harnesses, logs, and microphone captures outside Git.
- Treat XCTest source as authoritative, but do not claim XCTest execution succeeded on this host while its Command Line Tools SDK lacks the XCTest module. Use compile-failing/compile-passing temporary Swift harnesses as supplemental RED/GREEN evidence.
- Report source tests, release build, local installation, permissions, Space setup, shortcut configuration, C152 behavior, ChatGPT compatibility, quota sync, USB microphone, and automatic startup as separate validation layers. Unobserved physical behavior remains unverified.

## File Structure and Interfaces

- Modify `companion/Sources/CodexWatchCompanion/HIDShortcutDecoder.swift`: add `SuperEngineeringNavigationCommand`, typed navigation events, and four-angle recognition without app knowledge.
- Modify `companion/Tests/CodexWatchCompanionTests/HIDShortcutDecoderTests.swift`: cover every direction, tolerance rejection, raw 64-byte reports, global cooldown, release, malformed data, and recovery.
- Create `companion/Sources/CodexWatchCompanion/SuperEngineeringKeyEmitter.swift`: map the closed navigation enum to immutable CoreGraphics key stroke pairs and post them only to a revalidated process identity.
- Create `companion/Tests/CodexWatchCompanionTests/SuperEngineeringKeyEmitterTests.swift`: verify exact key codes, modifier flags, event order, PID targeting, and stale/PID-reuse rejection.
- Modify `companion/Sources/CodexWatchCompanion/SuperEngineeringToggler.swift`: expose the narrow `SuperEngineeringToggling` protocol while retaining current policy and behavior.
- Create `companion/Sources/CodexWatchCompanion/SuperEngineeringCommandRouter.swift`: send left to the toggler, gate navigation by foreground identity and Accessibility, and bound warning behavior.
- Create `companion/Tests/CodexWatchCompanionTests/SuperEngineeringCommandRouterTests.swift`: verify context gating, permission degradation, fixed routing, generic logging, and left independence.
- Modify `companion/Sources/CodexWatchCompanion/main.swift`: retain one router for the real `--watch` listener lifecycle and forward typed events on MainActor.
- Modify `companion/README.md`: document Space assignment, official super.engineering shortcuts, Accessibility, ChatGPT compatibility, diagnostics, acceptance, and rollback.

---

### Task 1: Expand the pure HID decoder to four typed radial events

**Files:**
- Modify: `companion/Sources/CodexWatchCompanion/HIDShortcutDecoder.swift`
- Modify: `companion/Tests/CodexWatchCompanionTests/HIDShortcutDecoderTests.swift`

**Interfaces:**

```swift
enum SuperEngineeringNavigationCommand: Equatable {
    case previousProject
    case nextProject
    case nextTab
}

enum CompanionShortcutEvent: Equatable {
    case toggleSuperEngineering
    case navigateSuperEngineering(SuperEngineeringNavigationCommand)
}
```

- [ ] **Step 1: Write the four-direction XCTest cases before implementation**

Add a message helper and table-driven assertions to `HIDShortcutDecoderTests.swift`:

```swift
private func radial(angle: Double, distance: Double) -> [UInt8] {
    report(#"{"method":"v.oai.rad","params":{"a":\#(angle),"d":\#(distance)}}"# + "\n")
}

func testFourPhysicalAnglesProduceTypedEvents() {
    let cases: [(Double, CompanionShortcutEvent)] = [
        (0.00, .navigateSuperEngineering(.nextTab)),
        (0.25, .navigateSuperEngineering(.nextProject)),
        (0.50, .toggleSuperEngineering),
        (0.75, .navigateSuperEngineering(.previousProject)),
    ]

    for (angle, expected) in cases {
        var decoder = HIDShortcutDecoder()
        XCTAssertEqual(
            decoder.consume(reportID: 6, bytes: radial(angle: angle, distance: 1), now: 10),
            [expected]
        )
    }
}

func testUnknownAngleOutsideToleranceIsIgnored() {
    var decoder = HIDShortcutDecoder()
    XCTAssertEqual(
        decoder.consume(reportID: 6, bytes: radial(angle: 0.12, distance: 1), now: 10),
        []
    )
}

func testCooldownIsSharedAcrossDirectionsAfterRelease() {
    var decoder = HIDShortcutDecoder()
    XCTAssertEqual(decoder.consume(reportID: 6, bytes: radial(angle: 0, distance: 1), now: 1), [.navigateSuperEngineering(.nextTab)])
    XCTAssertEqual(decoder.consume(reportID: 6, bytes: radial(angle: 0, distance: 0), now: 1.1), [])
    XCTAssertEqual(decoder.consume(reportID: 6, bytes: radial(angle: 0.75, distance: 1), now: 1.2), [])
    XCTAssertEqual(decoder.consume(reportID: 6, bytes: radial(angle: 0.75, distance: 0), now: 1.3), [])
    XCTAssertEqual(decoder.consume(reportID: 6, bytes: radial(angle: 0.25, distance: 1), now: 1.81), [.navigateSuperEngineering(.nextProject)])
}
```

Retain the existing fragmentation, raw-report-ID normalization, wrong report ID, malformed frame, overflow, non-finite input, multiple-newline, and recovery tests. Change the old “other direction” rejection assertion to a genuinely unknown angle such as `0.12`.

- [ ] **Step 2: Capture RED evidence without misrepresenting XCTest**

Run the focused command from `companion`:

```bash
swift test --filter HIDShortcutDecoderTests
```

Expected on the current host: the installed SDK stops at `no such module 'XCTest'`. Record this as an environment limitation, not a product failure or a passing test.

Create an untracked `/private/tmp` Swift harness with `apply_patch`. Compile it together with the production decoder. The harness must reference `.navigateSuperEngineering(.nextTab)`, `.nextProject`, and `.previousProject` and assert the table above.

Expected RED: compilation fails because the new enum cases and command type do not exist yet.

- [ ] **Step 3: Implement the closed angle-to-event mapping**

Replace the one-case event enum with the interfaces above and add a pure mapper:

```swift
private func event(for angle: Double) -> CompanionShortcutEvent? {
    let candidates: [(Double, CompanionShortcutEvent)] = [
        (0.00, .navigateSuperEngineering(.nextTab)),
        (0.25, .navigateSuperEngineering(.nextProject)),
        (0.50, .toggleSuperEngineering),
        (0.75, .navigateSuperEngineering(.previousProject)),
    ]
    return candidates.first { abs(angle - $0.0) <= Self.directionTolerance }?.1
}
```

Update `recognize` so it validates method and finite numbers, resolves one known direction, rearms on that direction's release, applies the existing global cooldown to accepted presses, and returns the resolved event:

```swift
guard message.method == "v.oai.rad",
      message.params.a.isFinite,
      message.params.d.isFinite,
      let event = event(for: message.params.a) else { return nil }
if abs(message.params.d) <= Self.distanceTolerance {
    armed = true
    return nil
}
guard abs(message.params.d - 1.0) <= Self.distanceTolerance, armed else { return nil }
armed = false
guard lastAcceptedAt.map({ now - $0 >= Self.cooldown }) ?? true else { return nil }
lastAcceptedAt = now
return event
```

Setting `armed = false` before the cooldown check is intentional: a press that
arrives during cooldown is still one physical hold and must require a release
before it can ever become eligible. This prevents repeated held reports from
turning into a delayed second event after 800 milliseconds.

Do not move application checks, Accessibility, or key mapping into the decoder.

- [ ] **Step 4: Prove GREEN with the temporary harness and warning-free compilation**

Compile and run the decoder harness against the production source with the pinned macOS SDK and isolated module cache. Expected: all assertions pass and the compiler emits no warnings.

Attempt the focused XCTest command again and preserve its XCTest-unavailable result accurately.

- [ ] **Step 5: Review and commit Task 1**

Review the diff for exact physical angles, finite checks, one event per press, shared cooldown, raw 64-byte normalization, and unchanged per-device reset behavior.

```bash
git add companion/Sources/CodexWatchCompanion/HIDShortcutDecoder.swift companion/Tests/CodexWatchCompanionTests/HIDShortcutDecoderTests.swift
git commit -m "feat: decode stopwatch workspace gestures"
```

---

### Task 2: Add the exact-PID fixed key emitter

**Files:**
- Create: `companion/Sources/CodexWatchCompanion/SuperEngineeringKeyEmitter.swift`
- Create: `companion/Tests/CodexWatchCompanionTests/SuperEngineeringKeyEmitterTests.swift`

**Interfaces:**

```swift
struct ProcessKeyStroke: Equatable {
    let keyCode: CGKeyCode
    let keyDown: Bool
    let flags: CGEventFlags
}

@MainActor
protocol ProcessTargetedKeyEmitting: AnyObject {
    func emit(
        _ command: SuperEngineeringNavigationCommand,
        to identity: ApplicationIdentity
    ) -> Bool
}
```

The production implementation accepts narrow foreground lookup, process lookup,
and sequence-poster adapters for tests. Callers can pass only the closed
navigation enum, never a raw key code, modifier set, string, shell command, or
target bundle.

- [ ] **Step 1: Write exact mapping and identity-revalidation tests**

Create a recording sequence poster and tests that assert:

```swift
private let modifiers: CGEventFlags = [.maskControl, .maskAlternate]

func testPreviousProjectEmitsControlOptionUpDownThenUpToExactPID() {
    let target = ApplicationIdentity(processIdentifier: 202, bundleIdentifier: "com.zarifpour.superconductor")
    let poster = SequencePosterStub()
    let emitter = SystemProcessTargetedKeyEmitter(
        frontmostIdentity: { target },
        identityForProcess: { _ in target },
        poster: poster
    )

    XCTAssertTrue(emitter.emit(.previousProject, to: target))
    XCTAssertEqual(poster.processIdentifiers, [202])
    XCTAssertEqual(poster.sequences, [[
        ProcessKeyStroke(keyCode: CGKeyCode(kVK_UpArrow), keyDown: true, flags: modifiers),
        ProcessKeyStroke(keyCode: CGKeyCode(kVK_UpArrow), keyDown: false, flags: modifiers),
    ]])
}
```

Add equivalent assertions for `.nextProject` → `kVK_DownArrow` and `.nextTab` → `kVK_RightArrow`. Add three rejection tests:

- target PID no longer exists;
- target PID now resolves to a different bundle identifier.
- the exact target identity is no longer foreground immediately before posting.

All three must return `false` and post no sequence.

- [ ] **Step 2: Capture RED with XCTest source and a temporary production-source harness**

Run the focused XCTest command and record the current XCTest module limitation. Create an untracked harness that supplies a fake identity lookup and sequence poster, then compile it with the current production sources.

Expected RED: `ProcessKeyStroke`, `ProcessTargetedKeyEmitting`, and `SystemProcessTargetedKeyEmitter` are unresolved.

- [ ] **Step 3: Implement fixed sequence construction and CoreGraphics posting**

Create `SuperEngineeringKeyEmitter.swift` with imports limited to the required public frameworks:

```swift
import AppKit
import ApplicationServices
import Carbon
import CoreGraphics
import Foundation
```

Define a small internal poster interface:

```swift
@MainActor
protocol ProcessKeySequencePosting: AnyObject {
    func post(_ strokes: [ProcessKeyStroke], to processIdentifier: pid_t) -> Bool
}
```

The emitter must:

1. resolve `NSWorkspace.shared.frontmostApplication` through an injectable foreground-identity lookup immediately before posting;
2. resolve `NSRunningApplication(processIdentifier:)` through an injectable process-identity lookup;
3. require both results to equal the supplied `ApplicationIdentity` and require its bundle identifier to equal the fixed target bundle identifier;
4. map the command with an exhaustive switch to only Up, Down, or Right;
5. construct exactly two strokes in key-down/key-up order with `.maskControl` and `.maskAlternate` on both;
6. ask the poster to deliver the immutable sequence only to the validated PID.

The CoreGraphics poster must create one `.hidSystemState` source, create every `CGEvent`, set the supplied fixed flags, and call `event.postToPid(processIdentifier)` in sequence order. If event construction fails, return `false` without posting a partial sequence. Do not call global `post(tap:)`.

- [ ] **Step 4: Prove mapping, ordering, flags, and PID isolation**

Compile and run the temporary emitter harness. Expected: all three command mappings pass; the recorder sees one exact PID, key-down then key-up, and both modifier flags; stale, reused-PID, and no-longer-foreground cases post nothing.

Run a warning-free release compilation after the focused harness. Do not attempt a real key injection in this task.

- [ ] **Step 5: Review and commit Task 2**

Review specifically for a closed command surface, exact bundle/PID validation, no global events, no text capture, no UI inspection, and no partial key-down delivery.

```bash
git add companion/Sources/CodexWatchCompanion/SuperEngineeringKeyEmitter.swift companion/Tests/CodexWatchCompanionTests/SuperEngineeringKeyEmitterTests.swift
git commit -m "feat: emit targeted super engineering commands"
```

---

### Task 3: Context-gate navigation and wire it into the watch lifecycle

**Files:**
- Modify: `companion/Sources/CodexWatchCompanion/SuperEngineeringToggler.swift`
- Create: `companion/Sources/CodexWatchCompanion/SuperEngineeringCommandRouter.swift`
- Create: `companion/Tests/CodexWatchCompanionTests/SuperEngineeringCommandRouterTests.swift`
- Modify: `companion/Sources/CodexWatchCompanion/main.swift`
- Verify unchanged behavior in: `companion/Sources/CodexWatchCompanion/CompanionRuntime.swift`

**Interfaces:**

```swift
@MainActor
protocol SuperEngineeringToggling: AnyObject {
    func toggle()
}

protocol AccessibilityTrustChecking {
    var isTrusted: Bool { get }
}
```

- [ ] **Step 1: Add router tests before production routing**

Use `WorkspaceStub`, a toggler spy, an emitter spy, a mutable trust stub, and a log recorder. Cover these cases:

```swift
func testLeftAlwaysReachesTogglerWithoutAccessibility() {
    let fixture = makeFixture(frontmost: chatGPT, trusted: false)
    fixture.router.handle(.toggleSuperEngineering)
    XCTAssertEqual(fixture.toggler.toggleCount, 1)
    XCTAssertTrue(fixture.emitter.calls.isEmpty)
}

func testNavigationIsIgnoredOutsideForegroundSuperEngineering() {
    let fixture = makeFixture(frontmost: chatGPT, trusted: true)
    fixture.router.handle(.navigateSuperEngineering(.nextProject))
    XCTAssertTrue(fixture.emitter.calls.isEmpty)
    XCTAssertTrue(fixture.logs.isEmpty)
}

func testNavigationUsesExactForegroundIdentity() {
    let fixture = makeFixture(frontmost: superApp, trusted: true)
    fixture.router.handle(.navigateSuperEngineering(.previousProject))
    fixture.router.handle(.navigateSuperEngineering(.nextProject))
    fixture.router.handle(.navigateSuperEngineering(.nextTab))
    XCTAssertEqual(fixture.emitter.calls.map(\.command), [.previousProject, .nextProject, .nextTab])
    XCTAssertEqual(fixture.emitter.calls.map(\.identity), [superApp, superApp, superApp])
}

func testAccessibilityWarningIsLoggedOnlyOnceAndLeftStillWorks() {
    let fixture = makeFixture(frontmost: superApp, trusted: false)
    fixture.router.handle(.navigateSuperEngineering(.previousProject))
    fixture.router.handle(.navigateSuperEngineering(.nextProject))
    fixture.router.handle(.toggleSuperEngineering)
    XCTAssertEqual(fixture.logs.filter { $0.contains("辅助功能") }.count, 1)
    XCTAssertEqual(fixture.toggler.toggleCount, 1)
}
```

Add an emitter-failure test that logs only a generic delivery failure and does not mutate the toggler. Assert that ignored non-target navigation produces no routine logs.

- [ ] **Step 2: Capture RED in the temporary router harness**

Retain the XCTest source and its environment result. Compile an untracked harness against production sources with router spies.

Expected RED: the router, trust checker, and toggler protocol do not exist.

- [ ] **Step 3: Implement the MainActor router and bounded permission warning**

Make `SuperEngineeringToggler` conform to `SuperEngineeringToggling` without changing its current activation, launch, return, or MainActor behavior.

Create `SuperEngineeringCommandRouter.swift`:

```swift
import ApplicationServices
import Foundation

struct SystemAccessibilityTrustChecker: AccessibilityTrustChecking {
    var isTrusted: Bool { AXIsProcessTrusted() }
}

@MainActor
final class SuperEngineeringCommandRouter {
    private let workspace: WorkspaceApplications
    private let toggler: SuperEngineeringToggling
    private let emitter: ProcessTargetedKeyEmitting
    private let accessibility: AccessibilityTrustChecking
    private let log: (String) -> Void
    private var didWarnAboutAccessibility = false

    func handle(_ event: CompanionShortcutEvent) {
        switch event {
        case .toggleSuperEngineering:
            toggler.toggle()
        case let .navigateSuperEngineering(command):
            guard let target = workspace.frontmost,
                  target.bundleIdentifier == SuperEngineeringToggler.targetBundleIdentifier else { return }
            guard accessibility.isTrusted else {
                if !didWarnAboutAccessibility {
                    didWarnAboutAccessibility = true
                    log("辅助功能权限未开启；super.engineering 项目和会话导航不可用")
                }
                return
            }
            guard emitter.emit(command, to: target) else {
                log("super.engineering 导航按键发送失败")
                return
            }
        }
    }
}
```

Provide an initializer taking all four adapters and the logger. Do not prompt for Accessibility or open System Settings automatically.

- [ ] **Step 4: Replace the one-case listener closure with a retained router**

In `main.swift`, retain a router for the same lifetime as `HIDShortcutListener`:

```swift
var shortcutRouter: SuperEngineeringCommandRouter?
var shortcutListener: HIDShortcutListener?
if options.startsHIDShortcutListener {
    let workspace = NSWorkspaceApplications()
    let toggler = SuperEngineeringToggler(
        workspace: workspace,
        log: { fputs("快捷键：\($0)\n", stderr) }
    )
    let router = SuperEngineeringCommandRouter(
        workspace: workspace,
        toggler: toggler,
        emitter: SystemProcessTargetedKeyEmitter(),
        accessibility: SystemAccessibilityTrustChecker(),
        log: { fputs("快捷键：\($0)\n", stderr) }
    )
    let listener = HIDShortcutListener(
        eventHandler: { [weak router] event in router?.handle(event) },
        log: { fputs("快捷键：\($0)\n", stderr) }
    )
    do {
        try listener.start()
        shortcutRouter = router
        shortcutListener = listener
    } catch {
        fputs("快捷键不可用：\(error.localizedDescription)\n", stderr)
    }
}
defer {
    withExtendedLifetime(shortcutRouter) { shortcutListener?.stop() }
    shortcutListener = nil
    shortcutRouter = nil
}
```

Keep `options.startsHIDShortcutListener` unchanged so only real `--watch` starts HID. Do not change quota retry behavior, RunLoop pumping, BLE UUID handling, or listener device-state ownership.

- [ ] **Step 5: Prove router and lifecycle behavior**

Run the temporary router harness. Then run the existing runtime/RunLoop harness and mode smoke checks:

- real `--watch` eligibility starts the listener;
- `--json-only`, demo, one-shot, and bootloader paths do not;
- a quota-cycle failure is logged and retried while the RunLoop remains responsive;
- ignored non-target navigation produces no logs;
- missing Accessibility warns once and left still calls the toggler.

Build release with warnings treated as review failures. Attempt focused XCTest and report the SDK limitation separately.

- [ ] **Step 6: Review and commit Task 3**

Review MainActor serialization, strong lifetimes, foreground gating before trust checks, exact identity passed to the emitter, one-time warning state, quota isolation, and watch-only listener gating.

```bash
git add companion/Sources/CodexWatchCompanion/SuperEngineeringToggler.swift companion/Sources/CodexWatchCompanion/SuperEngineeringCommandRouter.swift companion/Sources/CodexWatchCompanion/main.swift companion/Tests/CodexWatchCompanionTests/SuperEngineeringCommandRouterTests.swift
git commit -m "feat: route stopwatch workspace controls"
```

---

### Task 4: Document setup, run full verification, and review the branch

**Files:**
- Modify: `companion/README.md`
- Verify: all changed production and test files since `ba11fd4`

- [ ] **Step 1: Update the Companion setup and privacy documentation**

Document these exact user-visible steps:

1. Create a normal macOS Space, move super.engineering there, and choose Dock **Options → Assign To → This Desktop**.
2. In super.engineering **Keyboard Shortcuts**, configure Previous Project = `Control-Option-Up`, Next Project = `Control-Option-Down`, and Next Tab = `Control-Option-Right`.
3. Enable both Input Monitoring and Accessibility for the installed signed Companion identity.
4. In ChatGPT, leave only Analog stick left unbound; retain existing up/down/right mappings.
5. Explain that left works without Accessibility, while project/tab navigation does not.
6. Explain no-op behavior outside foreground super.engineering and the one-time permission warning.
7. State that the companion does not inspect projects, sessions, UI, preferences, or content and does not create Spaces.
8. Add rollback: restore the preserved companion app, restart the same LaunchAgent, optionally set Dock assignment to None, and reset the three super.engineering shortcuts. No firmware rollback is needed.

- [ ] **Step 2: Run all available automated verification**

Use isolated caches under `/private/tmp` and the pinned macOS 15.4 SDK to run:

- decoder harness;
- key-emitter harness;
- command-router harness;
- existing callback/session and RunLoop responsiveness harnesses;
- warning-free `swift build -c release`;
- `--json-only` smoke test;
- mode eligibility smoke tests.

Use this release-build shape from the `companion` directory so no generated
artifacts enter the repository:

```bash
env SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  CLANG_MODULE_CACHE_PATH=/private/tmp/codex-watch-workspace-controls-clang-cache \
  SWIFT_MODULE_CACHE_PATH=/private/tmp/codex-watch-workspace-controls-swift-cache \
  swift build --disable-sandbox --disable-dependency-cache \
  --manifest-cache local \
  --cache-path /private/tmp/codex-watch-workspace-controls-package-cache \
  --config-path /private/tmp/codex-watch-workspace-controls-package-config \
  --security-path /private/tmp/codex-watch-workspace-controls-package-security \
  --scratch-path /private/tmp/codex-watch-workspace-controls-build \
  --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk \
  -c release
```

Resolve the product path with the same cache and scratch options, then run the
resulting `codex-watch-companion --json-only` one-shot smoke test. Do not start a
second real `--watch` process alongside the installed LaunchAgent.

Attempt `swift test` once. If the host still reports `no such module 'XCTest'`, preserve the test source and report XCTest as unavailable. Do not relabel harnesses as the complete XCTest suite.

- [ ] **Step 3: Perform a complete branch review**

Review `ba11fd4..HEAD` and the working tree for:

- exact four-angle mapping and physical 64-byte framing;
- one accepted event per release/cooldown cycle;
- per-device decoder cleanup and reconnect behavior;
- exact foreground and exact PID/bundle revalidation;
- process-targeted rather than global key events;
- fixed command surface and modifiers on key-down and key-up;
- MainActor callback serialization and object lifetimes;
- one-time Accessibility warning and failure isolation;
- watch-only listener and quota retry behavior;
- no private Space APIs, shell, AppleScript, UI scraping, user content, secrets, device identifiers, local paths, captures, or generated app bundles in Git.

Fix any finding with a focused test/harness reproduction and a separate fix commit, then repeat affected verification.

- [ ] **Step 4: Commit documentation**

```bash
git add companion/README.md
git commit -m "docs: explain super engineering workspace controls"
```

Confirm the tracked tree is clean and all commits are limited to the intended source, tests, and documentation.

---

### Task 5: Install safely and perform layered physical acceptance

**Files and machine state:**
- Read only: existing signed Companion app, code signature, LaunchAgent, permissions, and process state
- Write only after validation: a new backup under `/private/tmp` and the existing Companion executable/signature
- Do not modify: firmware, LaunchAgent configuration, device UUID, Codex path, log paths, ChatGPT up/down/right mappings, or captured user content

- [ ] **Step 1: Resolve and validate the exact installation target before mutation**

Read the current LaunchAgent process and executable path without printing its UUID, private paths, arguments, or logs into tracked files. Verify:

- the resolved app is the currently running Companion;
- its bundle identifier is `io.github.codex-micro-stopwatch.companion`;
- its existing signature verifies;
- the release binary architecture matches the installed executable;
- the original backup remains present and untouched.

Create a second timestamped backup outside the repository. Before replacing anything, report the exact target and backup location to the user and obtain action-time approval if the resolved target differs from the already validated installed app. Never use a recursive broad target, glob, or unresolved variable for replacement.

- [ ] **Step 2: Replace only the executable, sign, verify, and restart the existing service**

Copy the verified release executable over the exact resolved bundle executable, sign the same local app identity, and verify the signature before restarting the existing LaunchAgent. Do not recreate or rewrite the plist.

After restart, verify separately:

- the expected Companion PID is running;
- the listener sees the C152 after disconnect/reconnect;
- one real quota cycle succeeds or a retry remains alive;
- no crash or repeated permission warning appears.

If signing, launch, or health verification fails, stop and restore the new backup before further testing.

- [ ] **Step 3: Complete user-visible Space, shortcut, and permission setup**

With action-time user confirmation for System Settings changes:

- assign super.engineering to its dedicated Space through the Dock;
- configure the three official super.engineering shortcuts exactly as documented;
- verify those three combinations work from the physical keyboard first;
- confirm Input Monitoring and Accessibility are enabled for the installed signed Companion identity;
- confirm ChatGPT Analog stick left is unbound and up/down/right remain bound.

Do not automate private settings or silently edit application preference files.

- [ ] **Step 4: Run physical C152 acceptance in order**

Record each item as pass, fail, or unverified:

1. From ChatGPT, left enters super.engineering and macOS follows it to the assigned Space.
2. Left returns to the exact previous ChatGPT window and Space.
3. From another ordinary app, left enters and returns to that exact app.
4. With super.engineering foreground, up selects Previous Project, down selects Next Project, and right selects Next Tab.
5. Right advances repeatedly and exhibits super.engineering's native wraparound.
6. Rapid duplicate reports do not double-advance.
7. With super.engineering foreground, ChatGPT performs no visible background up/down/right action.
8. After returning to ChatGPT, its existing up/down/right mappings still work.
9. Outside foreground super.engineering, companion up/down/right handling is a silent no-op.
10. Disconnect and reconnect C152; all four controls recover without restarting Companion.
11. Other physical buttons and directions not owned by this feature remain unchanged.

- [ ] **Step 5: Run regression acceptance and preserve rollback readiness**

Verify independently:

- USB microphone still enumerates as input only;
- a short temporary recording succeeds and is deleted;
- quota updates reach the device;
- the LaunchAgent remains loaded with its original configuration;
- automatic startup survives a controlled Companion restart;
- no firmware change or flash occurred.

Keep both backups until the user accepts the feature. If any critical regression appears, restore the newest known-good Companion app and restart the same LaunchAgent. Report restored behavior and leave the Space/shortcut settings for the user to reset manually if desired.

---

## Completion Gate

The feature is complete only when:

- Tasks 1–4 are independently committed and their available verification is green;
- the complete branch review has no unresolved correctness, privacy, lifecycle, or compatibility finding;
- installation and signing are verified on the local Mac;
- the user has observed and accepted entry/return, project navigation, session-tab navigation, and ChatGPT compatibility on the physical C152;
- USB microphone, quota sync, reconnect, other controls, and automatic startup have separate passing evidence;
- every unobserved layer is explicitly marked unverified rather than inferred.
