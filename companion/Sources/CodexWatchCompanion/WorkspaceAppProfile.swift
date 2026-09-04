import Foundation

enum WorkspaceAppProfile: CaseIterable {
    case codex, `super`, hermes

    var bundleIdentifier: String {
        switch self {
        case .codex: return "com.openai.codex"
        case .super: return "com.zarifpour.superconductor"
        case .hermes: return "com.nousresearch.hermes"
        }
    }

    init?(bundleIdentifier: String?) {
        guard let profile = Self.allCases.first(where: { $0.bundleIdentifier == bundleIdentifier }) else { return nil }
        self = profile
    }

    var next: Self {
        switch self {
        case .codex: return .super
        case .super: return .hermes
        case .hermes: return .codex
        }
    }

    func command(for event: CompanionShortcutEvent) -> WorkspaceNavigationCommand? {
        switch (self, event) {
        case (.super, .up): return .previousProject
        case (.super, .down): return .nextProject
        case (.super, .right): return .nextTab
        case (.hermes, .up): return .previousHermesTab
        case (.hermes, .down): return .nextHermesTab
        case (.hermes, .right): return .newHermesTab
        default: return nil
        }
    }
}

enum WorkspaceNavigationCommand: Equatable {
    case previousProject, nextProject, nextTab
    case previousHermesTab, nextHermesTab, newHermesTab

    var profile: WorkspaceAppProfile {
        switch self {
        case .previousProject, .nextProject, .nextTab: return .super
        case .previousHermesTab, .nextHermesTab, .newHermesTab: return .hermes
        }
    }
}
