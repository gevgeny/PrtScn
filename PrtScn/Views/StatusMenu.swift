import AppKit
import ServiceManagement
import SwiftUI

// Native AppKit status menu. AppKit draws item images at their real size;
// SwiftUI menus shrink item icons to ~15pt, which made the key badges unreadable.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var aboutWindow: NSWindow?

    // For actions that report progress (OCR). One status menu per app.
    static private(set) var current: StatusMenu?

    override init() {
        super.init()
        Self.current = self
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()
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
}
