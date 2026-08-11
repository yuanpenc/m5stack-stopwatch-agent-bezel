#!/usr/bin/env swift

import Foundation
import IOKit.hid

let vendorID = 0x303A
let productID = 0x8360
let reportID: UInt8 = 6

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

let matching: [String: Any] = [
    kIOHIDVendorIDKey as String: vendorID,
    kIOHIDProductIDKey as String: productID,
    kIOHIDPrimaryUsagePageKey as String: 0xFF00,
    kIOHIDPrimaryUsageKey as String: 1,
]
IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

let managerResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
guard managerResult == kIOReturnSuccess else {
    fatalError(String(format: "IOHIDManagerOpen failed: 0x%08X", managerResult))
}

guard let deviceSet = IOHIDManagerCopyDevices(manager), CFSetGetCount(deviceSet) > 0 else {
    fatalError("No 303A:8360 vendor HID device found")
}
guard CFSetGetCount(deviceSet) == 1 else {
    fatalError("Expected exactly one 303A:8360 vendor HID device")
}

var rawDevices = [UnsafeRawPointer?](
    repeating: nil,
    count: CFSetGetCount(deviceSet)
)
CFSetGetValues(deviceSet, &rawDevices)
let device = unsafeBitCast(rawDevices[0], to: IOHIDDevice.self)

let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString)
print("device=\(product ?? "?" as CFString)")

let deviceResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
guard deviceResult == kIOReturnSuccess else {
    fatalError(String(format: "IOHIDDeviceOpen failed: 0x%08X", deviceResult))
}

let arguments = Array(CommandLine.arguments.dropFirst())
let knownModes = ["--demo-lights", "--completion-idle", "--completion-done"]
guard arguments.allSatisfy({ knownModes.contains($0) }) else {
    fatalError("Unknown probe mode")
}
guard arguments.count <= 1 else {
    fatalError("Choose only one probe mode")
}

let mode = arguments.first ?? "--device-status"
let json: String
switch mode {
case "--demo-lights":
    json = "{\"method\":\"v.oai.thstatus\",\"params\":[{\"id\":0,\"c\":16777215,\"b\":1,\"e\":\"off\",\"s\":0},{\"id\":1,\"c\":1754367,\"b\":1,\"e\":\"breath\",\"s\":1},{\"id\":2,\"c\":4521796,\"b\":1,\"e\":\"off\",\"s\":0},{\"id\":3,\"c\":16753920,\"b\":1,\"e\":\"off\",\"s\":0},{\"id\":4,\"c\":16724787,\"b\":1,\"e\":\"off\",\"s\":0},{\"id\":5,\"c\":0,\"b\":0,\"e\":\"off\",\"s\":0}],\"id\":4243}\n"
case "--completion-idle":
    json = "{\"method\":\"v.oai.thstatus\",\"params\":[{\"id\":0,\"c\":16777215,\"b\":1,\"e\":\"off\",\"s\":0}],\"id\":4244}\n"
case "--completion-done":
    json = "{\"method\":\"v.oai.thstatus\",\"params\":[{\"id\":0,\"c\":2869614,\"b\":1,\"e\":\"off\",\"s\":0}],\"id\":4245}\n"
default:
    json = "{\"method\":\"device.status\",\"params\":{},\"id\":4242}\n"
}
print("mode=\(mode)")
let payload = Array(json.utf8)
var payloadOffset = 0
var writeResult = kIOReturnSuccess
var reportNumber = 0
while payloadOffset < payload.count {
    let chunkSize = min(61, payload.count - payloadOffset)
    var report = [UInt8](repeating: 0, count: 64)
    report[0] = reportID
    report[1] = 2
    report[2] = UInt8(chunkSize)
    report.replaceSubrange(
        3..<(3 + chunkSize),
        with: payload[payloadOffset..<(payloadOffset + chunkSize)]
    )

    writeResult = report.withUnsafeBytes { bytes in
        IOHIDDeviceSetReport(
            device,
            kIOHIDReportTypeOutput,
            CFIndex(reportID),
            bytes.bindMemory(to: UInt8.self).baseAddress!,
            report.count
        )
    }
    reportNumber += 1
    print(String(format: "setReport[%d](full 64 bytes)=0x%08X", reportNumber, writeResult))
    guard writeResult == kIOReturnSuccess else { break }
    payloadOffset += chunkSize
    usleep(10_000)
}

IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
exit(writeResult == kIOReturnSuccess ? EXIT_SUCCESS : EXIT_FAILURE)
