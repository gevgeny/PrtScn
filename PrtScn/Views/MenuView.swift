import ServiceManagement
import SwiftUI

// Menu bar panel: key matrix plus menu-style rows.
struct MenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @AppStorage("paused") private var paused = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Panel otherwise squeezes the grid and truncates the action titles.
            KeyMatrix().fixedSize()
            Divider().padding(.horizontal, 14).padding(.vertical, 5)
            MenuRow(title: paused ? "Resume PrtScn" : "Pause PrtScn") {
                paused.toggle()
                print("[PrtScn] paused=\(paused)")
            }
            MenuRow(title: "Launch at login", checked: launchAtLogin) {
                print("[PrtScn] launchAtLogin -> \(!launchAtLogin)")
                do { try launchAtLogin ? SMAppService.mainApp.unregister() : SMAppService.mainApp.register() }
                catch { print("[PrtScn] login item failed: \(error)") }
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
            Divider().padding(.horizontal, 14).padding(.vertical, 5)
            MenuRow(title: "About PrtScn") {
                dismiss()
                openWindow(id: "about")
                NSApp.activate()
            }
            MenuRow(title: "Quit PrtScn", shortcut: "⌘Q") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(.vertical, 6)
    }
}

// Looks like a native menu item: checkmark gutter, accent highlight on hover, shortcut hint.
struct MenuRow: View {
    let title: String
    var checked = false
    var shortcut = ""
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 14)
                    .opacity(checked ? 1 : 0)
                Text(title)
                Spacer()
                Text(shortcut).foregroundStyle(hovering ? .white : .secondary)
            }
            .padding(.horizontal, 6)
            .frame(height: 24)
            .foregroundStyle(hovering ? .white : .primary)
            .background(hovering ? Color.accentColor : .clear, in: .rect(cornerRadius: 5))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .padding(.horizontal, 8)
    }
}
