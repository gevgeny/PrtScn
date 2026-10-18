import AppKit
import ServiceManagement
import SwiftUI

// Native AppKit status menu. AppKit draws item images at their real size;
// SwiftUI menus shrink item icons to ~15pt, which made the key badges unreadable.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var aboutWindow: NSWindow?

    override init() {
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()
    }

    private func updateIcon() {
        statusItem.button?.image = KeyMonitor.paused ? .menuBarIconPaused : .menuBarIcon
    }

    // Rebuilt on every open so titles, checkmarks and badges are current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let bindings = Bindings.all
        // Header + arrow so rows read as key -> action settings, not commands.
        menu.addItem(.sectionHeader(title: "Tap a key to capture"))
        for key in TriggerKey.allCases {
            let item = NSMenuItem(title: bindings[key]?.title ?? "Not set", action: nil, keyEquivalent: "")
            item.image = key.badge
            // macOS 27 hides menu item images unless asked.
            item.preferredImageVisibility = .visible
            let font = NSFont.menuFont(ofSize: 0)
            let title = NSMutableAttributedString(string: "→  ", attributes: [.foregroundColor: NSColor.tertiaryLabelColor, .font: font])
            title.append(NSAttributedString(string: bindings[key]?.title ?? "Not set", attributes: [
                .foregroundColor: bindings[key] == nil ? NSColor.secondaryLabelColor : NSColor.labelColor,
                .font: font,
            ]))
            item.attributedTitle = title
            let submenu = NSMenu()
            for action in Action.allCases.map(Optional.some) + [nil] {
                let choice = NSMenuItem(title: action?.title ?? "None", action: #selector(pick(_:)), keyEquivalent: "")
                choice.target = self
                choice.representedObject = (key, action)
                choice.state = bindings[key] == action ? .on : .off
                submenu.addItem(choice)
            }
            item.submenu = submenu
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(item(KeyMonitor.paused ? "Resume" : "Pause", #selector(togglePause)))
        let login = item("Launch at login", #selector(toggleLogin))
        if SMAppService.mainApp.status == .enabled { login.badge = NSMenuItemBadge(string: "✓") }
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(item("About PrtScn", #selector(showAbout)))
        menu.addItem(NSMenuItem(title: "Quit PrtScn", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func pick(_ sender: NSMenuItem) {
        guard let (key, action) = sender.representedObject as? (TriggerKey, Action?) else { return }
        var bindings = Bindings.all
        bindings[key] = action
        Bindings.all = bindings
        print("[PrtScn] bindings -> \(bindings)")
    }

    @objc private func togglePause() {
        UserDefaults.standard.set(!KeyMonitor.paused, forKey: "paused")
        updateIcon()
        print("[PrtScn] paused=\(KeyMonitor.paused)")
    }

    @objc private func toggleLogin() {
        let on = SMAppService.mainApp.status != .enabled
        print("[PrtScn] launchAtLogin -> \(on)")
        do { try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister() }
        catch { print("[PrtScn] login item failed: \(error)") }
    }

    @objc private func showAbout() {
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

extension TriggerKey {
    var symbol: String {
        switch self {
        case .fn: "fn"
        case .ctrl: "Lt ⌃"
        case .opt: "Lt ⌥"
        case .rightCtrl: "Rt ⌃"
        case .rightOpt: "Rt ⌥"
        }
    }

    // Outlined key cap; template so it follows the menu's text color.
    var badge: NSImage {
        let image = NSImage(size: NSSize(width: 40, height: 20), flipped: false) { rect in
            NSColor.black.set()
            NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5).stroke()
            let text = NSAttributedString(string: symbol, attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .semibold)])
            let size = text.size()
            // Globe key: SF Symbol, not 🌐 emoji (a color emoji turns into a blob in a template image).
            let globe = self == .fn
                ? NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?
                    .withSymbolConfiguration(.init(pointSize: 10, weight: .semibold))
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
