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
    // Held longer than this = changed mind, no action (Karabiner's to_if_alone default).
    static let timeout: TimeInterval = 1.0
    static var hid: IOHIDManager?
    static var globeDown = false

    static func start() {
        let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        print("[PrtScn] accessibility trusted: \(trusted)")
        NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]) { e in
            guard e.type == .flagsChanged else {
                if pressed != nil { print("[PrtScn] interrupted by event type=\(e.type.rawValue)") }
                pressed = nil
                return
            }
            // Fn comes from HID when available; its flagsChanged may be suppressed or duplicated.
            if e.keyCode == TriggerKey.fnKeyCode && hid != nil { return }
            guard let key = TriggerKey(keyCode: e.keyCode) else { pressed = nil; return } // Caps Lock etc.
            changed(key, down: e.modifierFlags.rawValue & key.deviceMask != 0, flags: e.modifierFlags)
        }
        startGlobe()
    }

    static func changed(_ key: TriggerKey, down: Bool, flags: NSEvent.ModifierFlags) {
        if down {
            let others = flags.intersection([.command, .option, .control, .shift, .function]).subtracting(key.family)
            pressed = pressed == nil && others.isEmpty ? key : nil
            keyDownsAtPress = keyDowns()
            pressedAt = ProcessInfo.processInfo.systemUptime
            print("[PrtScn] \(key) down, armed=\(pressed != nil)")
        } else if pressed == key {
            pressed = nil
            let clean = keyDowns() == keyDownsAtPress && ProcessInfo.processInfo.systemUptime - pressedAt < timeout
            let action = Bindings.all[key]
            print("[PrtScn] \(key) up, clean=\(clean) paused=\(paused) action=\(String(describing: action))")
            if clean, !paused, let action { action.run() }
        }
    }

    static func keyDowns() -> UInt32 {
        CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
    }

    // Globe key straight from Apple keyboard HID. macOS can drop the Fn flagsChanged event
    // when "Press Globe key to" is "Do Nothing". Needs Input Monitoring permission.
    static func startGlobe() {
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
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
