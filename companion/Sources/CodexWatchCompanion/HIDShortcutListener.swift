import Foundation
import IOKit.hid

protocol HIDShortcutListening: AnyObject {
    func start() throws
    func stop()
}

enum HIDShortcutListenerError: LocalizedError {
    case openFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case .openFailed(let result):
            return String(format: "无法打开 StopWatch HID 监听：0x%08X", result)
        }
    }
}

final class HIDShortcutListener: HIDShortcutListening {
    static let matching: [String: Any] = [
        kIOHIDVendorIDKey as String: StopwatchHIDDescriptor.vendorID,
        kIOHIDProductIDKey as String: StopwatchHIDDescriptor.productID,
        kIOHIDPrimaryUsagePageKey as String: StopwatchHIDDescriptor.usagePage,
        kIOHIDPrimaryUsageKey as String: StopwatchHIDDescriptor.usage,
    ]

    private let eventHandler: (CompanionShortcutEvent) -> Void
    private let log: (String) -> Void
    private var manager: IOHIDManager?
    private var decodersByDevice: [UInt: HIDShortcutDecoder] = [:]
    private var warnedAboutPermission = false

    init(
        eventHandler: @escaping (CompanionShortcutEvent) -> Void,
        log: @escaping (String) -> Void
    ) {
        self.eventHandler = eventHandler
        self.log = log
    }

    func start() throws {
        guard manager == nil else { return }

        let manager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()

        IOHIDManagerSetDeviceMatching(manager, Self.matching as CFDictionary)
        IOHIDManagerRegisterInputReportCallback(
            manager,
            { context, result, sender, reportType, reportID, report, reportLength in
                guard result == kIOReturnSuccess,
                      reportType == kIOHIDReportTypeInput,
                      let context,
                      let sender,
                      reportID == StopwatchHIDDescriptor.reportID,
                      reportLength >= 0 else { return }

                let listener = Unmanaged<HIDShortcutListener>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
                listener.consume(reportID: reportID, bytes: bytes, sender: sender)
            },
            context
        )
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            { context, result, _, device in
                guard result == kIOReturnSuccess,
                      let context else { return }

                let listener = Unmanaged<HIDShortcutListener>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                listener.deviceMatched(device)
            },
            context
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            { context, result, _, device in
                guard result == kIOReturnSuccess,
                      let context else { return }

                let listener = Unmanaged<HIDShortcutListener>
                    .fromOpaque(context)
                    .takeUnretainedValue()
                listener.deviceRemoved(device)
            },
            context
        )

        self.manager = manager
        IOHIDManagerScheduleWithRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue
        )

        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeDenied,
           !warnedAboutPermission {
            warnedAboutPermission = true
            log("未授予“输入监控”权限，StopWatch 快捷键不可用；额度同步仍会继续")
        }

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            IOHIDManagerUnscheduleFromRunLoop(
                manager,
                CFRunLoopGetMain(),
                CFRunLoopMode.defaultMode.rawValue
            )
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            self.manager = nil
            decodersByDevice.removeAll()
            throw HIDShortcutListenerError.openFailed(result)
        }
    }

    func stop() {
        guard let manager else {
            decodersByDevice.removeAll()
            return
        }

        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue
        )
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = nil
        decodersByDevice.removeAll()
    }

    deinit {
        stop()
    }

    private func consume(reportID: UInt32, bytes: [UInt8], sender: UnsafeMutableRawPointer) {
        let deviceKey = UInt(bitPattern: sender)
        let now = ProcessInfo.processInfo.systemUptime
        var decoder = decodersByDevice[deviceKey] ?? HIDShortcutDecoder()
        let events = decoder.consume(reportID: Int(reportID), bytes: bytes, now: now)
        decodersByDevice[deviceKey] = decoder
        events.forEach(eventHandler)
    }

    private func deviceMatched(_ device: IOHIDDevice) {
        let deviceKey = UInt(bitPattern: Unmanaged.passUnretained(device).toOpaque())
        decodersByDevice[deviceKey] = HIDShortcutDecoder()
        log("StopWatch HID 已连接")
    }

    private func deviceRemoved(_ device: IOHIDDevice) {
        let deviceKey = UInt(bitPattern: Unmanaged.passUnretained(device).toOpaque())
        decodersByDevice.removeValue(forKey: deviceKey)
        log("StopWatch HID 已断开")
    }
}
