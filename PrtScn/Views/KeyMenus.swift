import SwiftUI

// One native submenu per key: badge + assigned action, submenu picks the action.
struct KeyMenus: View {
    @State private var assignment = Bindings.all

    var body: some View {
        ForEach(TriggerKey.allCases) { key in
            Menu {
                Picker("", selection: Binding(get: { assignment[key] }, set: { new in
                    assignment[key] = new
                    Bindings.all = assignment
                    print("[PrtScn] bindings -> \(assignment)")
                })) {
                    ForEach(Action.allCases, id: \.self) { Text($0.title).tag(Action?.some($0)) }
                    Text("None").tag(Action?.none)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                Label {
                    if let action = assignment[key] {
                        Text(action.title)
                    } else {
                        Text("Not set").foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(nsImage: key.badge)
                }
                // macOS 26 menus hide item icons unless asked.
                .labelStyle(.titleAndIcon)
            }
        }
    }
}

extension TriggerKey {
    var symbol: String {
        switch self {
        case .fn: "fn"
        case .ctrl: "Left ⌃"
        case .opt: "Left ⌥"
        case .rightCtrl: "Right ⌃"
        case .rightOpt: "Right ⌥"
        }
    }

    // Outlined key cap; template so it follows the menu's text color.
    var badge: NSImage {
        let image = NSImage(size: NSSize(width: 64, height: 26), flipped: false) { rect in
            NSColor.black.set()
            NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6).stroke()
            let text = NSAttributedString(string: symbol, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)])
            let size = text.size()
            // Globe key: SF Symbol, not 🌐 emoji (a color emoji turns into a blob in a template image).
            let globe = self == .fn
                ? NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?
                    .withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))
                : nil
            let globeWidth = globe.map { $0.size.width + 3 } ?? 0
            var x = (rect.width - globeWidth - size.width) / 2
            if let globe {
                globe.draw(in: NSRect(x: x, y: (rect.height - globe.size.height) / 2, width: globe.size.width, height: globe.size.height))
                x += globeWidth
            }
            text.draw(at: NSPoint(x: x, y: (rect.height - size.height) / 2))
            return true
        }
        image.isTemplate = true
        return image
    }
}
