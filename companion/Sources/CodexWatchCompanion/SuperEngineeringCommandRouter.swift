import ApplicationServices
import Foundation

protocol AccessibilityTrustChecking {
    var isTrusted: Bool { get }
}

struct SystemAccessibilityTrustChecker: AccessibilityTrustChecking {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }
}

@MainActor
final class SuperEngineeringCommandRouter {
    private let workspace: WorkspaceApplications
    private let toggler: SuperEngineeringToggling
    private let emitter: ProcessTargetedKeyEmitting
    private let accessibility: AccessibilityTrustChecking
    private let log: (String) -> Void
    private var didWarnAboutAccessibility = false

    init(
        workspace: WorkspaceApplications,
        toggler: SuperEngineeringToggling,
        emitter: ProcessTargetedKeyEmitting,
        accessibility: AccessibilityTrustChecking,
        log: @escaping (String) -> Void
    ) {
        self.workspace = workspace
        self.toggler = toggler
        self.emitter = emitter
        self.accessibility = accessibility
        self.log = log
    }

    func handle(_ event: CompanionShortcutEvent) {
        switch event {
        case .toggleSuperEngineering:
            toggler.toggle()
        case .navigateSuperEngineering(let command):
            guard let target = workspace.frontmost,
                  target.bundleIdentifier == SuperEngineeringToggler.targetBundleIdentifier else {
                return
            }
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
