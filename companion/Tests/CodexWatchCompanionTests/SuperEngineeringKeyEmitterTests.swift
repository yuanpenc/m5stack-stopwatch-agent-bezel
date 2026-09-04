import Carbon
import CoreGraphics
import XCTest
@testable import CodexWatchCompanion

@MainActor
private final class SequencePosterStub: ProcessKeySequencePosting {
    struct Delivery: Equatable {
        let strokes: [ProcessKeyStroke]
        let processIdentifier: pid_t
    }

    var deliveries: [Delivery] = []
    var result = true

    func post(_ strokes: [ProcessKeyStroke], to processIdentifier: pid_t) -> Bool {
        deliveries.append(Delivery(strokes: strokes, processIdentifier: processIdentifier))
        return result
    }
}

@MainActor
final class SuperEngineeringKeyEmitterTests: XCTestCase {
    private let target = ApplicationIdentity(
        processIdentifier: 202,
        bundleIdentifier: "com.zarifpour.superconductor"
    )
    private let modifiers: CGEventFlags = [.maskControl, .maskAlternate]

    func testCommandsProduceFixedArrowDownUpPairsForExactPID() {
        let cases: [(WorkspaceNavigationCommand, CGKeyCode)] = [
            (.previousProject, CGKeyCode(kVK_UpArrow)),
            (.nextProject, CGKeyCode(kVK_DownArrow)),
            (.nextTab, CGKeyCode(kVK_RightArrow)),
        ]

        for (command, expectedKeyCode) in cases {
            let poster = SequencePosterStub()
            let emitter = SystemProcessTargetedKeyEmitter(
                frontmostIdentity: { self.target },
                identityForProcess: { _ in self.target },
                poster: poster
            )

            XCTAssertTrue(emitter.emit(command, to: target))
            XCTAssertEqual(poster.deliveries, [
                .init(
                    strokes: [
                        ProcessKeyStroke(keyCode: expectedKeyCode, keyDown: true, flags: modifiers),
                        ProcessKeyStroke(keyCode: expectedKeyCode, keyDown: false, flags: modifiers),
                    ],
                    processIdentifier: target.processIdentifier
                ),
            ])
        }
    }

    func testHermesPreservesTabBrowsingAndConfirmsWithControlRelease() {
        let hermes = ApplicationIdentity(processIdentifier: 303, bundleIdentifier: "com.nousresearch.hermes")
        let cases: [(WorkspaceNavigationCommand, CGKeyCode, CGEventFlags, CGEventFlags)] = [
            (.previousHermesTab, 48, [.maskControl, .maskShift], [.maskControl, .maskShift]),
            (.nextHermesTab, 48, [.maskControl], [.maskControl]),
            (.confirmHermesSelection, 59, [.maskControl], []),
        ]
        for (command, key, downFlags, upFlags) in cases {
            let poster = SequencePosterStub()
            let emitter = SystemProcessTargetedKeyEmitter(frontmostIdentity: { hermes }, identityForProcess: { _ in hermes }, poster: poster)
            XCTAssertTrue(emitter.emit(command, to: hermes))
            XCTAssertEqual(poster.deliveries, [.init(strokes: [
                ProcessKeyStroke(keyCode: key, keyDown: true, flags: downFlags),
                ProcessKeyStroke(keyCode: key, keyDown: false, flags: upFlags)
            ], processIdentifier: 303)])
            XCTAssertFalse(emitter.emit(.nextProject, to: hermes))
            XCTAssertEqual(poster.deliveries.count, 1)
        }
        let poster = SequencePosterStub()
        let emitter = SystemProcessTargetedKeyEmitter(frontmostIdentity: { self.target }, identityForProcess: { _ in self.target }, poster: poster)
        XCTAssertFalse(emitter.emit(.confirmHermesSelection, to: target))
        XCTAssertTrue(poster.deliveries.isEmpty)
    }

    func testExitedTargetPostsNothing() {
        let poster = SequencePosterStub()
        let emitter = SystemProcessTargetedKeyEmitter(
            frontmostIdentity: { self.target },
            identityForProcess: { _ in nil },
            poster: poster
        )

        XCTAssertFalse(emitter.emit(.nextTab, to: target))
        XCTAssertTrue(poster.deliveries.isEmpty)
    }

    func testReusedPIDWithDifferentBundlePostsNothing() {
        let poster = SequencePosterStub()
        let reused = ApplicationIdentity(
            processIdentifier: target.processIdentifier,
            bundleIdentifier: "com.example.reused"
        )
        let emitter = SystemProcessTargetedKeyEmitter(
            frontmostIdentity: { self.target },
            identityForProcess: { _ in reused },
            poster: poster
        )

        XCTAssertFalse(emitter.emit(.nextProject, to: target))
        XCTAssertTrue(poster.deliveries.isEmpty)
    }

    func testTargetThatLostForegroundPostsNothing() {
        let poster = SequencePosterStub()
        let chatGPT = ApplicationIdentity(processIdentifier: 101, bundleIdentifier: "com.openai.chat")
        let emitter = SystemProcessTargetedKeyEmitter(
            frontmostIdentity: { chatGPT },
            identityForProcess: { _ in self.target },
            poster: poster
        )

        XCTAssertFalse(emitter.emit(.previousProject, to: target))
        XCTAssertTrue(poster.deliveries.isEmpty)
    }

    func testNonSuperEngineeringIdentityPostsNothing() {
        let poster = SequencePosterStub()
        let other = ApplicationIdentity(processIdentifier: 404, bundleIdentifier: "com.example.other")
        let emitter = SystemProcessTargetedKeyEmitter(
            frontmostIdentity: { other },
            identityForProcess: { _ in other },
            poster: poster
        )

        XCTAssertFalse(emitter.emit(.nextTab, to: other))
        XCTAssertTrue(poster.deliveries.isEmpty)
    }
}
