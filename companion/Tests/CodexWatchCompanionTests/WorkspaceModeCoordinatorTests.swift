import IOKit.hid
import XCTest
@testable import CodexWatchCompanion

@MainActor
private final class ForegroundObserverStub: ForegroundApplicationObserving {
    var frontmostBundleIdentifier: String?
    private var handler: (@MainActor (String?) -> Void)?
    private let trace: ((String) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(frontmostBundleIdentifier: String?, trace: ((String) -> Void)? = nil) {
        self.frontmostBundleIdentifier = frontmostBundleIdentifier
        self.trace = trace
    }

    func start(_ handler: @MainActor @escaping (String?) -> Void) {
        startCount += 1
        self.handler = handler
    }

    func stop() {
        stopCount += 1
        handler = nil
        trace?("observer:stop")
    }

    func activate(_ bundleIdentifier: String?) {
        frontmostBundleIdentifier = bundleIdentifier
        handler?(bundleIdentifier)
    }
}

@MainActor
private final class ScheduledTaskStub: WorkspaceModeScheduledTask {
    private let handler: @MainActor () -> Void
    private let trace: ((String) -> Void)?
    private(set) var cancelled = false

    init(handler: @MainActor @escaping () -> Void, trace: ((String) -> Void)? = nil) {
        self.handler = handler
        self.trace = trace
    }

    func cancel() {
        cancelled = true
        trace?("timer:cancel")
    }

    func fire() {
        guard !cancelled else { return }
        handler()
    }
}

@MainActor
private final class SchedulerStub: WorkspaceModeScheduling {
    private let trace: ((String) -> Void)?
    private(set) var intervals: [TimeInterval] = []
    private(set) var tasks: [ScheduledTaskStub] = []

    init(trace: ((String) -> Void)? = nil) {
        self.trace = trace
    }

    func scheduleRepeating(
        every interval: TimeInterval,
        _ handler: @MainActor @escaping () -> Void
    ) -> WorkspaceModeScheduledTask {
        intervals.append(interval)
        let task = ScheduledTaskStub(handler: handler, trace: trace)
        tasks.append(task)
        return task
    }
}

@MainActor
private final class WorkspaceSenderStub: WorkspaceModeSending {
    let deviceKey: UInt
    var results: [Bool] = []
    private(set) var modes: [StopwatchWorkspaceMode] = []
    private let trace: ((String) -> Void)?

    init(deviceKey: UInt, trace: ((String) -> Void)? = nil) {
        self.deviceKey = deviceKey
        self.trace = trace
    }

    func send(_ mode: StopwatchWorkspaceMode) -> Bool {
        modes.append(mode)
        trace?("send:\(mode == .super ? "super" : "codex")")
        return results.isEmpty ? true : results.removeFirst()
    }
}

@MainActor
final class WorkspaceModeCoordinatorTests: XCTestCase {
    func testStartReadsForegroundAttachSyncsImmediatelyAndSuperHeartbeatsEveryFiveSeconds() {
        let observer = ForegroundObserverStub(
            frontmostBundleIdentifier: WorkspaceModeCoordinator.targetBundleIdentifier
        )
        let scheduler = SchedulerStub()
        let coordinator = WorkspaceModeCoordinator(
            foregroundObserver: observer,
            scheduler: scheduler,
            uptime: { 0 },
            log: { _ in }
        )

        coordinator.start()
        let sender = WorkspaceSenderStub(deviceKey: 1)
        coordinator.attach(sender)
        scheduler.tasks.first?.fire()

        XCTAssertEqual(observer.startCount, 1)
        XCTAssertEqual(scheduler.intervals, [5])
        XCTAssertEqual(sender.modes, [.super, .super])
    }

    func testForegroundTransitionsSendImmediatelyAndCancelHeartbeatOnExit() {
        let observer = ForegroundObserverStub(frontmostBundleIdentifier: "com.openai.chat")
        let scheduler = SchedulerStub()
        let coordinator = WorkspaceModeCoordinator(
            foregroundObserver: observer,
            scheduler: scheduler,
            uptime: { 0 },
            log: { _ in }
        )
        coordinator.start()
        let sender = WorkspaceSenderStub(deviceKey: 1)
        coordinator.attach(sender)

        observer.activate(WorkspaceModeCoordinator.targetBundleIdentifier)
        observer.activate(WorkspaceModeCoordinator.targetBundleIdentifier)
        scheduler.tasks.first?.fire()
        observer.activate("com.openai.chat")
        scheduler.tasks.first?.fire()

        XCTAssertEqual(sender.modes, [.codex, .super, .super, .codex])
        XCTAssertEqual(scheduler.tasks.count, 1)
        XCTAssertTrue(scheduler.tasks[0].cancelled)
    }

    func testDeviceRemovalDoesNotAffectOtherDeviceAndReconnectResyncs() {
        let observer = ForegroundObserverStub(
            frontmostBundleIdentifier: WorkspaceModeCoordinator.targetBundleIdentifier
        )
        let scheduler = SchedulerStub()
        let coordinator = WorkspaceModeCoordinator(
            foregroundObserver: observer,
            scheduler: scheduler,
            uptime: { 0 },
            log: { _ in }
        )
        coordinator.start()
        let first = WorkspaceSenderStub(deviceKey: 1)
        let second = WorkspaceSenderStub(deviceKey: 2)
        coordinator.attach(first)
        coordinator.attach(second)

        coordinator.detach(deviceKey: 1)
        scheduler.tasks[0].fire()
        let reconnected = WorkspaceSenderStub(deviceKey: 1)
        coordinator.attach(reconnected)

        XCTAssertEqual(first.modes, [.super])
        XCTAssertEqual(second.modes, [.super, .super])
        XCTAssertEqual(reconnected.modes, [.super])
        XCTAssertEqual(coordinator.activeDeviceKeys, Set([1, 2]))
    }

    func testStopSendsCodexBeforeCancellingObserverAndTimer() {
        var trace: [String] = []
        let record: (String) -> Void = { trace.append($0) }
        let observer = ForegroundObserverStub(
            frontmostBundleIdentifier: WorkspaceModeCoordinator.targetBundleIdentifier,
            trace: record
        )
        let scheduler = SchedulerStub(trace: record)
        let coordinator = WorkspaceModeCoordinator(
            foregroundObserver: observer,
            scheduler: scheduler,
            uptime: { 0 },
            log: { _ in }
        )
        coordinator.start()
        coordinator.attach(WorkspaceSenderStub(deviceKey: 1, trace: record))
        trace.removeAll()

        coordinator.stop()

        XCTAssertEqual(trace, ["send:codex", "timer:cancel", "observer:stop"])
        XCTAssertTrue(coordinator.activeDeviceKeys.isEmpty)
        XCTAssertEqual(observer.stopCount, 1)
    }

    func testWriteFailureLogsAtMostOncePerSixtySecondsAndKeepsRetrying() {
        var now: TimeInterval = 0
        var logs: [String] = []
        let observer = ForegroundObserverStub(
            frontmostBundleIdentifier: WorkspaceModeCoordinator.targetBundleIdentifier
        )
        let scheduler = SchedulerStub()
        let coordinator = WorkspaceModeCoordinator(
            foregroundObserver: observer,
            scheduler: scheduler,
            uptime: { now },
            log: { logs.append($0) }
        )
        coordinator.start()
        let sender = WorkspaceSenderStub(deviceKey: 1)
        sender.results = [false, false, false, false]

        coordinator.attach(sender)
        now = 10
        scheduler.tasks[0].fire()
        now = 59.9
        scheduler.tasks[0].fire()
        now = 60
        scheduler.tasks[0].fire()

        XCTAssertEqual(sender.modes, [.super, .super, .super, .super])
        XCTAssertEqual(logs.count, 2)
        XCTAssertTrue(logs.allSatisfy { !$0.contains("host.workspace_mode") && !$0.contains("deviceKey") })
    }

    func testOnlyExactBundleIdentifierEntersSuperMode() {
        let observer = ForegroundObserverStub(
            frontmostBundleIdentifier: "com.zarifpour.superconductor.beta"
        )
        let scheduler = SchedulerStub()
        let coordinator = WorkspaceModeCoordinator(
            foregroundObserver: observer,
            scheduler: scheduler,
            uptime: { 0 },
            log: { _ in }
        )
        coordinator.start()
        let sender = WorkspaceSenderStub(deviceKey: 1)
        coordinator.attach(sender)
        observer.activate(WorkspaceModeCoordinator.targetBundleIdentifier)

        XCTAssertEqual(sender.modes, [.codex, .super])
        XCTAssertEqual(scheduler.intervals, [5])
    }
}
