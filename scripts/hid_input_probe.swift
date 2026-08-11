#!/usr/bin/env swift

import Foundation
import IOKit.hid

private var reportCount = 0
private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
private let matching: [String: Any] = [
    kIOHIDVendorIDKey as String: 0x303A,
    kIOHIDProductIDKey as String: 0x8360,
    kIOHIDPrimaryUsagePageKey as String: 0xFF00,
    kIOHIDPrimaryUsageKey as String: 1,
]
IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

IOHIDManagerRegisterInputReportCallback(
    manager,
    { _, result, _, reportType, reportID, report, reportLength in
        guard result == kIOReturnSuccess, reportType == kIOHIDReportTypeInput else { return }
        reportCount += 1
        let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
        let prefix = bytes.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ")
        print("input[\(reportCount)] reportID=\(reportID) length=\(reportLength) prefix=\(prefix)")
        fflush(stdout)
    },
    nil
)

IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
guard openResult == kIOReturnSuccess else {
    fatalError(String(format: "IOHIDManagerOpen failed: 0x%08X", openResult))
}

print("Listening for Codex Micro input reports for 15 seconds; press a hardware or Agent control now.")
DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
    print("inputReports=\(reportCount)")
    IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    exit(reportCount > 0 ? EXIT_SUCCESS : EXIT_FAILURE)
}
RunLoop.main.run()
