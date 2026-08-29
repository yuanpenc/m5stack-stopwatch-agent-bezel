import XCTest
import IOKit.hid
@testable import CodexWatchCompanion

@MainActor
final class HIDShortcutDecoderTests: XCTestCase {
    func testInvalidatedCallbackContextIgnoresDelayedDelivery() {
        var delivered: [HIDShortcutCallbackAction] = []
        let session = HIDShortcutCallbackSession { delivered.append($0) }
        let context = HIDShortcutCallbackRegistry.retain(session)
        let delayedSession = HIDShortcutCallbackRegistry.session(for: context)

        session.deliver(.matched(deviceKey: 1))
        XCTAssertEqual(delivered, [.matched(deviceKey: 1)])

        HIDShortcutCallbackRegistry.invalidate(context)
        delayedSession?.deliver(.removed(deviceKey: 1))

        XCTAssertEqual(delivered, [.matched(deviceKey: 1)])
        XCTAssertNil(HIDShortcutCallbackRegistry.session(for: context))
    }

    func testMatchingDictionaryContainsOnlyExpectedDeviceIdentity() {
        XCTAssertEqual(HIDShortcutListener.matching.count, 4)
        XCTAssertEqual(HIDShortcutListener.matching[kIOHIDVendorIDKey as String] as? Int, 0x303A)
        XCTAssertEqual(HIDShortcutListener.matching[kIOHIDProductIDKey as String] as? Int, 0x8360)
        XCTAssertEqual(HIDShortcutListener.matching[kIOHIDPrimaryUsagePageKey as String] as? Int, 0xFF00)
        XCTAssertEqual(HIDShortcutListener.matching[kIOHIDPrimaryUsageKey as String] as? Int, 1)
    }

    private func report(_ fragment: String, paddedTo size: Int = 63) -> [UInt8] {
        let payload = Array(fragment.utf8)
        precondition(payload.count <= 61)
        return [0x02, UInt8(payload.count)] + payload
            + Array(repeating: 0, count: max(0, size - payload.count - 2))
    }

    func testFragmentedLeftPressProducesOneToggle() {
        var decoder = HIDShortcutDecoder()
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai."#), now: 10), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"rad","params":{"a":0.5,"d":1.0}}"# + "\n"), now: 10.01), [.toggleSuperEngineering])
    }

    func testReleaseRearmsButCooldownBlocksImmediateSecondPress() {
        var decoder = HIDShortcutDecoder()
        let press = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
        let release = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":0.0}}"# + "\n")
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: press, now: 1), [.toggleSuperEngineering])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: press, now: 1.1), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: release, now: 1.2), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: press, now: 1.3), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: release, now: 1.4), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: press, now: 1.81), [.toggleSuperEngineering])
    }

    func testMalformedFrameClearsBufferAndNextMessageRecovers() {
        var decoder = HIDShortcutDecoder()
        _ = decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai."#), now: 1)
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: [0x02, 60, 0x7B], now: 1.1), [])
        let valid = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: valid, now: 2), [.toggleSuperEngineering])
    }

    func testWrongReportMethodDirectionAndNonFiniteValuesAreIgnored() {
        var decoder = HIDShortcutDecoder()
        let left = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
        XCTAssertEqual(decoder.consume(reportID: 5, bytes: left, now: 1), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"other","params":{"a":0.5,"d":1.0}}"# + "\n"), now: 2), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai.rad","params":{"a":0.0,"d":1.0}}"# + "\n"), now: 3), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai.rad","params":{"a":"NaN","d":1.0}}"# + "\n"), now: 4), [])
    }

    func testOtherReportIDDoesNotDiscardAnInProgressVendorMessage() {
        var decoder = HIDShortcutDecoder()
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"{"method":"v.oai."#), now: 1), [])
        XCTAssertEqual(decoder.consume(reportID: 5, bytes: [0x00], now: 1.1), [])
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(#"rad","params":{"a":0.5,"d":1.0}}"# + "\n"), now: 1.2), [.toggleSuperEngineering])
    }

    func testDescriptorConstantsMatchPhysicalProbe() {
        XCTAssertEqual(StopwatchHIDDescriptor.vendorID, 0x303A)
        XCTAssertEqual(StopwatchHIDDescriptor.productID, 0x8360)
        XCTAssertEqual(StopwatchHIDDescriptor.usagePage, 0xFF00)
        XCTAssertEqual(StopwatchHIDDescriptor.usage, 1)
        XCTAssertEqual(StopwatchHIDDescriptor.reportID, 6)
    }

    func testOversizedBufferIsClearedAndNextMessageRecovers() {
        var decoder = HIDShortcutDecoder()
        for index in 0 ..< 68 {
            XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(String(repeating: "x", count: 61)), now: TimeInterval(index)), [])
        }
        let valid = report(#"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n")
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: valid, now: 100), [.toggleSuperEngineering])
    }

    func testConsumesEveryNewlineInOneFragment() {
        var decoder = HIDShortcutDecoder()
        let payload = "{}\n" + #"{"method":"v.oai.rad","params":{"a":0.5,"d":1.0}}"# + "\n"
        XCTAssertEqual(decoder.consume(reportID: 6, bytes: report(payload), now: 1), [.toggleSuperEngineering])
    }
}
