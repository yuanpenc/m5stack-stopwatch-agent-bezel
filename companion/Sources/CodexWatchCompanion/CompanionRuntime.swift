import Foundation

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
