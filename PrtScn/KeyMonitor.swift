import AppKit
import IOKit.hid

// Fires an action when a trigger key is pressed and released alone, like Babbler's ActionKeyTracker:
// no other modifier held, no key/mouse/scroll in between, system key-down counter unchanged,
// and no key typed just before the press (mid-typing brushes of a modifier are accidents).
// Listen-only, so shortcuts that use these keys keep working.
enum KeyMonitor {
    static var paused: Bool { UserDefaults.standard.bool(forKey: "paused") }
    static var pressed: TriggerKey?
    static var keyDownsAtPress: UInt32 = 0
    static var pressedAt: TimeInterval = 0
    // Held longer than this = changed mind, no action. Real taps take ~80–200 ms; Karabiner's
    // to_if_alone default is 1 s, too forgiving for modifiers people also hold for shortcuts.
    static let timeout: TimeInterval = 0.25
    // Pressed this soon after typing a key = still typing, no action. Keystrokes in a burst come
    // ~100–250 ms apart; a deliberate tap usually follows a pause.
    static let typingCooldown: TimeInterval = 0.5
    static var lastKeyDownAt: TimeInterval = 0
    static var lastKeyDown = "" // Diagnostics: key name (never a character) and sending process.
    // Wait this long after release before firing; a key typed meanwhile means the tap was a brush mid-typing.
    static let fireDelay: Duration = .milliseconds(10)
    static var hid: IOHIDManager?
    static var globeDown = false

    static var tap: CFMachPort?
    static var mediaTap: CFMachPort?

    // Starts on launch if any key is assigned, otherwise on the first assignment.
    // Permission prompts come from Permission.requestMissing. Safe to call repeatedly.
    static func start() {
        guard !Bindings.all.isEmpty else { return }
        installTap()
        installMediaTap()
    }

    // Top-row keys: an active tap that swallows the media/system event so only the action runs.
    // Blocking needs Accessibility, so it's only installed once a top-row key is assigned.
    // ponytail: stays installed if those keys are unassigned later; it passes everything through then.
    private static func installMediaTap() {
        guard mediaTap == nil, Bindings.all.keys.contains(where: { $0.media != nil }) else { return }
        guard AXIsProcessTrusted() else {
            Task { try? await Task.sleep(for: .seconds(2)); installMediaTap() }
            return
        }
        let types: [CGEventType] = [.keyDown, .keyUp, systemDefined]
        let mask = types.reduce(CGEventMask(0)) { $0 | CGEventMask(1) << $1.rawValue }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: { _, type, event, _ in
            MainActor.assumeIsolated { KeyMonitor.handleMedia(type, event) } ? nil : Unmanaged.passUnretained(event)
        }, userInfo: nil) else {
            print("[PrtScn] media tap failed")
            return
        }
        print("[PrtScn] media tap installed")
        mediaTap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NotificationCenter.default.post(name: Permission.changed, object: nil)
    }

    // True = swallow. Assigned top-row keys fire on press; their release and auto-repeat are swallowed too.
    // With a modifier held (⌥⇧ volume steps, ⌃F-key shortcuts) the key passes through. Fn+key sends plain F1…F12,
    // which isn't mapped. No Fn flag check: macOS sets it on top-row events even without Fn.
    private static func handleMedia(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let mediaTap { CGEvent.tapEnable(tap: mediaTap, enable: true) }
            return false
        }
        let key: TriggerKey?, down: Bool, isRepeat: Bool, code: String
        if type == systemDefined {
            // NX_SUBTYPE_AUX_CONTROL_BUTTONS: data1 = key type << 16 | state << 8 | repeat.
            guard let e = NSEvent(cgEvent: event), e.subtype.rawValue == 8 else { return false }
            let nx = (e.data1 & 0xFFFF0000) >> 16
            key = TriggerKey.allCases.first { $0.media?.nx.contains(nx) == true }
            down = (e.data1 & 0xFF00) >> 8 == 0x0A
            isRepeat = e.data1 & 1 != 0
            code = "nx=\(nx)"
        } else {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            // Typed text never logs; only special keys above the normal keycode range.
            guard keyCode >= 0x80, keyCode != TriggerKey.globeKeyCode else { return false }
            key = TriggerKey.allCases.first { $0.media?.keyCodes.contains(keyCode) == true }
            down = type == .keyDown
            isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
            code = "keyCode=\(keyCode)"
        }
        guard let key else {
            if down && !isRepeat { print("[PrtScn] unmapped media key \(code)") }
            return false
        }
        let modifiers: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        guard !paused, event.flags.intersection(modifiers).isEmpty, let action = Bindings.all[key] else { return false }
        if down && !isRepeat {
            print("[PrtScn] \(key) (\(code)) pressed, fire \(action)")
            Task { action.run() } // Off the tap callback, which must return quickly.
        }
        return true
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
        // system-defined events, not keyDown, and don't bump the key-down counter.
        // No trackpad gestures: a finger resting on the trackpad sends them, which is not using the key.
        let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
                                    systemDefined]
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
        if type == .keyDown {
            let code = cgEvent.getIntegerValueField(.keyboardEventKeycode)
            if code == TriggerKey.globeKeyCode { return }
            // Only text editing counts as typing; Esc (cancelling a capture), arrows, F-keys don't.
            if code < 0x80 && !notTyping.contains(code) {
                lastKeyDownAt = ProcessInfo.processInfo.systemUptime
                lastKeyDown = describeKeyDown(cgEvent)
            }
        }
        // Inertia after an earlier swipe, or touch begin/end with no movement, is not the user scrolling now.
        if type == .scrollWheel, cgEvent.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
            || cgEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 0
            && cgEvent.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == 0 { return }
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
            let now = ProcessInfo.processInfo.systemUptime
            let typing = now - lastKeyDownAt < typingCooldown
            pressed = pressed == nil && others.isEmpty && !typing ? key : nil
            keyDownsAtPress = keyDowns()
            pressedAt = now
            let why = previous.map { "\($0) already held" }
                ?? (!others.isEmpty ? "other modifiers held \(others)"
                : typing ? "key typed \(Int((now - lastKeyDownAt) * 1000)) ms ago: \(lastKeyDown)" : "")
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
            guard verdict.hasPrefix("fire"), let action else { return }
            let downsAtRelease = keyDowns()
            Task {
                try? await Task.sleep(for: fireDelay)
                let typedAfter = keyDowns() &- downsAtRelease
                if typedAfter > 0 { print("[PrtScn] \(key) cancelled: \(typedAfter) key-down(s) right after release") }
                else { action.run() }
            }
        } else {
            print("[PrtScn] \(key) up, not armed")
        }
    }

    private static let systemDefined = CGEventType(rawValue: 14)! // NX_SYSDEFINED: media/brightness keys

    private static func describe(_ type: CGEventType) -> String {
        switch type {
        case .keyDown: "a key press"
        case .leftMouseDown, .rightMouseDown, .otherMouseDown: "a click"
        case .scrollWheel: "scrolling"
        case systemDefined: "a media/system key"
        default: "event type \(type.rawValue)"
        }
    }

    // Esc, arrows, Home/End/Page Up/Down, F1–F12.
    private static let notTyping: Set<Int64> = [53, 123, 124, 125, 126, 115, 119, 116, 121,
                                                122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]

    // Named for special keys only; letters, digits and symbols stay "a character key" so typing never logs.
    private static func describeKeyDown(_ e: CGEvent) -> String {
        let code = e.getIntegerValueField(.keyboardEventKeycode)
        let names: [Int64: String] = [53: "Esc", 36: "Return", 76: "Enter", 48: "Tab", 49: "Space", 51: "Delete",
                                      117: "Forward Delete", 123: "Left", 124: "Right", 125: "Down", 126: "Up",
                                      115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
                                      122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
                                      98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"]
        let key = names[code].map { "\($0) (keyCode=\(code))" } ?? (code >= 0x80 ? "special keyCode=\(code)" : "a character key")
        let pid = pid_t(e.getIntegerValueField(.eventSourceUnixProcessID))
        let app = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
        let auto = e.getIntegerValueField(.keyboardEventAutorepeat) != 0 ? ", autorepeat" : ""
        return "\(key) from \(app)\(auto)"
    }

    static func keyDowns() -> UInt32 {
        CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown)
    }

    // Any keyboard not made by Apple, so maybe with a right Control key. Listing devices needs no permission.
    // ponytail: vendor heuristic; a mouse or receiver that presents a keyboard interface counts too.
    static func hasNonAppleKeyboard() -> Bool {
        let m = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(m, [kIOHIDDeviceUsagePageKey: Int(kHIDPage_GenericDesktop),
                                          kIOHIDDeviceUsageKey: Int(kHIDUsage_GD_Keyboard)] as CFDictionary)
        let devices = IOHIDManagerCopyDevices(m) as? Set<IOHIDDevice> ?? []
        return devices.contains { IOHIDDeviceGetProperty($0, kIOHIDVendorIDKey as CFString) as? Int != 0x05AC }
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
