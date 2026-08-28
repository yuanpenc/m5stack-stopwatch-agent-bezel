# super.engineering StopWatch Shortcut Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make one left swipe on the physical C152 toggle between super.engineering and the previously foreground macOS application without changing StopWatch firmware.

**Architecture:** Add a pure vendor-HID decoder, a narrowly matched IOKit listener, and an AppKit application toggler to the existing Swift companion. Start the listener only in real `--watch` mode and keep quota-cycle errors isolated so the main RunLoop continues serving HID callbacks.

**Tech Stack:** Swift 5.10, Swift Package Manager, XCTest, AppKit/NSWorkspace, IOKit.hid/IOHIDManager, macOS 14+

## Global Constraints

- Target hardware is M5Stack StopWatch Dev Kit C152 with the already installed optional USB microphone firmware.
- Do not modify, build, upload, or reflash firmware for this feature.
- Match vendor ID `0x303A`, product ID `0x8360`, usage page `0xFF00`, usage `1`, and input report ID `6` exactly.
- Recognize only `v.oai.rad` with finite `a` near `0.5`, press `d` near `1.0`, release `d` near `0.0`, and an 800-millisecond cooldown.
- Locate super.engineering only by bundle identifier `com.zarifpour.superconductor`.
- Do not invoke `sc`, AppleScript, a shell, user-configurable commands, or read super.engineering sessions, workspaces, credentials, or configuration.
- Do not capture keyboard text, clipboard data, prompts, workspace content, account data, or credentials.
- Enable HID listening only for real continuous `--watch` operation, not one-shot, `--demo`, `--json-only`, or bootloader modes.
- Keep generated app bundles, LaunchAgent values, CoreBluetooth UUIDs, usernames, home-directory paths, logs, and microphone recordings out of Git.
- Keep existing quota synchronization and HID shortcut lifecycles isolated; a per-cycle quota failure in watch mode must not terminate HID listening.
- Require macOS 14 or newer and Swift 5.10 or newer.
- Unassign ChatGPT's Analog stick left mapping before physical acceptance; keep up, right, and down unchanged.
- Report build/tests, local installation, Input Monitoring, HID recognition, app switching, USB microphone, other controls, quota sync, and automatic startup as separate validation layers.
- Do not claim the shortcut is validated until it is observed on physical C152 hardware.

## File Structure

- Create `companion/Sources/CodexWatchCompanion/HIDShortcutDecoder.swift`: pure report framing, JSON recognition, release gating, and cooldown state.
- Create `companion/Sources/CodexWatchCompanion/HIDShortcutListener.swift`: exact IOHIDManager matching and lifecycle; forwards only logical toggle events.
- Create `companion/Sources/CodexWatchCompanion/SuperEngineeringToggler.swift`: NSWorkspace adapter and previous-application toggle policy.
- Create `companion/Sources/CodexWatchCompanion/CompanionRuntime.swift`: mode eligibility and retryable watch-loop orchestration.
- Modify `companion/Sources/CodexWatchCompanion/main.swift`: expose shared error/options types as needed and wire the new components into `run()`.
- Modify `companion/Package.swift`: add the companion XCTest target.
- Create `companion/Tests/CodexWatchCompanionTests/HIDShortcutDecoderTests.swift`: framing, validation, resynchronization, release, and debounce coverage.
- Create `companion/Tests/CodexWatchCompanionTests/SuperEngineeringTogglerTests.swift`: activation, launch, return, stale target, and launch-in-flight coverage.
- Create `companion/Tests/CodexWatchCompanionTests/CompanionRuntimeTests.swift`: command-mode eligibility and quota failure isolation.
- Modify `companion/README.md`: document left-swipe behavior, Input Monitoring, ChatGPT mapping, diagnostics, and rollback boundary.

---

### Task 1: Decode and debounce the StopWatch left-swipe report

**Files:**
- Modify: `companion/Package.swift:11-13`
- Create: `companion/Sources/CodexWatchCompanion/HIDShortcutDecoder.swift`
- Create: `companion/Tests/CodexWatchCompanionTests/HIDShortcutDecoderTests.swift`

**Interfaces:**
- Consumes: IOHID callback values expressed as `reportID: Int`, `bytes: [UInt8]`, and monotonic `now: TimeInterval`.
- Produces: `enum CompanionShortcutEvent: Equatable { case toggleSuperEngineering }`, `enum StopwatchHIDDescriptor`, and `HIDShortcutDecoder.consume(reportID:bytes:now:) -> [CompanionShortcutEvent]`.

- [ ] **Step 1: Add the test target and write decoder tests that fail to compile**

Add this target after the executable target in `companion/Package.swift`:

```swift
.testTarget(
    name: "CodexWatchCompanionTests",
    dependencies: ["CodexWatchCompanion"]
),
```

Create `HIDShortcutDecoderTests.swift` with helpers that construct the real body format `[0x02, payloadLength, payload..., padding...]` and tests for a fragmented press, release rearming, cooldown, invalid frames, wrong report IDs, malformed JSON recovery, other directions, non-finite values, and more than one newline-delimited message:

```swift
import XCTest
@testable import CodexWatchCompanion

final class HIDShortcutDecoderTests: XCTestCase {
    private func report(_ fragment: String, paddedTo size: Int = 63) -> [UInt8] {
        let payload = Array(fragment.utf8)
        precondition(payload.count <= 61)
        return [0x02, UInt8(payload.count)] + payload
            + Array(repeating: 0, count: max(0, size - payload.count - 2))
    }

    func testFragmentedLeftPressProducesOneToggle() {
        var decoder = HIDShortcutDecoder()
        XCTAssertEqual(decoder.consume(
            reportID: 6,
            bytes: report(#"{"method":"v.oai."#),
            now: 10
        ), [])
        XCTAssertEqual(decoder.consume(
            reportID: 6,
            bytes: report(#"rad","params":{"a":0.5,"d":1.0}}"# + "\n"),
            now: 10.01
        ), [.toggleSuperEngineering])
    }

    func testReleaseRearmsButCooldownBlocksImmediateSecondPress() {
        var decoder = HIDShortcutDecoder()
        let press = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
        let release = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":0.0}}"# + "\n")
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: press, now: 1), [.toggleSuperEngineering])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: press, now: 1.1), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: release, now: 1.2), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: press, now: 1.3), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: release, now: 1.4), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: press, now: 1.81), [.toggleSuperEngineering])
    }

    func testMalformedFrameClearsBufferAndNextMessageRecovers() {
        var decoder = HIDShortcutDecoder()
        _ = decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai."#), now: 1)
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: [0x02, 60, 0x7B], now: 1.1), [])
        let valid = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: valid, now: 2), [.toggleSuperEngineering])
    }

    func testWrongReportMethodDirectionAndNonFiniteValuesAreIgnored() {
        var decoder = HIDShortcutDecoder()
        let left = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
        XCTAssertEqual(decoder.consume(reportID: 5, bytes: left, now: 1), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"other","params":{"a":0.5,"d":1.0}}"# + "\n"), now: 2), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai.rad","params":{"a":0.0,"d":1.0}}"# + "\n"), now: 3), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai.rad","params":{"a":"NaN","d":1.0}}"# + "\n"), now: 4), [])
    }

    func testOtherReportIDDoesNotDiscardAnInProgressVendorMessage() {
        var decoder = HIDShortcutDecoder()
        XCTAssertEqual(decoder.consume(
            reportID: 6,
            bytes: report(#"{"method":"v.oai."#),
            now: 1
        ), [])
        XCTAssertEqual(decoder.consume(reportID: 5, bytes: [0x00], now: 1.1), [])
        XCTAssertEqual(decoder.consume(
            reportID: 6,
            bytes: report(#"rad","params":{"a":0.5,"d":1.0}}"# + "\n"),
            now: 1.2
        ), [.toggleSuperEngineering])
    }

    func testDescriptorConstantsMatchPhysicalProbe() {
        XCTAssertEqual(StopwatchHIDDescriptor.vendorID, 0x303A)
        XCTAssertEqual(StopwatchHIDDescriptor.productID, 0x8360)
        XCTAssertEqual(StopwatchHIDDescriptor.usagePage, 0xFF00)
        XCTAssertEqual(StopwatchHIDDescriptor.usage, 1)
        XCTAssertEqual(StopwatchHIDDescriptor.reportID, 6)
    }
}
```

Add these two tests to the same class so overflow recovery and multiple newlines are executable requirements:

```swift
func testOversizedBufferIsClearedAndNextMessageRecovers() {
    var decoder = HIDShortcutDecoder()
    for index in 0 ..< 68 {
        XCTAssertEqual(decoder.consume(
            reportID: 6,
            bytes: report(String(repeating: "x", count: 61)),
            now: TimeInterval(index)
        ), [])
    }
    let valid = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
    XCTAssertEqual(decoder.consume(reportID: 6, bytes: valid, now: 100), [.toggleSuperEngineering])
}

func testConsumesEveryNewlineInOneFragment() {
    var decoder = HIDShortcutDecoder()
    let payload = "{}\n" + #"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n"
    XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(payload), now: 1), [.toggleSuperEngineering])
}
```

- [ ] **Step 2: Run the focused test and verify the expected failure**

Run:

```bash
cd companion
swift test --filter HIDShortcutDecoderTests
```

Expected: compilation fails because `HIDShortcutDecoder`, `CompanionShortcutEvent`, and `StopwatchHIDDescriptor` do not exist.

- [ ] **Step 3: Implement the pure decoder with bounded state**

Create `HIDShortcutDecoder.swift` with these public-to-the-module constants and signatures:

```swift
import Foundation

enum CompanionShortcutEvent: Equatable {
    case toggleSuperEngineering
}

enum StopwatchHIDDescriptor {
    static let vendorID = 0x303A
    static let productID = 0x8360
    static let usagePage = 0xFF00
    static let usage = 1
    static let reportID = 6
}

struct HIDShortcutDecoder {
    private static let fragmentMarker: UInt8 = 0x02
    private static let maximumMessageBytes = 4_096
    private static let directionTolerance = 0.05
    private static let distanceTolerance = 0.05
    private static let cooldown: TimeInterval = 0.8

    private struct Message: Decodable {
        struct Parameters: Decodable {
            let a: Double
            let d: Double
        }
        let method: String
        let params: Parameters
    }

    private var receiveBuffer: [UInt8] = []
    private var armed = true
    private var lastAcceptedAt: TimeInterval?

    mutating func consume(
        reportID: Int,
        bytes: [UInt8],
        now: TimeInterval
    ) -> [CompanionShortcutEvent] {
        guard reportID == StopwatchHIDDescriptor.reportID else { return [] }
        guard bytes.count >= 2,
              bytes[0] == Self.fragmentMarker else {
            receiveBuffer.removeAll(keepingCapacity: true)
            return []
        }
        let length = Int(bytes[1])
        guard length <= bytes.count - 2 else {
            receiveBuffer.removeAll(keepingCapacity: true)
            return []
        }
        receiveBuffer.append(contentsOf: bytes[2 ..< 2 + length])
        guard receiveBuffer.count <= Self.maximumMessageBytes else {
            receiveBuffer.removeAll(keepingCapacity: true)
            return []
        }

        var events: [CompanionShortcutEvent] = []
        while let newline = receiveBuffer.firstIndex(of: 0x0A) {
            let line = Data(receiveBuffer[..<newline])
            receiveBuffer.removeSubrange(...newline)
            guard let message = try? JSONDecoder().decode(Message.self, from: line),
                  let event = recognize(message, now: now) else { continue }
            events.append(event)
        }
        return events
    }

    mutating func reset() {
        receiveBuffer.removeAll(keepingCapacity: true)
        armed = true
        lastAcceptedAt = nil
    }

    private mutating func recognize(_ message: Message, now: TimeInterval) -> CompanionShortcutEvent? {
        guard message.method == "v.oai.rad",
              message.params.a.isFinite,
              message.params.d.isFinite,
              abs(message.params.a - 0.5) <= Self.directionTolerance else { return nil }

        if abs(message.params.d) <= Self.distanceTolerance {
            armed = true
            return nil
        }
        guard abs(message.params.d - 1.0) <= Self.distanceTolerance, armed else { return nil }
        guard lastAcceptedAt.map({ now - $0 >= Self.cooldown }) ?? true else { return nil }
        armed = false
        lastAcceptedAt = now
        return .toggleSuperEngineering
    }
}
```

If a focused test exposes a framing fact that differs from the physical probe, adjust the decoder and the test together and record that evidence in the task notes; do not loosen the exact device/report matching.

- [ ] **Step 4: Run the decoder tests and the complete suite**

Run:

```bash
swift test --filter HIDShortcutDecoderTests
swift test
```

Expected: all tests pass with no test reading a physical HID device.

- [ ] **Step 5: Commit the decoder boundary**

```bash
git add companion/Package.swift companion/Sources/CodexWatchCompanion/HIDShortcutDecoder.swift companion/Tests/CodexWatchCompanionTests/HIDShortcutDecoderTests.swift
git commit -m "feat: decode stopwatch shortcut gestures"
```

---

### Task 2: Implement the safe super.engineering application toggle policy

**Files:**
- Create: `companion/Sources/CodexWatchCompanion/SuperEngineeringToggler.swift`
- Create: `companion/Tests/CodexWatchCompanionTests/SuperEngineeringTogglerTests.swift`

**Interfaces:**
- Consumes: logical `.toggleSuperEngineering` events from Task 1.
- Produces: `ApplicationIdentity`, `WorkspaceApplications`, `NSWorkspaceApplications`, and `SuperEngineeringToggler.toggle()`.

- [ ] **Step 1: Write policy tests using an in-memory workspace**

Create `SuperEngineeringTogglerTests.swift` with this in-memory workspace and concrete policy tests:

```swift
import XCTest
@testable import CodexWatchCompanion

final class WorkspaceStub: WorkspaceApplications {
    var frontmost: ApplicationIdentity?
    var runningByBundleID: [String: ApplicationIdentity] = [:]
    var activatable: Set<ApplicationIdentity> = []
    var activations: [ApplicationIdentity] = []
    var launchRequests: [String] = []
    var launchCompletion: ((Bool) -> Void)?

    func runningApplication(bundleIdentifier: String) -> ApplicationIdentity? {
        runningByBundleID[bundleIdentifier]
    }

    func activate(_ identity: ApplicationIdentity) -> Bool {
        guard activatable.contains(identity) else { return false }
        activations.append(identity)
        return true
    }

    func launchAndActivate(bundleIdentifier: String, completion: @escaping (Bool) -> Void) {
        launchRequests.append(bundleIdentifier)
        launchCompletion = completion
    }
}

final class SuperEngineeringTogglerTests: XCTestCase {
    private let chatGPT = ApplicationIdentity(processIdentifier: 101, bundleIdentifier: "com.openai.chat")
    private let superApp = ApplicationIdentity(processIdentifier: 202, bundleIdentifier: "com.zarifpour.superconductor")

    func testOrdinaryFrontmostActivatesRunningSuperAndReturnsToExactProcess() {
        let workspace = WorkspaceStub()
        workspace.frontmost = chatGPT
        workspace.runningByBundleID[superApp.bundleIdentifier] = superApp
        workspace.activatable = [chatGPT, superApp]
        let toggler = SuperEngineeringToggler(workspace: workspace, log: { _ in })
        toggler.toggle()
        XCTAssertEqual(workspace.activations, [superApp])
        workspace.frontmost = superApp
        toggler.toggle()
        XCTAssertEqual(workspace.activations, [superApp, chatGPT])
    }

    func testMissingSuperLaunchesByBundleIdentifier() {
        let workspace = WorkspaceStub()
        workspace.frontmost = chatGPT
        let toggler = SuperEngineeringToggler(workspace: workspace, log: { _ in })
        toggler.toggle()
        XCTAssertEqual(workspace.launchRequests, ["com.zarifpour.superconductor"])
    }

    func testSecondToggleDuringLaunchIsIgnored() {
        let workspace = WorkspaceStub()
        workspace.frontmost = chatGPT
        let toggler = SuperEngineeringToggler(workspace: workspace, log: { _ in })
        toggler.toggle()
        toggler.toggle()
        XCTAssertEqual(workspace.launchRequests.count, 1)
        workspace.launchCompletion?(false)
        toggler.toggle()
        XCTAssertEqual(workspace.launchRequests.count, 2)
    }

    func testSuperFrontmostWithExitedPreviousApplicationDoesNothing() {
        let workspace = WorkspaceStub()
        workspace.frontmost = chatGPT
        workspace.runningByBundleID[superApp.bundleIdentifier] = superApp
        workspace.activatable = [superApp]
        let toggler = SuperEngineeringToggler(workspace: workspace, log: { _ in })
        toggler.toggle()
        workspace.frontmost = superApp
        workspace.activatable = []
        toggler.toggle()
        XCTAssertEqual(workspace.activations, [superApp])
    }

    func testPIDReuseWithDifferentBundleIdentifierCannotBeActivated() {
        let workspace = WorkspaceStub()
        workspace.frontmost = chatGPT
        workspace.runningByBundleID[superApp.bundleIdentifier] = superApp
        workspace.activatable = [superApp]
        let toggler = SuperEngineeringToggler(workspace: workspace, log: { _ in })
        toggler.toggle()
        workspace.frontmost = superApp
        workspace.activatable = [
            ApplicationIdentity(processIdentifier: 101, bundleIdentifier: "com.example.reused-pid")
        ]
        toggler.toggle()
        XCTAssertEqual(workspace.activations, [superApp])
    }

    func testCompanionIsNeverStoredAsReturnTarget() {
        let workspace = WorkspaceStub()
        let companion = ApplicationIdentity(
            processIdentifier: 303,
            bundleIdentifier: "io.github.codex-micro-stopwatch.companion"
        )
        workspace.frontmost = companion
        workspace.runningByBundleID[superApp.bundleIdentifier] = superApp
        workspace.activatable = [superApp, companion]
        let toggler = SuperEngineeringToggler(workspace: workspace, log: { _ in })
        toggler.toggle()
        workspace.frontmost = superApp
        toggler.toggle()
        XCTAssertEqual(workspace.activations, [superApp])
    }
}
```

- [ ] **Step 2: Run the focused tests and verify the expected failure**

Run:

```bash
cd companion
swift test --filter SuperEngineeringTogglerTests
```

Expected: compilation fails because the application identity, workspace protocol, and toggler do not exist.

- [ ] **Step 3: Implement the workspace abstraction and toggle state machine**

Create `SuperEngineeringToggler.swift` with these interfaces:

```swift
import AppKit
import Foundation

struct ApplicationIdentity: Equatable, Hashable {
    let processIdentifier: pid_t
    let bundleIdentifier: String
}

protocol WorkspaceApplications: AnyObject {
    var frontmost: ApplicationIdentity? { get }
    func runningApplication(bundleIdentifier: String) -> ApplicationIdentity?
    @discardableResult func activate(_ identity: ApplicationIdentity) -> Bool
    func launchAndActivate(bundleIdentifier: String, completion: @escaping (Bool) -> Void)
}

final class NSWorkspaceApplications: WorkspaceApplications {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    var frontmost: ApplicationIdentity? {
        identity(for: workspace.frontmostApplication)
    }

    func runningApplication(bundleIdentifier: String) -> ApplicationIdentity? {
        workspace.runningApplications
            .first(where: { $0.bundleIdentifier == bundleIdentifier })
            .flatMap { identity(for: $0) }
    }

    func activate(_ identity: ApplicationIdentity) -> Bool {
        guard let application = NSRunningApplication(processIdentifier: identity.processIdentifier),
              application.bundleIdentifier == identity.bundleIdentifier,
              !application.isTerminated else { return false }
        return application.activate(options: [.activateIgnoringOtherApps])
    }

    func launchAndActivate(bundleIdentifier: String, completion: @escaping (Bool) -> Void) {
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            completion(false)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.openApplication(at: url, configuration: configuration) { application, _ in
            DispatchQueue.main.async {
                completion(application?.bundleIdentifier == bundleIdentifier)
            }
        }
    }

    private func identity(for application: NSRunningApplication?) -> ApplicationIdentity? {
        guard let application, let bundleIdentifier = application.bundleIdentifier else { return nil }
        return ApplicationIdentity(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: bundleIdentifier
        )
    }
}
```

Implement `SuperEngineeringToggler` with constants for target and companion bundle identifiers, `previousApplication`, and `launchInFlight`. `toggle()` must follow this exact branch order:

```swift
final class SuperEngineeringToggler {
    static let targetBundleIdentifier = "com.zarifpour.superconductor"
    static let companionBundleIdentifier = "io.github.codex-micro-stopwatch.companion"

    private let workspace: WorkspaceApplications
    private let log: (String) -> Void
    private var previousApplication: ApplicationIdentity?
    private var launchInFlight = false

    init(workspace: WorkspaceApplications, log: @escaping (String) -> Void) {
        self.workspace = workspace
        self.log = log
    }

    func toggle() {
        guard !launchInFlight else { return }
        if workspace.frontmost?.bundleIdentifier == Self.targetBundleIdentifier {
            guard let previousApplication else {
                log("super.engineering 已在前台，但没有可返回的应用")
                return
            }
            if workspace.activate(previousApplication) {
                log("已返回之前的应用")
            } else {
                log("之前的应用已退出或无法激活")
            }
            return
        }

        if let frontmost = workspace.frontmost,
           frontmost.bundleIdentifier != Self.companionBundleIdentifier {
            previousApplication = frontmost
        }
        if let running = workspace.runningApplication(bundleIdentifier: Self.targetBundleIdentifier) {
            log(workspace.activate(running) ? "已激活 super.engineering" : "无法激活 super.engineering")
            return
        }

        launchInFlight = true
        workspace.launchAndActivate(bundleIdentifier: Self.targetBundleIdentifier) { [weak self] success in
            guard let self else { return }
            self.launchInFlight = false
            self.log(success ? "已启动 super.engineering" : "找不到或无法启动 super.engineering")
        }
    }
}
```

Logs must remain fixed messages like those above; do not interpolate application names, paths, process IDs, or content.

- [ ] **Step 4: Run toggler and full tests**

Run:

```bash
swift test --filter SuperEngineeringTogglerTests
swift test
```

Expected: all policy tests pass, including the stale PID/bundle check enforced by the real adapter contract and the launch-in-flight guard.

- [ ] **Step 5: Commit the toggle policy**

```bash
git add companion/Sources/CodexWatchCompanion/SuperEngineeringToggler.swift companion/Tests/CodexWatchCompanionTests/SuperEngineeringTogglerTests.swift
git commit -m "feat: toggle super engineering application"
```

---

### Task 3: Connect the pure decoder to the exact vendor HID device

**Files:**
- Create: `companion/Sources/CodexWatchCompanion/HIDShortcutListener.swift`
- Test: `companion/Tests/CodexWatchCompanionTests/HIDShortcutDecoderTests.swift`

**Interfaces:**
- Consumes: `StopwatchHIDDescriptor`, `HIDShortcutDecoder`, and `CompanionShortcutEvent` from Task 1.
- Produces: `HIDShortcutListening`, `HIDShortcutListener.start() throws`, and `HIDShortcutListener.stop()` for runtime wiring in Task 4.

- [ ] **Step 1: Add a test that locks the IOHID matching dictionary**

Extend `HIDShortcutDecoderTests` with:

```swift
func testMatchingDictionaryContainsOnlyExpectedDeviceIdentity() {
    XCTAssertEqual(HIDShortcutListener.matching.count, 4)
    XCTAssertEqual(HIDShortcutListener.matching[kIOHIDVendorIDKey as String] as? Int, 0x303A)
    XCTAssertEqual(HIDShortcutListener.matching[kIOHIDProductIDKey as String] as? Int, 0x8360)
    XCTAssertEqual(HIDShortcutListener.matching[kIOHIDPrimaryUsagePageKey as String] as? Int, 0xFF00)
    XCTAssertEqual(HIDShortcutListener.matching[kIOHIDPrimaryUsageKey as String] as? Int, 1)
}
```

Add `import IOKit.hid` to the test file.

- [ ] **Step 2: Run the focused test and verify the expected failure**

Run:

```bash
cd companion
swift test --filter HIDShortcutDecoderTests/testMatchingDictionaryContainsOnlyExpectedDeviceIdentity
```

Expected: compilation fails because `HIDShortcutListener` does not exist.

- [ ] **Step 3: Implement the IOHIDManager lifecycle**

Create `HIDShortcutListener.swift` with:

```swift
import Foundation
import IOKit.hid

protocol HIDShortcutListening: AnyObject {
    func start() throws
    func stop()
}

enum HIDShortcutListenerError: LocalizedError {
    case openFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case .openFailed(let result):
            return String(format: "无法打开 StopWatch HID 监听：0x%08X", result)
        }
    }
}

final class HIDShortcutListener: HIDShortcutListening {
    static let matching: [String: Any] = [
        kIOHIDVendorIDKey as String: StopwatchHIDDescriptor.vendorID,
        kIOHIDProductIDKey as String: StopwatchHIDDescriptor.productID,
        kIOHIDPrimaryUsagePageKey as String: StopwatchHIDDescriptor.usagePage,
        kIOHIDPrimaryUsageKey as String: StopwatchHIDDescriptor.usage,
    ]

    private let eventHandler: (CompanionShortcutEvent) -> Void
    private let log: (String) -> Void
    private var manager: IOHIDManager?
    private var decodersByDevice: [UInt: HIDShortcutDecoder] = [:]
    private var warnedAboutPermission = false

    init(
        eventHandler: @escaping (CompanionShortcutEvent) -> Void,
        log: @escaping (String) -> Void
    ) {
        self.eventHandler = eventHandler
        self.log = log
    }
}
```

In `start()`, create one manager, set only `Self.matching`, register input, matching, and removal callbacks with `Unmanaged.passUnretained(self).toOpaque()`, schedule it on `CFRunLoopGetMain()` in the default mode, and open with `kIOHIDOptionsTypeNone`. If `IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)` is denied, log the fixed permission warning once but still let quota sync continue. If open fails, unschedule/close and throw `openFailed`.

The input callback must require `kIOReturnSuccess`, `kIOHIDReportTypeInput`, a non-null device sender, and report ID 6 before copying exactly `reportLength` bytes. Derive `deviceKey` with `UInt(bitPattern: sender)`, retrieve or create that device's decoder, then store the mutated decoder back:

```swift
let now = ProcessInfo.processInfo.systemUptime
var decoder = decodersByDevice[deviceKey] ?? HIDShortcutDecoder()
let events = decoder.consume(reportID: Int(reportID), bytes: bytes, now: now)
decodersByDevice[deviceKey] = decoder
events.forEach(eventHandler)
```

The matching callback creates an empty decoder entry for the exact device key and logs only `StopWatch HID 已连接`. The removal callback removes only that device's decoder and logs only `StopWatch HID 已断开`. `stop()` unschedules and closes the exact manager, clears it, and removes all decoder entries. `deinit` calls `stop()`.

- [ ] **Step 4: Build and run all tests without requiring hardware**

Run:

```bash
swift test
swift build -c release
```

Expected: tests and release build pass. No test opens IOHIDManager or requests Input Monitoring.

- [ ] **Step 5: Commit the IOKit adapter**

```bash
git add companion/Sources/CodexWatchCompanion/HIDShortcutListener.swift companion/Tests/CodexWatchCompanionTests/HIDShortcutDecoderTests.swift
git commit -m "feat: listen for stopwatch shortcut reports"
```

---

### Task 4: Wire watch-mode lifecycle and isolate quota-cycle failures

**Files:**
- Create: `companion/Sources/CodexWatchCompanion/CompanionRuntime.swift`
- Modify: `companion/Sources/CodexWatchCompanion/main.swift:501-675`
- Create: `companion/Tests/CodexWatchCompanionTests/CompanionRuntimeTests.swift`

**Interfaces:**
- Consumes: `HIDShortcutListener`, `NSWorkspaceApplications`, and `SuperEngineeringToggler` from Tasks 2-3.
- Produces: `Options.startsHIDShortcutListener`, argument-injectable `parseOptions(_:)`, and `runQuotaLoop(watch:interval:cycle:wait:reportError:shouldContinue:)`.

- [ ] **Step 1: Write mode and retry-isolation tests**

Create `CompanionRuntimeTests.swift` with:

```swift
import XCTest
@testable import CodexWatchCompanion

final class CompanionRuntimeTests: XCTestCase {
    func testOnlyRealWatchModeStartsHIDListener() throws {
        XCTAssertTrue(try parseOptions(["companion", "--watch", "--device-id", "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"]).startsHIDShortcutListener)
        XCTAssertFalse(try parseOptions(["companion", "--watch", "--demo"]).startsHIDShortcutListener)
        XCTAssertFalse(try parseOptions(["companion", "--json-only"]).startsHIDShortcutListener)
        XCTAssertFalse(try parseOptions(["companion"]).startsHIDShortcutListener)
    }

    func testWatchLoopReportsFailureThenRunsNextCycle() throws {
        struct ExpectedFailure: Error {}
        var cycles = 0
        var waits: [TimeInterval] = []
        var reportedErrors = 0
        try runQuotaLoop(
            watch: true,
            interval: 60,
            cycle: {
                cycles += 1
                if cycles == 1 { throw ExpectedFailure() }
            },
            wait: { waits.append($0) },
            reportError: { _ in reportedErrors += 1 },
            shouldContinue: { cycles < 2 }
        )
        XCTAssertEqual(cycles, 2)
        XCTAssertEqual(waits, [60])
        XCTAssertEqual(reportedErrors, 1)
    }

    func testOneShotLoopRethrowsImmediately() {
        struct ExpectedFailure: Error {}
        XCTAssertThrowsError(try runQuotaLoop(
            watch: false,
            interval: 60,
            cycle: { throw ExpectedFailure() },
            wait: { _ in XCTFail("one-shot mode must not wait") },
            reportError: { _ in XCTFail("one-shot mode must not absorb errors") },
            shouldContinue: { true }
        ))
    }
}
```

- [ ] **Step 2: Run the focused test and verify the expected failure**

Run:

```bash
cd companion
swift test --filter CompanionRuntimeTests
```

Expected: compilation fails because the injectable option parser, mode property, and quota-loop helper do not exist.

- [ ] **Step 3: Add testable mode and quota-loop orchestration**

Change `Options` from `private` to module-internal and keep every existing stored property:

```swift
struct Options {
    var codexPath = defaultCodexPath()
    var demo = false
    var jsonOnly = false
    var watch = false
    var interval: TimeInterval = 60
    var verbose = false
    var deviceIdentifier: UUID?
    var enterBootloader = false

    var startsHIDShortcutListener: Bool {
        watch && !demo && !jsonOnly && !enterBootloader
    }
}
```

Change the parser declaration and remove its current local `let arguments = CommandLine.arguments`; the existing switch body continues to use the new parameter:

```diff
-private func parseOptions() throws -> Options {
+func parseOptions(_ arguments: [String] = CommandLine.arguments) throws -> Options {
     var options = Options()
     var index = 1
-    let arguments = CommandLine.arguments
     while index < arguments.count {
```

Do not change the existing cases, validation messages, index increments, or returned `Options` value.

Create `CompanionRuntime.swift` with the exact loop contract exercised above:

```swift
import Foundation

func runQuotaLoop(
    watch: Bool,
    interval: TimeInterval,
    cycle: () throws -> Void,
    wait: (TimeInterval) -> Void,
    reportError: (Error) -> Void,
    shouldContinue: () -> Bool = { true }
) throws {
    while true {
        do {
            try cycle()
        } catch {
            guard watch else { throw error }
            reportError(error)
        }
        guard watch, shouldContinue() else { return }
        wait(interval)
    }
}
```

- [ ] **Step 4: Wire the listener and quota loop in `run()`**

After option validation and before creating the Codex client, create strong local references:

```swift
var shortcutToggler: SuperEngineeringToggler?
var shortcutListener: HIDShortcutListener?
if options.startsHIDShortcutListener {
    let toggler = SuperEngineeringToggler(
        workspace: NSWorkspaceApplications(),
        log: { fputs("快捷键：\($0)\n", stderr) }
    )
    let listener = HIDShortcutListener(
        eventHandler: { [weak toggler] event in
            if event == .toggleSuperEngineering { toggler?.toggle() }
        },
        log: { fputs("快捷键：\($0)\n", stderr) }
    )
    do {
        try listener.start()
        shortcutToggler = toggler
        shortcutListener = listener
    } catch {
        fputs("快捷键不可用：\(error.localizedDescription)\n", stderr)
    }
}
defer {
    shortcutListener?.stop()
    shortcutListener = nil
    shortcutToggler = nil
}
```

Move Codex client initialization into the quota-cycle closure and use `runQuotaLoop`. On any watch-mode cycle error, set `client = nil`, log one bounded line, wait on the current RunLoop, and retry. One-shot modes continue throwing:

```swift
var client: AppServerClient?
try runQuotaLoop(
    watch: options.watch,
    interval: options.interval,
    cycle: {
        if !options.demo, client == nil {
            client = try AppServerClient(codexPath: options.codexPath)
        }
        let snapshot: QuotaSnapshot
        if options.demo {
            snapshot = QuotaSnapshot(remainingPercent: 59, resetInSeconds: 3_600)
        } else {
            snapshot = try client!.readRateLimits()
        }
        let payload = try encoder.encode(snapshot)
        guard let json = String(data: payload, encoding: .utf8) else {
            throw CompanionError.malformedRateLimits("无法编码额度 JSON")
        }
        print(json)
        if !options.jsonOnly {
            _ = try BLEQuotaWriter(
                payload: payload,
                verbose: options.verbose,
                expectedIdentifier: options.deviceIdentifier
            ).write()
            print("✓ 已写入 StopWatch：剩余 \(Int(snapshot.remainingPercent.rounded()))%，\(formatReset(seconds: snapshot.resetInSeconds)) 后重置")
        }
    },
    wait: { seconds in
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    },
    reportError: { error in
        client = nil
        fputs("额度同步失败，将重试：\(error.localizedDescription)\n", stderr)
    }
)
```

Do not move HID input onto a global event tap, do not spawn a shell process, and do not alter the bootloader branch.

- [ ] **Step 5: Run runtime tests, all tests, and mode smoke checks**

Run:

```bash
swift test --filter CompanionRuntimeTests
swift test
swift run codex-watch-companion --json-only
swift run codex-watch-companion --demo --verbose
```

Expected: tests pass; JSON-only prints one real quota JSON without opening Bluetooth/HID; demo prints synthetic quota and performs its existing BLE discovery/write behavior without starting the shortcut listener. If no physical StopWatch is available during this code task, the demo BLE result is reported separately rather than converted into a passing claim.

- [ ] **Step 6: Commit runtime integration**

```bash
git add companion/Sources/CodexWatchCompanion/CompanionRuntime.swift companion/Sources/CodexWatchCompanion/main.swift companion/Tests/CodexWatchCompanionTests/CompanionRuntimeTests.swift
git commit -m "feat: enable stopwatch shortcut in watch mode"
```

---

### Task 5: Document permissions, configuration, and regression boundaries

**Files:**
- Modify: `companion/README.md:1-122`

**Interfaces:**
- Consumes: the completed companion CLI behavior from Task 4.
- Produces: installation and operator guidance without storing local identifiers or paths.

- [ ] **Step 1: Add focused companion documentation**

Add a `## Optional super.engineering left-swipe shortcut` section after continuous refresh guidance. State all of the following explicitly:

```markdown
## Optional super.engineering left-swipe shortcut

In a real `--watch` process, the companion also listens to the explicitly
matched C152 vendor HID interface. One left swipe activates the installed app
whose bundle identifier is `com.zarifpour.superconductor`; a second left swipe
returns to the exact previously running application. If that application has
exited, the companion stays in super.engineering.

This feature does not call `sc`, run a command, inspect a workspace or session,
or change StopWatch firmware. It is disabled for one-shot, `--demo`,
`--json-only`, and bootloader modes.

Before using it:

1. Remove the ChatGPT action assigned to Analog stick left. Leave up, right,
   and down unchanged.
2. Add the locally installed `CodexWatchCompanion.app` to macOS System Settings
   > Privacy & Security > Input Monitoring.
3. Restart the per-user LaunchAgent after the permission change.

Missing Input Monitoring affects only the shortcut; quota sync retains its
normal watch-mode retry loop. The first successful result still requires a
physical C152 round-trip test and cannot be inferred from a build.
```

Update the Data boundary paragraph so it says the companion recognizes only the left radial event and does not capture keyboard text; remove the now-inaccurate sentence that all analog directions remain outside the companion.

- [ ] **Step 2: Run documentation and release checks**

Run:

```bash
git diff --check
rg -n "super.engineering|Input Monitoring|Analog stick left|does not capture" companion/README.md
cd companion
swift test
swift build -c release
```

Expected: no whitespace errors, all required guidance is present, tests pass, and the release executable builds.

- [ ] **Step 3: Review the implementation against every spec section**

Read `docs/superpowers/specs/2026-08-28-super-engineering-shortcut-design.md` from top to bottom and record results for:

- exact HID matching and report filtering;
- bounded frame reset/recovery;
- finite values, release gate, and 800-millisecond cooldown;
- exact PID plus bundle identifier return behavior;
- missing app and stale previous app no-op behavior;
- no shell/CLI/content access;
- watch-only lifecycle and quota failure isolation;
- permissions and bounded logs;
- local install/rollback and each physical acceptance layer.

Expected: every implementation requirement maps to code, automated test, documentation, or the explicit physical-validation task below. Any discovered gap is fixed and re-tested before committing.

- [ ] **Step 4: Commit documentation and any review corrections**

```bash
git add companion/README.md companion/Sources companion/Tests companion/Package.swift
git commit -m "docs: explain super engineering shortcut setup"
```

If review produced no code corrections, the commit contains only `companion/README.md`.

---

### Task 6: Install locally and validate every layer on the physical C152

**Files:**
- Read: `companion/.build/release/codex-watch-companion`
- Replace locally after approval: `$HOME/Library/Application Support/Codex Micro StopWatch/CodexWatchCompanion.app/Contents/MacOS/codex-watch-companion`
- Preserve locally: `$HOME/Library/LaunchAgents/io.github.codex-micro-stopwatch.companion.plist`
- Back up locally: `/private/tmp/codex-watch-companion-super-shortcut-backup/CodexWatchCompanion.app`
- Do not modify tracked firmware files or the tracked LaunchAgent example.

**Interfaces:**
- Consumes: signed local app wrapper and LaunchAgent already installed for this Mac.
- Produces: a physically observed validation matrix and a recoverable previous companion app.

- [ ] **Step 1: Run final read-only preflight checks**

Run from the repository root:

```bash
git status --short
sw_vers -productVersion
swift --version
test -x companion/.build/release/codex-watch-companion
test -x "$HOME/Library/Application Support/Codex Micro StopWatch/CodexWatchCompanion.app/Contents/MacOS/codex-watch-companion"
plutil -lint "$HOME/Library/LaunchAgents/io.github.codex-micro-stopwatch.companion.plist"
launchctl print "gui/$UID/io.github.codex-micro-stopwatch.companion"
```

Expected: clean repository, macOS 14+, Swift 5.10+, both executables present, plist valid, and the current LaunchAgent visible. Do not print or copy its device UUID into Git or chat.

- [ ] **Step 2: Create an exact recoverable backup before replacement**

Run these as separate commands and stop if the backup path already exists:

```bash
test ! -e /private/tmp/codex-watch-companion-super-shortcut-backup
mkdir -m 700 /private/tmp/codex-watch-companion-super-shortcut-backup
ditto "$HOME/Library/Application Support/Codex Micro StopWatch/CodexWatchCompanion.app" /private/tmp/codex-watch-companion-super-shortcut-backup/CodexWatchCompanion.app
codesign --verify --deep --strict /private/tmp/codex-watch-companion-super-shortcut-backup/CodexWatchCompanion.app
```

Expected: the previous signed app is preserved outside the repository. This installation mutation requires the user's approval if the execution environment requests it.

- [ ] **Step 3: Stop the exact agent, replace only the companion executable, and re-sign**

Run:

```bash
launchctl bootout "gui/$UID/io.github.codex-micro-stopwatch.companion"
install -m 755 companion/.build/release/codex-watch-companion "$HOME/Library/Application Support/Codex Micro StopWatch/CodexWatchCompanion.app/Contents/MacOS/codex-watch-companion"
codesign --force --deep --sign - "$HOME/Library/Application Support/Codex Micro StopWatch/CodexWatchCompanion.app"
codesign --verify --deep --strict "$HOME/Library/Application Support/Codex Micro StopWatch/CodexWatchCompanion.app"
```

Expected: only the local wrapper executable changes and the wrapper verifies after ad-hoc signing. Do not touch the C152 serial port or run PlatformIO upload.

- [ ] **Step 4: Restart the existing LaunchAgent without rewriting its local values**

Run:

```bash
launchctl bootstrap "gui/$UID" "$HOME/Library/LaunchAgents/io.github.codex-micro-stopwatch.companion.plist"
launchctl kickstart -k "gui/$UID/io.github.codex-micro-stopwatch.companion"
launchctl print "gui/$UID/io.github.codex-micro-stopwatch.companion"
```

Expected: agent state is running and uses the existing plist. Do not regenerate the plist or expose its private local values.

- [ ] **Step 5: Grant Input Monitoring and remove the ChatGPT left mapping**

In macOS System Settings, add or re-enable `CodexWatchCompanion.app` under Privacy & Security > Input Monitoring. In ChatGPT Desktop's Codex Micro control mapping, set Analog stick left to unassigned and leave up, right, and down untouched. Restart the exact LaunchAgent once more with the commands from Step 4 after the permission change.

Expected: the companion is listed and enabled for Input Monitoring, and Analog stick left has no ChatGPT action. Treat this as user-observed permission/configuration evidence, not as proof the gesture works.

- [ ] **Step 6: Validate the left-swipe state machine on physical hardware**

Observe and record each case separately:

1. ChatGPT foreground -> one left swipe -> super.engineering foreground.
2. A second left swipe -> the same ChatGPT process foreground.
3. Repeat the round trip from Claude Code and Cursor.
4. Quit super.engineering, then left swipe -> super.engineering launches and activates.
5. Swipe/press rapidly -> no immediate duplicate return.
6. Enter super.engineering from a disposable ordinary app, quit that previous app, then left swipe -> remain in super.engineering.
7. Disconnect and reconnect the StopWatch, then repeat a round trip without restarting the companion.

Expected: all seven behaviors are physically observed. A failed case remains reported as failed or unverified; do not reinterpret logs as foreground-switch proof.

- [ ] **Step 7: Validate unaffected controls, microphone, quota, and automatic startup**

Run the USB input checks without storing audio in the repository:

```bash
swift scripts/usb_mic_capture.swift --list-inputs
swift scripts/usb_mic_capture.swift --device "Codex StopWatch Mic" --output /private/tmp/codex-stopwatch-mic-shortcut-validation.wav --seconds 3
test -s /private/tmp/codex-stopwatch-mic-shortcut-validation.wav
unlink /private/tmp/codex-stopwatch-mic-shortcut-validation.wav
```

Physically verify up, right, and down mappings still perform their configured ChatGPT actions. Observe one new quota/reset update on the StopWatch after the configured interval. Verify the LaunchAgent remains running with:

```bash
launchctl print "gui/$UID/io.github.codex-micro-stopwatch.companion"
```

Expected: microphone enumeration/capture, three unaffected directions, quota update, and automatic companion runtime each receive a separate pass/fail result.

- [ ] **Step 8: Use the recoverable rollback if any critical acceptance layer fails**

If app switching is unsafe, the companion repeatedly exits, or quota sync regresses, restore only the backed-up app:

```bash
launchctl bootout "gui/$UID/io.github.codex-micro-stopwatch.companion"
ditto /private/tmp/codex-watch-companion-super-shortcut-backup/CodexWatchCompanion.app "$HOME/Library/Application Support/Codex Micro StopWatch/CodexWatchCompanion.app"
codesign --verify --deep --strict "$HOME/Library/Application Support/Codex Micro StopWatch/CodexWatchCompanion.app"
launchctl bootstrap "gui/$UID" "$HOME/Library/LaunchAgents/io.github.codex-micro-stopwatch.companion.plist"
launchctl print "gui/$UID/io.github.codex-micro-stopwatch.companion"
```

Expected: the previous companion is running again; no firmware rollback is needed. Keep or remove the temporary backup only after the user decides the new installation is accepted.

- [ ] **Step 9: Report the final validation matrix**

Report separate statuses for:

- source changes and commit history;
- Swift tests and release build;
- local app backup, replacement, signing, and LaunchAgent health;
- Input Monitoring and ChatGPT Analog-left configuration;
- physical HID recognition and all seven toggle cases;
- up/right/down controls;
- USB microphone enumeration and capture;
- real quota/reset update;
- reconnect recovery and automatic startup;
- rollback availability.

Use only `passed`, `failed`, or `unverified` for each layer, with the observed evidence. Never collapse these into a single success claim.
