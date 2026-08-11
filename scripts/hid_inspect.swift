#!/usr/bin/env swift

import Foundation
import IOKit.hid

let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let matching: [String: Any] = [
    kIOHIDVendorIDKey as String: 0x303A,
    kIOHIDProductIDKey as String: 0x8360,
    kIOHIDPrimaryUsagePageKey as String: 0xFF00,
    kIOHIDPrimaryUsageKey as String: 1,
]
IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

let managerResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
guard managerResult == kIOReturnSuccess else {
    fatalError(String(format: "IOHIDManagerOpen failed: 0x%08X", managerResult))
}
defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

guard let deviceSet = IOHIDManagerCopyDevices(manager), CFSetGetCount(deviceSet) == 1 else {
    fatalError("Expected exactly one 303A:8360 vendor HID device")
}

var rawDevices = [UnsafeRawPointer?](repeating: nil, count: 1)
CFSetGetValues(deviceSet, &rawDevices)
let device = unsafeBitCast(rawDevices[0], to: IOHIDDevice.self)

func integerProperty(_ key: CFString) -> Int? {
    guard let value = IOHIDDeviceGetProperty(device, key) else { return nil }
    return (value as? NSNumber)?.intValue
}

let product = IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) ?? "?" as CFString
let inputSize = integerProperty(kIOHIDMaxInputReportSizeKey as CFString) ?? -1
let outputSize = integerProperty(kIOHIDMaxOutputReportSizeKey as CFString) ?? -1
let featureSize = integerProperty(kIOHIDMaxFeatureReportSizeKey as CFString) ?? -1
print("device=\(product) maxInput=\(inputSize) maxOutput=\(outputSize) maxFeature=\(featureSize)")

guard let rawElements = IOHIDDeviceCopyMatchingElements(
    device,
    nil,
    IOOptionBits(kIOHIDOptionsTypeNone)
) as? [IOHIDElement] else {
    fatalError("Could not read parsed HID elements")
}

let outputElements = rawElements.filter {
    IOHIDElementGetType($0) == kIOHIDElementTypeOutput
}

if outputElements.isEmpty {
    print("outputElements=none")
} else {
    for element in outputElements {
        print(
            "outputElement reportID=\(IOHIDElementGetReportID(element)) " +
            "usagePage=\(IOHIDElementGetUsagePage(element)) " +
            "usage=\(IOHIDElementGetUsage(element)) " +
            "reportSize=\(IOHIDElementGetReportSize(element)) " +
            "reportCount=\(IOHIDElementGetReportCount(element))"
        )
    }
}

exit(outputSize > 0 && outputElements.contains { IOHIDElementGetReportID($0) == 6 }
    ? EXIT_SUCCESS
    : EXIT_FAILURE)
