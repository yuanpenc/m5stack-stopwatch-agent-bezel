import Foundation
import IOKit.hid

@MainActor
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

enum HIDShortcutCallbackAction: Equatable {
    case input(reportID: Int, bytes: [UInt8], deviceKey: UInt)
    case matched(deviceKey: UInt)
    case removed(deviceKey: UInt)
}

final class HIDShortcutCallbackSession: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: (@MainActor (HIDShortcutCallbackAction) -> Void)?

    init(handler: @MainActor @escaping (HIDShortcutCallbackAction) -> Void) {
        self.handler = handler
    }

    func invalidate() {
        lock.lock()
        handler = nil
        lock.unlock()
    }

    @MainActor
    func deliver(_ action: HIDShortcutCallbackAction) {
        lock.lock()
        let handler = handler
        lock.unlock()
        handler?(action)
    }
}

enum HIDShortcutCallbackRegistry {
    private final class State: @unchecked Sendable {
        let lock = NSLock()
        var sessions: [UInt: HIDShortcutCallbackSession] = [:]
        var nextToken: UInt = 1
    }

    private static let state = State()

    static func retain(_ session: HIDShortcutCallbackSession) -> UnsafeMutableRawPointer {
        // IOKit only echoes this opaque token; it is never dereferenced or reused.
        state.lock.lock()
        precondition(state.nextToken < UInt.max, "StopWatch HID callback token space exhausted")
        let token = state.nextToken
        state.nextToken += 1
        state.sessions[token] = session
        state.lock.unlock()
        return UnsafeMutableRawPointer(bitPattern: token)!
    }

    static func session(for context: UnsafeMutableRawPointer?) -> HIDShortcutCallbackSession? {
        guard let context else { return nil }
        let token = UInt(bitPattern: context)
        state.lock.lock()
        let session = state.sessions[token]
        state.lock.unlock()
        return session
    }

    static func invalidate(_ context: UnsafeMutableRawPointer) {
        let token = UInt(bitPattern: context)
        state.lock.lock()
        let session = state.sessions.removeValue(forKey: token)
        state.lock.unlock()
        session?.invalidate()
    }
}

private final class HIDShortcutManagerLifetime: @unchecked Sendable {
    let manager: IOHIDManager
    let context: UnsafeMutableRawPointer

    private let lock = NSLock()
    private var tornDown = false

    init(manager: IOHIDManager, context: UnsafeMutableRawPointer) {
        self.manager = manager
        self.context = context
    }

    @MainActor
    func tearDown() {
        HIDShortcutCallbackRegistry.invalidate(context)

        lock.lock()
        guard !tornDown else {
            lock.unlock()
            return
        }
        tornDown = true
        lock.unlock()

        IOHIDManagerRegisterInputReportCallback(manager, nil, nil)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue
        )
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    func tearDownAfterFinalRelease() {
        // Late callbacks become no-ops before teardown is handed to the main RunLoop.
        HIDShortcutCallbackRegistry.invalidate(context)
        Task { @MainActor [self] in
            tearDown()
        }
    }
}

@MainActor
final class HIDShortcutListener: HIDShortcutListening {
    static let matching: [String: Any] = [
        kIOHIDVendorIDKey as String: StopwatchHIDDescriptor.vendorID,
        kIOHIDProductIDKey as String: StopwatchHIDDescriptor.productID,
        kIOHIDPrimaryUsagePageKey as String: StopwatchHIDDescriptor.usagePage,
        kIOHIDPrimaryUsageKey as String: StopwatchHIDDescriptor.usage,
    ]

    private let eventHandler: (CompanionShortcutEvent) -> Void
    private let log: (String) -> Void
    private var lifetime: HIDShortcutManagerLifetime?
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
        guard lifetime == nil else { return }

        let manager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        let callbackSession = HIDShortcutCallbackSession { [weak self] action in
            self?.handle(action)
        }
        let context = HIDShortcutCallbackRegistry.retain(callbackSession)
        let lifetime = HIDShortcutManagerLifetime(manager: manager, context: context)

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

                let bytes = Array(UnsafeBufferPointer(start: report, count: reportLength))
                guard let session = HIDShortcutCallbackRegistry.session(for: context) else { return }
                MainActor.assumeIsolated {
                    session.deliver(.input(
                        reportID: Int(reportID),
                        bytes: bytes,
                        deviceKey: UInt(bitPattern: sender)
                    ))
                }
            },
            context
        )
        IOHIDManagerRegisterDeviceMatchingCallback(
            manager,
            { context, result, _, device in
                guard result == kIOReturnSuccess,
                      let context else { return }

                guard let session = HIDShortcutCallbackRegistry.session(for: context) else { return }
                let deviceKey = UInt(bitPattern: Unmanaged.passUnretained(device).toOpaque())
                MainActor.assumeIsolated {
                    session.deliver(.matched(deviceKey: deviceKey))
                }
            },
            context
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            manager,
            { context, result, _, device in
                guard result == kIOReturnSuccess,
                      let context else { return }

                guard let session = HIDShortcutCallbackRegistry.session(for: context) else { return }
                let deviceKey = UInt(bitPattern: Unmanaged.passUnretained(device).toOpaque())
                MainActor.assumeIsolated {
                    session.deliver(.removed(deviceKey: deviceKey))
                }
            },
            context
        )

        self.lifetime = lifetime
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
            lifetime.tearDown()
            self.lifetime = nil
            decodersByDevice.removeAll()
            throw HIDShortcutListenerError.openFailed(result)
        }
    }

    func stop() {
        guard let lifetime else {
            decodersByDevice.removeAll()
            return
        }

        self.lifetime = nil
        lifetime.tearDown()
        decodersByDevice.removeAll()
    }

    deinit {
        lifetime?.tearDownAfterFinalRelease()
    }

    private func handle(_ action: HIDShortcutCallbackAction) {
        switch action {
        case .input(let reportID, let bytes, let deviceKey):
            consume(reportID: reportID, bytes: bytes, deviceKey: deviceKey)
        case .matched(let deviceKey):
            decodersByDevice[deviceKey] = HIDShortcutDecoder()
            log("StopWatch HID 已连接")
        case .removed(let deviceKey):
            decodersByDevice.removeValue(forKey: deviceKey)
            log("StopWatch HID 已断开")
        }
    }

    private func consume(reportID: Int, bytes: [UInt8], deviceKey: UInt) {
        let now = ProcessInfo.processInfo.systemUptime
        var decoder = decodersByDevice[deviceKey] ?? HIDShortcutDecoder()
        let events = decoder.consume(reportID: reportID, bytes: bytes, now: now)
        decodersByDevice[deviceKey] = decoder
        events.forEach(eventHandler)
    }
}
