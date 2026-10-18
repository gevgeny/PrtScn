import AppKit
import SwiftUI

// Menu bar item. Opens MenuPanel in a borderless panel under the icon, using the macOS 27
// expanded-interface API so the item highlights and tracks like a real menu.
final class StatusMenu: NSObject, NSStatusItemExpandedInterfaceDelegate, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var panel: KeyPanel?
    private var aboutWindow: NSWindow?

    // For actions that report progress (OCR). One status menu per app.
    static private(set) var current: StatusMenu?

    override init() {
        super.init()
        Self.current = self
        statusItem.expandedInterfaceDelegate = self
        updateIcon()
        // Pause is stored in UserDefaults by the panel; keep the icon in sync.
        NotificationCenter.default.addObserver(self, selector: #selector(updateIcon), name: UserDefaults.didChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateIcon), name: KeyMonitor.stateChanged, object: nil)
    }

    // Pulses the menu bar icon while a slow action runs.
    var busy = false {
        didSet {
            guard let button = statusItem.button, busy != oldValue else { return }
            button.wantsLayer = true
            if busy {
                let pulse = CABasicAnimation(keyPath: "opacity")
                pulse.fromValue = 1
                pulse.toValue = 0.3
                pulse.duration = 0.5
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                button.layer?.add(pulse, forKey: "busy")
            } else {
                button.layer?.removeAnimation(forKey: "busy")
            }
        }
    }

    @objc private func updateIcon() {
        statusItem.button?.image = KeyMonitor.waitingForPermission ? .menuBarIconWarning
            : KeyMonitor.paused ? .menuBarIconPaused : .menuBarIcon
    }

    func statusItem(_ statusItem: NSStatusItem, didBegin session: NSStatusItemExpandedInterfaceSession) {
        showPanel()
    }

    func statusItemDidEndExpandedInterfaceSession(_ statusItem: NSStatusItem, animated: Bool) {
        panel?.orderOut(nil)
        panel = nil
    }

    private func close() {
        if let session = statusItem.expandedInterfaceSession { session.cancel() } else { panel?.orderOut(nil) }
    }

    private func showPanel() {
        guard let buttonFrame = statusItem.button?.window?.frame,
              let screen = statusItem.button?.window?.screen ?? NSScreen.main else { return }
        // Fresh content on every open, so state (bindings, login item) is current.
        let content = MenuPanel(close: { [weak self] in self?.close() }, showAbout: { [weak self] in self?.showAbout() })
            // Room for the glass shadow; small top gap under the menu bar, like a native menu.
            .padding(EdgeInsets(top: 4, leading: 12, bottom: 12, trailing: 12))
            .frame(maxHeight: .infinity, alignment: .top)
        let host = NSHostingView(rootView: content)
        // Tall transparent panel down to the screen bottom: the accordion grows inside it without resizing the window.
        let width = host.fittingSize.width
        let top = buttonFrame.minY
        let x = min(max(buttonFrame.minX - 12, screen.visibleFrame.minX), screen.visibleFrame.maxX - width)
        let frame = NSRect(x: x, y: screen.visibleFrame.minY, width: width, height: top - screen.visibleFrame.minY)

        let panel = KeyPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.close() }
        panel.contentView = host
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    // Click outside (or anywhere that takes key) closes, like a menu.
    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func showAbout() {
        if aboutWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: AboutView()))
            window.title = "About PrtScn"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            aboutWindow = window
        }
        aboutWindow?.center()
        NSApp.activate()
        aboutWindow?.makeKeyAndOrderFront(nil)
    }
}

// Borderless panels can't become key by default; we need key for Esc, ⌘Q and resign-to-close.
final class KeyPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
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

    // Dimmed icon with a red dot, like Babbler: a permission is missing.
    static let menuBarIconWarning: NSImage = {
        let dotSize: CGFloat = 6
        let overhang: CGFloat = 2 // Dot sticks out right/up; padded on both sides to keep the icon centred.
        let base = menuBarIcon
        let size = NSSize(width: base.size.width + overhang * 2, height: base.size.height + overhang * 2)
        return NSImage(size: size, flipped: false) { _ in
            let baseRect = NSRect(origin: NSPoint(x: overhang, y: overhang), size: base.size)
            base.draw(in: baseRect, from: .zero, operation: .sourceOver, fraction: 0.35)
            // Not a template (the dot must stay red), so tint the base by hand; drawn per appearance.
            NSColor.labelColor.set()
            baseRect.fill(using: .sourceAtop)
            NSColor.systemRed.setFill()
            NSBezierPath(ovalIn: NSRect(x: baseRect.maxX - dotSize + overhang, y: size.height - dotSize, width: dotSize, height: dotSize)).fill()
            return true
        }
    }()
}
