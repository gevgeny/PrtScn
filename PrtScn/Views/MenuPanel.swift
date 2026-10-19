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
    @State private var missing = Permission.missing

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !missing.isEmpty {
                HStack(spacing: 6) {
                    Text("⛔️ Allow")
                        .font(.callout)
                        .foregroundStyle(.red)
                    ForEach(missing, id: \.self) { permission in
                        Button(permission.title) {
                            close()
                            permission.grant()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                separator
            }
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
        // The panel doesn't activate the app, so controls would draw in their inactive (dimmed) style.
        .environment(\.controlActiveState, .key)
        .onReceive(NotificationCenter.default.publisher(for: Permission.changed)) { _ in
            withAnimation(.snappy(duration: 0.25)) { missing = Permission.missing }
        }
    }

    private func keyRow(_ key: TriggerKey) -> some View {
        HoverRow(action: { withAnimation(.snappy(duration: 0.25)) { expanded = expanded == key ? nil : key } }) {
            KeyBadge(key: key, active: bindings[key] != nil)
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
        HoverRow(action: action) {
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
    var height: CGFloat = 34 // One height for every row.
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

// Key cap: glyph top-right, faint label bottom-left (Left/Right, or the globe on fn).
// Unassigned: dimmed outline on a light grey fill. Assigned: bright outline, no fill.
struct KeyBadge: View {
    let key: TriggerKey
    var active = false

    var body: some View {
        // Tight glyph-to-label gap; the label keeps its bottom margin.
        VStack(spacing: -2) {
            Text(key.glyph)
                .font(.system(size: key == .fn ? 11 : 13, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .trailing)
            Group {
                if key == .fn { Image(systemName: "globe").font(.system(size: 9, weight: .semibold)) }
                else { Text(key.side ?? "").font(.system(size: 8, weight: .medium)) }
            }
            .opacity(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 5)
        .padding(.bottom, 3)
        .frame(width: 40, height: 28, alignment: .bottom)
        .background(active ? .clear : Color.primary.opacity(0.08), in: .rect(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary, lineWidth: 1))
        // Unassigned: dimmed on grey, softer than the action titles; assigned: full brightness.
        .opacity(active ? 1 : 0.7)
    }
}
