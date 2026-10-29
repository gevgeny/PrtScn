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
    @State private var unavailable = Set(TriggerKey.allCases.filter { !$0.available })
    // Three keys per row, like a keyboard: modifiers, then the top row in threes (F1–F3, F4–F6…).
    private static let columns = 3
    private static let rows: [[TriggerKey]] = [TriggerKey.allCases.filter { $0.media == nil }, TriggerKey.allCases.filter { $0.media != nil }]
        .flatMap { group in stride(from: 0, to: group.count, by: columns).map { Array(group[$0..<min($0 + columns, group.count)]) } }

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
            ForEach(Self.rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(row) { keyCell($0) }
                    // Short last row keeps the column widths.
                    ForEach(row.count..<Self.columns, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 0) }
                }
                // Choices open full width under the row of the picked key.
                if let key = expanded, row.contains(key) {
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
        .frame(width: 480)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        // The panel doesn't activate the app, so controls would draw in their inactive (dimmed) style.
        .environment(\.controlActiveState, .key)
        .onReceive(NotificationCenter.default.publisher(for: Permission.changed)) { _ in
            withAnimation(.snappy(duration: 0.25)) { missing = Permission.missing }
        }
    }

    // Badge plus the action in up to two small lines; the open key stays highlighted.
    // Unavailable keys show N/A and ignore the mouse, unless assigned (so it can still be cleared).
    private func keyCell(_ key: TriggerKey) -> some View {
        let na = unavailable.contains(key) && bindings[key] == nil
        return HoverRow(height: 44, action: { withAnimation(.snappy(duration: 0.25)) { expanded = expanded == key ? nil : key } }) {
            KeyBadge(key: key, active: bindings[key] != nil)
            Text(na ? "N/A" : bindings[key]?.title ?? key.unsetTitle)
                .font(.system(size: 11))
                .lineLimit(2)
                .foregroundStyle(bindings[key] == nil ? .secondary : .primary)
        }
        .background(expanded == key ? Color.primary.opacity(0.1) : .clear, in: .rect(cornerRadius: 8))
        .opacity(na ? 0.4 : 1)
        .allowsHitTesting(!na)
        .frame(maxWidth: .infinity)
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
            Text(action?.title ?? (key.media != nil ? "Default" : "None"))
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

extension TriggerKey {
    // Unassigned top-row keys keep their system action.
    var unsetTitle: String { media != nil ? "Default" : "Not set" }
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

// Key cap: glyph top-right, faint label bottom-left (Left/Right, the globe on fn, F1… under a MacBook top-row symbol).
// Unassigned: dimmed outline on a light grey fill. Assigned: no fill, glyph and outline in the title color.
struct KeyBadge: View {
    let key: TriggerKey
    var active = false

    var body: some View {
        // Tight glyph-to-label gap; the label keeps its bottom margin.
        VStack(spacing: -2) {
            Group {
                if let media = key.media { Image(systemName: media.symbol).font(.system(size: 11, weight: .semibold)) }
                else { Text(key.glyph).font(.system(size: key == .fn ? 11 : 13, weight: .semibold)) }
            }
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
