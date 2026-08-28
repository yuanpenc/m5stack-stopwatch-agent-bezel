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
