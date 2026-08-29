import AppKit
import Carbon
import CoreGraphics
import Foundation

struct ProcessKeyStroke: Equatable {
    let keyCode: CGKeyCode
    let keyDown: Bool
    let flags: CGEventFlags
}

@MainActor
protocol ProcessKeySequencePosting: AnyObject {
    func post(_ strokes: [ProcessKeyStroke], to processIdentifier: pid_t) -> Bool
}

@MainActor
protocol ProcessTargetedKeyEmitting: AnyObject {
    func emit(
        _ command: SuperEngineeringNavigationCommand,
        to identity: ApplicationIdentity
    ) -> Bool
}

@MainActor
final class CoreGraphicsProcessKeySequencePoster: ProcessKeySequencePosting {
    func post(_ strokes: [ProcessKeyStroke], to processIdentifier: pid_t) -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        var events: [CGEvent] = []
        events.reserveCapacity(strokes.count)
        for stroke in strokes {
            guard let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: stroke.keyCode,
                keyDown: stroke.keyDown
            ) else { return false }
            event.flags = stroke.flags
            events.append(event)
        }
        for event in events {
            event.postToPid(processIdentifier)
        }
        return true
    }
}

@MainActor
final class SystemProcessTargetedKeyEmitter: ProcessTargetedKeyEmitting {
    typealias FrontmostIdentity = () -> ApplicationIdentity?
    typealias IdentityForProcess = (pid_t) -> ApplicationIdentity?

    private let frontmostIdentity: FrontmostIdentity
    private let identityForProcess: IdentityForProcess
    private let poster: ProcessKeySequencePosting

    convenience init() {
        self.init(
            frontmostIdentity: {
                Self.identity(for: NSWorkspace.shared.frontmostApplication)
            },
            identityForProcess: { processIdentifier in
                Self.identity(for: NSRunningApplication(processIdentifier: processIdentifier))
            },
            poster: CoreGraphicsProcessKeySequencePoster()
        )
    }

    init(
        frontmostIdentity: @escaping FrontmostIdentity,
        identityForProcess: @escaping IdentityForProcess,
        poster: ProcessKeySequencePosting
    ) {
        self.frontmostIdentity = frontmostIdentity
        self.identityForProcess = identityForProcess
        self.poster = poster
    }

    func emit(
        _ command: SuperEngineeringNavigationCommand,
        to identity: ApplicationIdentity
    ) -> Bool {
        guard identity.bundleIdentifier == SuperEngineeringToggler.targetBundleIdentifier,
              frontmostIdentity() == identity,
              identityForProcess(identity.processIdentifier) == identity else { return false }

        let keyCode: CGKeyCode
        switch command {
        case .previousProject:
            keyCode = CGKeyCode(kVK_UpArrow)
        case .nextProject:
            keyCode = CGKeyCode(kVK_DownArrow)
        case .nextTab:
            keyCode = CGKeyCode(kVK_RightArrow)
        }
        let flags: CGEventFlags = [.maskControl, .maskAlternate]
        return poster.post(
            [
                ProcessKeyStroke(keyCode: keyCode, keyDown: true, flags: flags),
                ProcessKeyStroke(keyCode: keyCode, keyDown: false, flags: flags),
            ],
            to: identity.processIdentifier
        )
    }

    private static func identity(for application: NSRunningApplication?) -> ApplicationIdentity? {
        guard let application,
              let bundleIdentifier = application.bundleIdentifier,
              !application.isTerminated else { return nil }
        return ApplicationIdentity(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: bundleIdentifier
        )
    }
}
