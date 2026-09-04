import Foundation

@MainActor
protocol WorkspaceCycling: AnyObject {
    func cycle()
}

@MainActor
final class WorkspaceCycleController: WorkspaceCycling {
    private let workspace: WorkspaceApplications
    private let observer: ForegroundApplicationObserving
    private let scheduler: WorkspaceModeScheduling
    private let log: (String) -> Void
    private var started = false
    private var generation: UInt64 = 0
    private var lifecycleGeneration: UInt64 = 0
    private var pending: (generation: UInt64, origin: String?, target: String)?
    private var timeout: WorkspaceModeScheduledTask?

    init(workspace: WorkspaceApplications,
         observer: ForegroundApplicationObserving,
         scheduler: WorkspaceModeScheduling,
         log: @escaping (String) -> Void) {
        self.workspace = workspace
        self.observer = observer
        self.scheduler = scheduler
        self.log = log
    }

    func start() {
        guard !started else { return }
        started = true
        lifecycleGeneration &+= 1
        let lifecycle = lifecycleGeneration
        observer.start { [weak self] bundle in
            guard let self, self.started, self.lifecycleGeneration == lifecycle else { return }
            self.foregroundChanged(bundle)
        }
    }

    func stop() {
        started = false
        lifecycleGeneration &+= 1
        generation &+= 1
        clearPending()
        observer.stop()
    }

    func cycle() {
        guard started, pending == nil else { return }
        let origin = workspace.frontmost?.bundleIdentifier
        let target = (WorkspaceAppProfile(bundleIdentifier: origin)?.next ?? .codex).bundleIdentifier
        generation &+= 1
        let request = generation
        pending = (request, origin, target)
        timeout = scheduler.scheduleRepeating(every: 3) { [weak self] in
            guard let self, self.started, self.pending?.generation == request else { return }
            self.clearPending()
            self.log("桌面切换等待超时；保持真实前台")
        }
        if let identity = workspace.runningApplication(bundleIdentifier: target) {
            completeRequest(request, accepted: workspace.activate(identity))
        } else {
            workspace.launchAndActivate(bundleIdentifier: target) { [weak self] accepted in
                self?.completeRequest(request, accepted: accepted)
            }
        }
    }

    private func completeRequest(_ request: UInt64, accepted: Bool) {
        guard started, pending?.generation == request else { return }
        if !accepted {
            clearPending()
            log("找不到或无法激活目标桌面应用")
        } else {
            // Successful submission alone is not proof of a foreground change.
            foregroundChanged(workspace.frontmost?.bundleIdentifier)
        }
    }

    private func foregroundChanged(_ bundle: String?) {
        guard let pending else { return }
        if bundle == pending.target || bundle != pending.origin { clearPending() }
    }

    private func clearPending() {
        timeout?.cancel()
        timeout = nil
        pending = nil
    }
}
