import ServiceManagement
import SwiftUI

// Menu bar panel content. A SwiftUI panel instead of NSMenu for grey hover rows,
// toggles and picks that keep it open, and an animated accordion per key.
struct MenuPanel: View {
    let close: () -> Void
    let showAbout: () -> Void

    @State private var bindings = Bindings.all
    @State private var expanded: TriggerKey?
    @AppStorage("paused") private var paused = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var waitingForPermission = KeyMonitor.waitingForPermission

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if waitingForPermission {
                VStack(alignment: .leading, spacing: 8) {
                    Text("⛔️ PrtScn needs Input Monitoring to see key presses")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Grant Input Monitoring…") {
                        close()
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                separator
            }
            Text("Tap a key to capture")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            ForEach(TriggerKey.allCases) { key in
                keyRow(key)
                if expanded == key {
                    ForEach(Action.allCases.map(Optional.some) + [nil], id: \.self) { action in
                        choiceRow(key, action)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            separator
            toggleRow("Pause", symbol: "pause.fill", on: paused) {
                paused.toggle()
                print("[PrtScn] paused=\(paused)")
            }
            toggleRow("Launch at login", symbol: "power", on: launchAtLogin) {
                print("[PrtScn] launchAtLogin -> \(!launchAtLogin)")
                do { try launchAtLogin ? SMAppService.mainApp.unregister() : SMAppService.mainApp.register() }
                catch { print("[PrtScn] login item failed: \(error)") }
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
            separator
            HoverRow(action: { close(); showAbout() }) { Text("About PrtScn") }
            HoverRow(action: { NSApp.terminate(nil) }) {
                Text("Quit PrtScn")
                Spacer()
                Text("⌘Q").foregroundStyle(.tertiary)
            }
            .keyboardShortcut("q")
        }
        .padding(6)
        .frame(width: 340)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .onReceive(NotificationCenter.default.publisher(for: KeyMonitor.stateChanged)) { _ in
            withAnimation(.snappy(duration: 0.25)) { waitingForPermission = KeyMonitor.waitingForPermission }
        }
    }

    private func keyRow(_ key: TriggerKey) -> some View {
        HoverRow(action: { withAnimation(.snappy(duration: 0.25)) { expanded = expanded == key ? nil : key } }) {
            KeyBadge(key: key)
            Text("→").foregroundStyle(.tertiary)
            Text(bindings[key]?.title ?? "Not set")
                .foregroundStyle(bindings[key] == nil ? .secondary : .primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded == key ? 90 : 0))
        }
    }

    private func choiceRow(_ key: TriggerKey, _ action: Action?) -> some View {
        HoverRow(action: {
            bindings[key] = action
            Bindings.all = bindings
            print("[PrtScn] bindings -> \(bindings)")
        }) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6))
                .frame(width: 12)
                .opacity(bindings[key] == action ? 1 : 0)
            Text(action?.title ?? "None")
        }
    }

    // Control Center style toggle: symbol in a circle, accent-filled when on.
    private func toggleRow(_ title: String, symbol: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        HoverRow(height: 36, action: action) {
            ZStack {
                Circle().fill(on ? Color.accentColor : Color.primary.opacity(0.1))
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(on ? .white : .primary)
            }
            .frame(width: 26, height: 26)
            Text(title)
        }
    }

    private var separator: some View {
        Divider().padding(.horizontal, 10).padding(.vertical, 4)
    }
}

// Menu-style row: grey highlight on hover, whole row clickable.
struct HoverRow<Content: View>: View {
    var height: CGFloat = 28
    let action: () -> Void
    @ViewBuilder let content: Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) { content }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
                .background(hovering ? Color.primary.opacity(0.1) : .clear, in: .rect(cornerRadius: 8))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// Outlined key cap, 40×20 like the native menu version.
struct KeyBadge: View {
    let key: TriggerKey

    var body: some View {
        HStack(spacing: 3) {
            if key == .fn { Image(systemName: "globe").font(.system(size: 10, weight: .semibold)) }
            Text(key.symbol).font(.system(size: 11, weight: .semibold))
        }
        .frame(width: 40, height: 20)
        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.primary, lineWidth: 1))
        // Softer than the action titles, brighter than "Not set".
        .opacity(0.7)
    }
}
