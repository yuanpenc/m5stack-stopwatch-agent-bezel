import XCTest
@testable import CodexWatchCompanion

final class CompanionRuntimeTests: XCTestCase {
    @MainActor
    func testAppServerWaitPumpsMainRunLoopBeforeResponse() {
        let condition = NSCondition()
        var events: [String] = []
        var responseReady = false

        RunLoop.current.perform(inModes: [.default]) {
            condition.lock()
            events.append("callback")
            condition.unlock()
        }
        RunLoop.current.perform(inModes: [.default]) {
            condition.lock()
            events.append("response")
            responseReady = true
            condition.broadcast()
            condition.unlock()
        }

        let outcome = waitForAppServerState(
            condition: condition,
            deadline: Date().addingTimeInterval(0.5),
            state: { responseReady ? .responseAvailable : .waiting }
        )

        XCTAssertEqual(outcome, .responseAvailable)
        XCTAssertEqual(events, ["callback", "response"])
    }

    func testOnlyRealWatchModeStartsHIDListener() throws {
        let realWatch = try parseOptions(["companion", "--watch", "--device-id", "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"])
        let demoWatch = try parseOptions(["companion", "--watch", "--demo"])
        let jsonOnly = try parseOptions(["companion", "--json-only"])
        let oneShot = try parseOptions(["companion"])
        let bootloader = try parseOptions(["companion", "--enter-bootloader", "--device-id", "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"])

        XCTAssertTrue(realWatch.startsHIDShortcutListener)
        XCTAssertTrue(realWatch.startsWorkspaceModeCoordinator)
        for options in [demoWatch, jsonOnly, oneShot, bootloader] {
            XCTAssertFalse(options.startsHIDShortcutListener)
            XCTAssertFalse(options.startsWorkspaceModeCoordinator)
        }
    }

    func testWatchLoopReportsFailureThenRunsNextCycle() throws {
        struct ExpectedFailure: Error {}
        var cycles = 0
        var waits: [TimeInterval] = []
        var reportedErrors = 0
        try runQuotaLoop(
            watch: true,
            interval: 60,
            cycle: {
                cycles += 1
                if cycles == 1 { throw ExpectedFailure() }
            },
            wait: { waits.append($0) },
            reportError: { _ in reportedErrors += 1 },
            shouldContinue: { cycles < 2 }
        )
        XCTAssertEqual(cycles, 2)
        XCTAssertEqual(waits, [60])
        XCTAssertEqual(reportedErrors, 1)
    }

    func testOneShotLoopRethrowsImmediately() {
        struct ExpectedFailure: Error {}
        XCTAssertThrowsError(try runQuotaLoop(
            watch: false,
            interval: 60,
            cycle: { throw ExpectedFailure() },
            wait: { _ in XCTFail("one-shot mode must not wait") },
            reportError: { _ in XCTFail("one-shot mode must not absorb errors") },
            shouldContinue: { true }
        ))
    }
}
