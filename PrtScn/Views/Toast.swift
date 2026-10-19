import SwiftUI

// Small HUD near the cursor confirming what a silent action put on the clipboard.
enum Toast {
    private static var panel: NSPanel?
    private static var hideTask: Task<Void, Never>?

    static func show(_ text: String, symbol: String? = nil, swatch: NSColor? = nil) {
        let host = NSHostingView(rootView: ToastView(text: text, symbol: symbol, swatch: swatch))
        let size = host.fittingSize
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.contentView = host

        // Centered ~24 pt below the pointer (clear of the arrow), like the system HUDs; above it near the
        // bottom edge. The panel has 12 pt of shadow room around the capsule, hence the offsets.
        let mouse = NSEvent.mouseLocation
        var origin = NSPoint(x: mouse.x - size.width / 2, y: mouse.y - size.height - 12)
        if let frame = (NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main)?.visibleFrame {
            if origin.y < frame.minY { origin.y = mouse.y + 12 }
            origin.x = min(max(origin.x, frame.minX), frame.maxX - size.width)
            origin.y = min(max(origin.y, frame.minY), frame.maxY - size.height)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await NSAnimationContext.runAnimationGroup { $0.duration = 0.3; panel.animator().alphaValue = 0 }
            if !Task.isCancelled { panel.orderOut(nil) }
        }
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return panel
    }
}

private struct ToastView: View {
    let text: String
    let symbol: String?
    let swatch: NSColor?

    var body: some View {
        HStack(spacing: 8) {
            if let swatch {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: swatch))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.primary.opacity(0.25)))
                    .frame(width: 16, height: 16)
            } else if let symbol {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
            }
            Text(text).font(.system(size: 13, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
        .padding(12) // Room for the glass shadow.
    }
}
