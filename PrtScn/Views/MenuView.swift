import ServiceManagement
import SwiftUI

// Native menu bar menu (MenuBarExtra .menu style).
struct MenuView: View {
    @Environment(\.openWindow) private var openWindow
    @AppStorage("paused") private var paused = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        KeyMenus()
        Divider()
        Button(paused ? "Resume" : "Pause") {
            paused.toggle()
            print("[PrtScn] paused=\(paused)")
        }
        // Button with a trailing ✓ badge, not a Toggle: a Toggle adds a state column that indents every item.
        Button("Launch at login") {
            print("[PrtScn] launchAtLogin -> \(!launchAtLogin)")
            do { try launchAtLogin ? SMAppService.mainApp.unregister() : SMAppService.mainApp.register() }
            catch { print("[PrtScn] login item failed: \(error)") }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        .badge(launchAtLogin ? Text("✓") : nil)
        Divider()
        Button("About PrtScn") {
            openWindow(id: "about")
            NSApp.activate()
        }
        Button("Quit PrtScn") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
