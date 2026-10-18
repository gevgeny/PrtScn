//
//  PrtScnApp.swift
//  PrtScn
//
//  Created by eugene gluhotorenko on 18/10/2026.
//

import AppKit
import IOKit.hid
import ServiceManagement
import SwiftUI

enum Action: String, CaseIterable {
    case screenFile = "Save picture of screen as a file"
    case screenClipboard = "Copy picture of screen to the clipboard"
    case areaFile = "Save picture of selected area as a file"
    case areaClipboard = "Copy picture of selected area to the clipboard"
    case options = "Screenshot and recording options"

    func run() {
        print("[PrtScn] run \(self)")
        switch self {
        case .screenFile: capture(screenshotPaths())
        case .screenClipboard: capture(["-c"])
        case .areaFile: capture(["-i", screenshotPaths()[0]])
        case .areaClipboard: capture(["-ic"])
        case .options: NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app"))
        }
    }

    private func capture(_ args: [String]) {
        print("[PrtScn] screencapture \(args)")
        do { _ = try Process.run(URL(fileURLWithPath: "/usr/sbin/screencapture"), arguments: args) }
        catch { print("[PrtScn] screencapture failed: \(error)") }
    }

    // Same folder and naming as Cmd+Shift+3; one file per display.
    private func screenshotPaths() -> [String] {
        let dir = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
            .map { NSString(string: $0).expandingTildeInPath }
            ?? NSHomeDirectory() + "/Desktop"
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let name = "\(dir)/Screenshot \(f.string(from: Date()))"
        return (1...max(NSScreen.screens.count, 1)).map { $0 == 1 ? "\(name).png" : "\(name) (\($0)).png" }
    }
}

enum TriggerKey: String, CaseIterable, Identifiable {
    case fn = "Fn", opt = "Opt", rightOpt = "R Opt", ctrl = "Ctrl", rightCtrl = "R Ctrl"
    var id: Self { self }

    init?(keyCode: UInt16) {
        switch keyCode {
        case 0x3F: self = .fn
        case 0x3A: self = .opt
        case 0x3D: self = .rightOpt
        case 0x3B: self = .ctrl
        case 0x3E: self = .rightCtrl
        default: return nil
        }
    }

    var glyph: String {
        switch self {
        case .fn: "fn"
        case .opt, .rightOpt: "⌥"
        case .ctrl, .rightCtrl: "⌃"
        }
    }

    var family: NSEvent.ModifierFlags {
        switch self {
        case .fn: .function
        case .opt, .rightOpt: .option
        case .ctrl, .rightCtrl: .control
        }
    }

    // Device-dependent bits (NX_DEVICE*KEYMASK) tell left from right.
    var deviceMask: UInt {
        switch self {
        case .fn: NSEvent.ModifierFlags.function.rawValue
        case .opt: 0x20
        case .rightOpt: 0x40
        case .ctrl: 0x01
        case .rightCtrl: 0x2000
        }
    }
}

// Key -> action assignments, persisted.
enum Bindings {
    static var all: [TriggerKey: Action] {
        get {
            guard let raw = UserDefaults.standard.dictionary(forKey: "bindings") as? [String: String] else {
                return [.fn: .areaClipboard]
            }
            return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in
                TriggerKey(rawValue: k).flatMap { key in Action(rawValue: v).map { (key, $0) } }
            })
        }
        set {
            UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: newValue.map { ($0.rawValue, $1.rawValue) }), forKey: "bindings")
        }
    }
}

// Fires an action when a trigger key is pressed and released alone, like Babbler's ActionKeyTracker:
// no other modifier held, no key/mouse/scroll in between, system key-down counter unchanged.
// Listen-only, so shortcuts that use these keys keep working.
enum KeyMonitor {
    static var paused: Bool { UserDefaults.standard.bool(forKey: "paused") }
    static var pressed: TriggerKey?
    static var keyDownsAtPress: UInt32 = 0
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
            if e.keyCode == 0x3F && hid != nil { return }
            guard let key = TriggerKey(keyCode: e.keyCode) else { pressed = nil; return } // Cmd, Shift, Caps...
            changed(key, down: e.modifierFlags.rawValue & key.deviceMask != 0, flags: e.modifierFlags)
        }
        startGlobe()
    }

    static func changed(_ key: TriggerKey, down: Bool, flags: NSEvent.ModifierFlags) {
        if down {
            let others = flags.intersection([.command, .option, .control, .shift, .function]).subtracting(key.family)
            pressed = pressed == nil && others.isEmpty ? key : nil
            keyDownsAtPress = keyDowns()
            print("[PrtScn] \(key) down, armed=\(pressed != nil)")
        } else if pressed == key {
            pressed = nil
            let clean = keyDowns() == keyDownsAtPress
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

@main
struct PrtScnApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @AppStorage("paused") private var paused = false

    var body: some Scene {
        MenuBarExtra {
            MenuView()
        } label: {
            Image(nsImage: paused ? .menuBarIconPaused : .menuBarIcon)
        }
        .menuBarExtraStyle(.window)

        Window("About PrtScn", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

// Start monitoring only after launch: installing it in App.init (before the app finished
// launching) left the menu bar panel without mouse events.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[PrtScn] launched, login status=\(SMAppService.mainApp.status.rawValue)")
        // Single instance: newest wins, so a fresh launch (or Xcode rerun) replaces a stale copy.
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        where app != .current {
            print("[PrtScn] quitting other instance pid=\(app.processIdentifier)")
            app.terminate()
        }
        KeyMonitor.start()
    }
}

extension NSImage {
    // Template images render by alpha, so a faded copy shows grey like a disabled item in light and dark.
    static let menuBarIconPaused: NSImage = {
        let image = NSImage(size: menuBarIcon.size, flipped: false) { rect in
            menuBarIcon.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 0.35)
            return true
        }
        image.isTemplate = true
        return image
    }()
}
