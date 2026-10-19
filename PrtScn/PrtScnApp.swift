//
//  PrtScnApp.swift
//  PrtScn
//
//  Created by eugene gluhotorenko on 18/10/2026.
//

import AppKit
import ServiceManagement

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    static let shared = AppDelegate()
    private var statusMenu: StatusMenu?

    static func main() {
        NSApplication.shared.delegate = shared
        NSApplication.shared.run()
    }

    // Start monitoring only after launch: installing it earlier left our own menus without mouse events.
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[PrtScn] launched, login status=\(SMAppService.mainApp.status.rawValue)")
        // Single instance: newest wins, so a fresh launch (or Xcode rerun) replaces a stale copy.
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        where app != .current {
            print("[PrtScn] quitting other instance pid=\(app.processIdentifier)")
            app.terminate()
        }
        statusMenu = StatusMenu()
        Permission.requestMissing() // Keys assigned in an earlier run.
        KeyMonitor.start()
    }
}
