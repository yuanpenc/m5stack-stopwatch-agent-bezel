import XCTest
@testable import CodexWatchCompanion

@MainActor
private final class TogglerSpy: SuperEngineeringToggling {
    var toggleCount = 0

    func toggle() {
        toggleCount += 1
    }
}

@MainActor
private final class EmitterSpy: ProcessTargetedKeyEmitting {
    struct Call: Equatable {
        let command: SuperEngineeringNavigationCommand
        let identity: ApplicationIdentity
    }

    var calls: [Call] = []
    var result = true

    func emit(
        _ command: SuperEngineeringNavigationCommand,
        to identity: ApplicationIdentity
    ) -> Bool {
        calls.append(Call(command: command, identity: identity))
        return result
    }
}

private struct AccessibilityTrustStub: AccessibilityTrustChecking {
    let isTrusted: Bool
}

private final class RouterLogRecorder {
    var messages: [String] = []
}

@MainActor
final class SuperEngineeringCommandRouterTests: XCTestCase {
    private let chatGPT = ApplicationIdentity(processIdentifier: 101, bundleIdentifier: "com.openai.chat")
    private let superApp = ApplicationIdentity(
        processIdentifier: 202,
        bundleIdentifier: "com.zarifpour.superconductor"
    )

    func testLeftAlwaysReachesTogglerWithoutAccessibility() {
        let fixture = makeFixture(frontmost: chatGPT, trusted: false)

        fixture.router.handle(.toggleSuperEngineering)

        XCTAssertEqual(fixture.toggler.toggleCount, 1)
        XCTAssertTrue(fixture.emitter.calls.isEmpty)
        XCTAssertTrue(fixture.logs.messages.isEmpty)
    }

    func testNavigationIsSilentOutsideForegroundSuperEngineering() {
        let fixture = makeFixture(frontmost: chatGPT, trusted: true)

        fixture.router.handle(.navigateSuperEngineering(.nextProject))

        XCTAssertEqual(fixture.toggler.toggleCount, 0)
        XCTAssertTrue(fixture.emitter.calls.isEmpty)
        XCTAssertTrue(fixture.logs.messages.isEmpty)
    }

    func testNavigationUsesExactForegroundIdentityForEveryCommand() {
        let fixture = makeFixture(frontmost: superApp, trusted: true)

        fixture.router.handle(.navigateSuperEngineering(.previousProject))
        fixture.router.handle(.navigateSuperEngineering(.nextProject))
        fixture.router.handle(.navigateSuperEngineering(.nextTab))

        XCTAssertEqual(fixture.emitter.calls, [
            .init(command: .previousProject, identity: superApp),
            .init(command: .nextProject, identity: superApp),
            .init(command: .nextTab, identity: superApp),
        ])
        XCTAssertEqual(fixture.toggler.toggleCount, 0)
    }

    func testAccessibilityWarningOccursOnceAndLeftStillWorks() {
        let fixture = makeFixture(frontmost: superApp, trusted: false)

        fixture.router.handle(.navigateSuperEngineering(.previousProject))
        fixture.router.handle(.navigateSuperEngineering(.nextProject))
        fixture.router.handle(.toggleSuperEngineering)

        XCTAssertTrue(fixture.emitter.calls.isEmpty)
        XCTAssertEqual(fixture.toggler.toggleCount, 1)
        XCTAssertEqual(fixture.logs.messages.filter { $0.contains("辅助功能") }.count, 1)
    }

    func testDeliveryFailureIsGenericAndDoesNotToggle() {
        let fixture = makeFixture(frontmost: superApp, trusted: true)
        fixture.emitter.result = false

        fixture.router.handle(.navigateSuperEngineering(.nextTab))

        XCTAssertEqual(fixture.emitter.calls, [.init(command: .nextTab, identity: superApp)])
        XCTAssertEqual(fixture.toggler.toggleCount, 0)
        XCTAssertEqual(fixture.logs.messages, ["super.engineering 导航按键发送失败"])
    }

    private func makeFixture(
        frontmost: ApplicationIdentity,
        trusted: Bool
    ) -> (
        router: SuperEngineeringCommandRouter,
        toggler: TogglerSpy,
        emitter: EmitterSpy,
        logs: RouterLogRecorder
    ) {
        let workspace = WorkspaceStub()
        workspace.frontmost = frontmost
        let toggler = TogglerSpy()
        let emitter = EmitterSpy()
        let logs = RouterLogRecorder()
        let router = SuperEngineeringCommandRouter(
            workspace: workspace,
            toggler: toggler,
            emitter: emitter,
            accessibility: AccessibilityTrustStub(isTrusted: trusted),
            log: { logs.messages.append($0) }
        )
        return (router, toggler, emitter, logs)
    }
}
