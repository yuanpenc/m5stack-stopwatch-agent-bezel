import Foundation

enum SuperEngineeringNavigationCommand: Equatable {
    case previousProject
    case nextProject
    case nextTab
}

enum CompanionShortcutEvent: Equatable {
    case toggleSuperEngineering
    case navigateSuperEngineering(SuperEngineeringNavigationCommand)
}

enum StopwatchHIDDescriptor {
    static let vendorID = 0x303A
    static let productID = 0x8360
    static let usagePage = 0xFF00
    static let usage = 1
    static let reportID = 6
    static let reportBodyByteCount = 63
}

struct HIDShortcutDecoder {
    private static let fragmentMarker: UInt8 = 0x02
    private static let maximumMessageBytes = 4_096
    private static let directionTolerance = 0.05
    private static let distanceTolerance = 0.05
    private static let cooldown: TimeInterval = 0.8

    private struct Message: Decodable {
        struct Parameters: Decodable {
            let a: Double
            let d: Double
        }
        let method: String
        let params: Parameters
    }

    private var receiveBuffer: [UInt8] = []
    private var armed = true
    private var lastAcceptedAt: TimeInterval?

    mutating func consume(reportID: Int, bytes: [UInt8], now: TimeInterval) -> [CompanionShortcutEvent] {
        guard reportID == StopwatchHIDDescriptor.reportID else { return [] }
        // On the physical C152, macOS supplies the report ID both as the
        // callback argument and as the first byte of the 64-byte raw report.
        let body = bytes.count == StopwatchHIDDescriptor.reportBodyByteCount + 1
            && bytes.first == UInt8(reportID)
            ? Array(bytes.dropFirst())
            : bytes
        guard body.count >= 2, body[0] == Self.fragmentMarker else {
            receiveBuffer.removeAll(keepingCapacity: true)
            return []
        }
        let length = Int(body[1])
        guard length <= body.count - 2 else {
            receiveBuffer.removeAll(keepingCapacity: true)
            return []
        }
        receiveBuffer.append(contentsOf: body[2 ..< 2 + length])
        guard receiveBuffer.count <= Self.maximumMessageBytes else {
            receiveBuffer.removeAll(keepingCapacity: true)
            return []
        }

        var events: [CompanionShortcutEvent] = []
        while let newline = receiveBuffer.firstIndex(of: 0x0A) {
            let line = Data(receiveBuffer[..<newline])
            receiveBuffer.removeSubrange(...newline)
            guard let message = try? JSONDecoder().decode(Message.self, from: line),
                  let event = recognize(message, now: now) else { continue }
            events.append(event)
        }
        return events
    }

    mutating func reset() {
        receiveBuffer.removeAll(keepingCapacity: true)
        armed = true
        lastAcceptedAt = nil
    }

    private mutating func recognize(_ message: Message, now: TimeInterval) -> CompanionShortcutEvent? {
        guard message.method == "v.oai.rad",
              message.params.a.isFinite,
              message.params.d.isFinite,
              let event = event(for: message.params.a) else { return nil }
        if abs(message.params.d) <= Self.distanceTolerance {
            armed = true
            return nil
        }
        guard abs(message.params.d - 1.0) <= Self.distanceTolerance, armed else { return nil }
        armed = false
        guard lastAcceptedAt.map({ now - $0 >= Self.cooldown }) ?? true else { return nil }
        lastAcceptedAt = now
        return event
    }

    private func event(for angle: Double) -> CompanionShortcutEvent? {
        let candidates: [(Double, CompanionShortcutEvent)] = [
            (0.00, .navigateSuperEngineering(.nextTab)),
            (0.25, .navigateSuperEngineering(.nextProject)),
            (0.50, .toggleSuperEngineering),
            (0.75, .navigateSuperEngineering(.previousProject)),
        ]
        return candidates.first { abs(angle - $0.0) <= Self.directionTolerance }?.1
    }
}
