import AppKit
import IOKit.hid

// Fires an action when a trigger key is pressed and released alone, like Babbler's ActionKeyTracker:
// no other modifier held, no key/mouse/scroll in between, system key-down counter unchanged.
// Listen-only, so shortcuts that use these keys keep working.
enum KeyMonitor {
    static var paused: Bool { UserDefaults.standard.bool(forKey: "paused") }
    static var pressed: TriggerKey?
    static var keyDownsAtPress: UInt32 = 0
    static var pressedAt: TimeInterval = 0
    // Held longer than this = changed mind, no action. Real taps take ~80–200 ms; Karabiner's
    // to_if_alone default is 1 s, too forgiving for modifiers people also hold for shortcuts.
    static let timeout: TimeInterval = 0.35
    static var hid: IOHIDManager?
    static var globeDown = false

    static var tap: CFMachPort?

    // Starts on launch if any key is assigned, otherwise on the first assignment.
    // Permission prompts come from Permission.requestMissing. Safe to call repeatedly.
    static func start() {
        guard tap == nil, !Bindings.all.isEmpty else { return }
        installTap()
    }

    // Listen-only event tap: needs Input Monitoring only (a global NSEvent key monitor needs Accessibility).
    private static func installTap() {
        guard tap == nil else { return }
        // tapCreate succeeds even without permission (it just gets no key events), so check first.
        guard CGPreflightListenEventAccess() else {
            // Not granted yet: retry, so allowing it in System Settings works without a restart.
            Task { try? await Task.sleep(for: .seconds(2)); installTap() }
            return
        }
        // Anything here while a key is held cancels the tap. Media/brightness keys (fn+F1, volume) are
        // system-defined events, not keyDown, and don't bump the key-down counter; trackpad gestures neither.
        let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
                                    systemDefined, gesture]
        let mask = types.reduce(CGEventMask(0)) { $0 | CGEventMask(1) << $1.rawValue }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                          eventsOfInterest: mask, callback: { _, type, event, _ in
            MainActor.assumeIsolated { KeyMonitor.handle(type, event) }
            return Unmanaged.passUnretained(event)
        }, userInfo: nil) else {
            print("[PrtScn] event tap failed")
            return
        }
        print("[PrtScn] event tap installed")
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        startGlobe()
        NotificationCenter.default.post(name: Permission.changed, object: nil)
    }

    private static func handle(_ type: CGEventType, _ cgEvent: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type == .flagsChanged, let e = NSEvent(cgEvent: cgEvent) else {
            // Never logs which key was typed, only that something happened.
            if let pressed { print("[PrtScn] \(pressed) cancelled by \(describe(type))") }
            pressed = nil
            return
        }
        // Fn comes from HID when available; its flagsChanged may be suppressed or duplicated.
        if e.keyCode == TriggerKey.fnKeyCode && hid != nil { return }
        guard let key = TriggerKey(keyCode: e.keyCode) else { // Caps Lock, right Control...
            if let pressed { print("[PrtScn] \(pressed) cancelled by other modifier keyCode=\(e.keyCode)") }
            pressed = nil
            return
        }
        changed(key, down: e.modifierFlags.rawValue & key.deviceMask != 0, flags: e.modifierFlags)
    }

    static func changed(_ key: TriggerKey, down: Bool, flags: NSEvent.ModifierFlags) {
        if down {
            let others = flags.intersection([.command, .option, .control, .shift, .function]).subtracting(key.family)
            let previous = pressed
            pressed = pressed == nil && others.isEmpty ? key : nil
            keyDownsAtPress = keyDowns()
            pressedAt = ProcessInfo.processInfo.systemUptime
            let why = previous.map { "\($0) already held" } ?? (others.isEmpty ? "" : "other modifiers held \(others)")
            print("[PrtScn] \(key) down, \(pressed != nil ? "armed" : "not armed: \(why)") flags=0x\(String(flags.rawValue, radix: 16))")
        } else if pressed == key {
            pressed = nil
            let heldMs = Int((ProcessInfo.processInfo.systemUptime - pressedAt) * 1000)
            let typed = keyDowns() &- keyDownsAtPress
            let action = Bindings.all[key]
            let verdict = typed > 0 ? "cancelled: \(typed) key-down(s) while held"
                : heldMs >= Int(timeout * 1000) ? "cancelled: held too long"
                : paused ? "skipped: paused"
                : action == nil ? "skipped: no action"
                : "fire \(action!)"
            print("[PrtScn] \(key) up after \(heldMs) ms, \(verdict)")
            if verdict.hasPrefix("fire"), let action { action.run() }
        } else {
            print("[PrtScn] \(key) up, not armed")
        }
    }

    private static let systemDefined = CGEventType(rawValue: 14)! // NX_SYSDEFINED: media/brightness keys
    private static let gesture = CGEventType(rawValue: 29)!       // NSEvent.EventType.gesture: trackpad

    private static func describe(_ type: CGEventType) -> String {
        switch type {
        case .keyDown: "a key press"
        case .leftMouseDown, .rightMouseDown, .otherMouseDown: "a click"
        case .scrollWheel: "scrolling"
        case systemDefined: "a media/system key"
        case gesture: "a trackpad gesture"
        default: "event type \(type.rawValue)"
        }
    }

    static func keyDowns() -> UInt32 {
        CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
    }

    // Globe key straight from Apple keyboard HID. macOS can drop the Fn flagsChanged event
    // when "Press Globe key to" is "Do Nothing". Same Input Monitoring permission as the tap.
    static func startGlobe() {
        let elements: [[String: Int]] = [
            [kIOHIDElementUsagePageKey: 0xFF, kIOHIDElementUsageKey: 0x03],
            [kIOHIDElementUsagePageKey: 0xFF01, kIOHIDElementUsageKey: 0x03],
        ]
        let devices = [[kIOHIDDeviceUsagePageKey: Int(kHIDPage_GenericDesktop), kIOHIDDeviceUsageKey: Int(kHIDUsage_GD_Keyboard)]]
            + elements.map { [kIOHIDDeviceUsagePageKey: $0[kIOHIDElementUsagePageKey]!, kIOHIDDeviceUsageKey: $0[kIOHIDElementUsageKey]!] }
        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatchingMultiple(m, devices as CFArray)
        IOHIDManagerSetInputValueMatchingMultiple(m, elements as CFArray)
        IOHIDManagerRegisterInputValueCallback(m, { _, result, _, value in
            guard result == kIOReturnSuccess else { return }
            let down = IOHIDValueGetIntegerValue(value) != 0
            MainActor.assumeIsolated {
                guard down != KeyMonitor.globeDown else { return }
                KeyMonitor.globeDown = down
                print("[PrtScn] fn (HID) \(down ? "down" : "up")")
                KeyMonitor.changed(.fn, down: down, flags: NSEvent.modifierFlags)
            }
        }, nil)
        IOHIDManagerScheduleWithRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(m, IOOptionBits(kIOHIDOptionsTypeNone))
        let connected = IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice> ?? []
        let hasGlobe = connected.contains { d in
            elements.contains { !((IOHIDDeviceCopyMatchingElements(d, $0 as CFDictionary, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement])?.isEmpty ?? true) }
        }
        print("[PrtScn] globe HID open=\(result == kIOReturnSuccess) hasGlobe=\(hasGlobe)")
        guard result == kIOReturnSuccess, hasGlobe else {
            // Fall back to Fn flagsChanged events.
            IOHIDManagerClose(m, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(m, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            return
        }
        hid = m
    }
}
