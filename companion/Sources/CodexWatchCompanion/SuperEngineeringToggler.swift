import AppKit
import Foundation

struct ApplicationIdentity: Equatable, Hashable {
    let processIdentifier: pid_t
    let bundleIdentifier: String
}

@MainActor
protocol WorkspaceApplications: AnyObject {
    var frontmost: ApplicationIdentity? { get }
    func runningApplication(bundleIdentifier: String) -> ApplicationIdentity?
    @discardableResult func activate(_ identity: ApplicationIdentity) -> Bool
    func launchAndActivate(bundleIdentifier: String, completion: @MainActor @escaping (Bool) -> Void)
}

@MainActor
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
        return application.activate(options: [])
    }

    func launchAndActivate(bundleIdentifier: String, completion: @MainActor @escaping (Bool) -> Void) {
        guard let url = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            completion(false)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        workspace.openApplication(at: url, configuration: configuration) { application, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    completion(application?.bundleIdentifier == bundleIdentifier)
                }
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

@MainActor
protocol SuperEngineeringToggling: AnyObject {
    func toggle()
}

@MainActor
final class SuperEngineeringToggler: SuperEngineeringToggling {
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
