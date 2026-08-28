import Foundation

enum CompanionShortcutEvent: Equatable {
    case toggleSuperEngineering
}

enum StopwatchHIDDescriptor {
    static let vendorID = 0x303A
    static let productID = 0x8360
    static let usagePage = 0xFF00
    static let usage = 1
    static let reportID = 6
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
        guard bytes.count >= 2, bytes[0] == Self.fragmentMarker else {
            receiveBuffer.removeAll(keepingCapacity: true)
            return []
        }
        let length = Int(bytes[1])
        guard length <= bytes.count - 2 else {
            receiveBuffer.removeAll(keepingCapacity: true)
            return []
        }
        receiveBuffer.append(contentsOf: bytes[2 ..< 2 + length])
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
              abs(message.params.a - 0.5) <= Self.directionTolerance else { return nil }
        if abs(message.params.d) <= Self.distanceTolerance {
            armed = true
            return nil
        }
        guard abs(message.params.d - 1.0) <= Self.distanceTolerance, armed else { return nil }
        guard lastAcceptedAt.map({ now - $0 >= Self.cooldown }) ?? true else { return nil }
        armed = false
        lastAcceptedAt = now
        return .toggleSuperEngineering
    }
}
