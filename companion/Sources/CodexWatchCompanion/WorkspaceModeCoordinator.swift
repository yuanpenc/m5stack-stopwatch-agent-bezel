import AppKit
import Foundation

@MainActor
protocol ForegroundApplicationObserving: AnyObject {
    var frontmostBundleIdentifier: String? { get }
    func start(_ handler: @MainActor @escaping (String?) -> Void)
    func stop()
}

@MainActor
final class SystemForegroundApplicationObserver: ForegroundApplicationObserving {
    private let workspace: NSWorkspace
    private var observation: NSObjectProtocol?

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    var frontmostBundleIdentifier: String? {
        workspace.frontmostApplication?.bundleIdentifier
    }

    func start(_ handler: @MainActor @escaping (String?) -> Void) {
        stop()
        observation = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
            MainActor.assumeIsolated {
                handler(application?.bundleIdentifier)
            }
        }
    }

    func stop() {
        guard let observation else { return }
        workspace.notificationCenter.removeObserver(observation)
        self.observation = nil
    }

    deinit {
        if let observation {
            workspace.notificationCenter.removeObserver(observation)
        }
    }
}

@MainActor
protocol WorkspaceModeScheduledTask: AnyObject {
    func cancel()
}

@MainActor
protocol WorkspaceModeScheduling: AnyObject {
    func scheduleRepeating(
        every interval: TimeInterval,
        _ handler: @MainActor @escaping () -> Void
    ) -> WorkspaceModeScheduledTask
}

@MainActor
private final class SystemWorkspaceModeScheduledTask: WorkspaceModeScheduledTask {
    private var timer: Timer?

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        timer?.invalidate()
    }
}

@MainActor
final class SystemWorkspaceModeScheduler: WorkspaceModeScheduling {
    func scheduleRepeating(
        every interval: TimeInterval,
        _ handler: @MainActor @escaping () -> Void
    ) -> WorkspaceModeScheduledTask {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated {
                handler()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        return SystemWorkspaceModeScheduledTask(timer: timer)
    }
}

@MainActor
final class WorkspaceModeCoordinator {
    static let targetBundleIdentifier = "com.zarifpour.superconductor"
    static let heartbeatInterval: TimeInterval = 5
    static let failureLogInterval: TimeInterval = 60

    private let foregroundObserver: ForegroundApplicationObserving
    private let scheduler: WorkspaceModeScheduling
    private let uptime: () -> TimeInterval
    private let log: (String) -> Void
    private var sendersByDevice: [UInt: WorkspaceModeSending] = [:]
    private var heartbeat: WorkspaceModeScheduledTask?
    private var desiredMode = StopwatchWorkspaceMode.codex
    private var lastFailureLogAt: TimeInterval?
    private var started = false

    init(
        foregroundObserver: ForegroundApplicationObserving,
        scheduler: WorkspaceModeScheduling,
        uptime: @escaping () -> TimeInterval,
        log: @escaping (String) -> Void
    ) {
        self.foregroundObserver = foregroundObserver
        self.scheduler = scheduler
        self.uptime = uptime
        self.log = log
    }

    convenience init(log: @escaping (String) -> Void) {
        self.init(
            foregroundObserver: SystemForegroundApplicationObserver(),
            scheduler: SystemWorkspaceModeScheduler(),
            uptime: { ProcessInfo.processInfo.systemUptime },
            log: log
        )
    }

    var activeDeviceKeys: Set<UInt> {
        Set(sendersByDevice.keys)
    }

    func start() {
        guard !started else { return }
        started = true
        foregroundObserver.start { [weak self] bundleIdentifier in
            self?.foregroundApplicationChanged(bundleIdentifier)
        }
        transition(to: mode(for: foregroundObserver.frontmostBundleIdentifier))
    }

    func attach(_ sender: WorkspaceModeSending) {
        sendersByDevice[sender.deviceKey] = sender
        send(desiredMode, to: sender)
    }

    func detach(deviceKey: UInt) {
        sendersByDevice.removeValue(forKey: deviceKey)
    }

    func stop() {
        sendToAll(.codex)
        heartbeat?.cancel()
        heartbeat = nil
        if started {
            foregroundObserver.stop()
        }
        sendersByDevice.removeAll()
        desiredMode = .codex
        started = false
    }

    private func foregroundApplicationChanged(_ bundleIdentifier: String?) {
        guard started else { return }
        transition(to: mode(for: bundleIdentifier))
    }

    private func mode(for bundleIdentifier: String?) -> StopwatchWorkspaceMode {
        bundleIdentifier == Self.targetBundleIdentifier ? .super : .codex
    }

    private func transition(to mode: StopwatchWorkspaceMode) {
        guard mode != desiredMode else {
            if mode == .super {
                startHeartbeatIfNeeded()
            }
            return
        }

        desiredMode = mode
        sendToAll(mode)
        if mode == .super {
            startHeartbeatIfNeeded()
        } else {
            heartbeat?.cancel()
            heartbeat = nil
        }
    }

    private func startHeartbeatIfNeeded() {
        guard heartbeat == nil else { return }
        heartbeat = scheduler.scheduleRepeating(every: Self.heartbeatInterval) { [weak self] in
            guard let self, self.started, self.desiredMode == .super else { return }
            self.sendToAll(.super)
        }
    }

    private func sendToAll(_ mode: StopwatchWorkspaceMode) {
        for deviceKey in sendersByDevice.keys.sorted() {
            guard let sender = sendersByDevice[deviceKey] else { continue }
            send(mode, to: sender)
        }
    }

    private func send(_ mode: StopwatchWorkspaceMode, to sender: WorkspaceModeSending) {
        guard !sender.send(mode) else { return }

        let now = uptime()
        if let lastFailureLogAt,
           now - lastFailureLogAt < Self.failureLogInterval {
            return
        }
        lastFailureLogAt = now
        log("StopWatch 屏幕模式同步失败；将在后续心跳重试")
    }
}
