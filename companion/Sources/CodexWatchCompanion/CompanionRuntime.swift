import Foundation

enum AppServerWaitState: Equatable {
    case waiting
    case responseAvailable
    case processExited
    case timedOut
}

func waitForAppServerState(
    condition: NSCondition,
    deadline: Date,
    step: TimeInterval = 0.025,
    state: () -> AppServerWaitState
) -> AppServerWaitState {
    precondition(step > 0)

    while true {
        condition.lock()
        let currentState = state()
        condition.unlock()
        if currentState != .waiting { return currentState }

        let now = Date()
        guard now < deadline else { return .timedOut }
        let stepDeadline = min(deadline, now.addingTimeInterval(step))

        if Thread.isMainThread {
            _ = RunLoop.current.run(mode: .default, before: stepDeadline)
        }

        condition.lock()
        var nextState = state()
        if nextState == .waiting, Date() < stepDeadline {
            condition.wait(until: stepDeadline)
            nextState = state()
        }
        condition.unlock()

        if nextState != .waiting { return nextState }
    }
}

func runQuotaLoop(
    watch: Bool,
    interval: TimeInterval,
    cycle: () throws -> Void,
    wait: (TimeInterval) -> Void,
    reportError: (Error) -> Void,
    shouldContinue: () -> Bool = { true }
) throws {
    while true {
        do {
            try cycle()
        } catch {
            guard watch else { throw error }
            reportError(error)
        }
        guard watch, shouldContinue() else { return }
        wait(interval)
    }
}
