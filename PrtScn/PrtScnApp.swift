//
//  PrtScnApp.swift
//  PrtScn
//
//  Created by eugene gluhotorenko on 18/10/2026.
//

import AppKit
import ServiceManagement

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

// Fires the chosen action when Fn/Globe is tapped alone (no other key or modifier in between).
enum FnMonitor {
    static var armed = false

    static func start() {
        // Global key monitors need Accessibility permission.
        print("[PrtScn] FnMonitor.start")
        let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        print("[PrtScn] accessibility trusted: \(trusted)")
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { e in
            print("[PrtScn] event type=\(e.type.rawValue) keyCode=\(e.keyCode) flags=\(e.modifierFlags.rawValue)")
            guard e.type == .flagsChanged, e.keyCode == 63 else { armed = false; return }
            if e.modifierFlags.contains(.function) {
                armed = e.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty
                print("[PrtScn] Fn down, armed=\(armed)")
            } else if armed {
                armed = false
                print("[PrtScn] Fn tap -> fire")
                (Action(rawValue: UserDefaults.standard.string(forKey: "action") ?? "") ?? .areaClipboard).run()
            }
        }
        print("[PrtScn] global monitor installed: \(monitor != nil)")
    }
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let shared = AppDelegate()
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    static func main() {
        NSApplication.shared.delegate = shared
        NSApplication.shared.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[PrtScn] launched, login status=\(SMAppService.mainApp.status.rawValue)")
        statusItem.button?.image = NSImage(named: "MenuBarIcon")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        FnMonitor.start()
    }

    // Rebuilt on every open so checkmarks are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        print("[PrtScn] menu open")
        menu.removeAllItems()
        let current = UserDefaults.standard.string(forKey: "action") ?? Action.areaClipboard.rawValue
        for a in Action.allCases {
            let item = NSMenuItem(title: a.rawValue, action: #selector(pick(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = a.rawValue
            item.state = a.rawValue == current ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc func pick(_ item: NSMenuItem) {
        print("[PrtScn] action -> \(item.title)")
        UserDefaults.standard.set(item.representedObject, forKey: "action")
    }

    @objc func toggleLogin() {
        let on = SMAppService.mainApp.status != .enabled
        print("[PrtScn] launchAtLogin -> \(on)")
        do { try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
        catch { print("[PrtScn] login item failed: \(error)") }
    }
}
