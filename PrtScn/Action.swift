import AppKit
import UniformTypeIdentifiers
import Vision

enum Action: String, CaseIterable {
    // Raw value (case name) is the persisted ID; title is display-only.
    case screenFile, screenClipboard, areaFile, areaClipboard, areaEdit, areaText, pickColor, options

    var title: String {
        switch self {
        case .screenFile: "Capture screen to file"
        case .screenClipboard: "Capture screen to clipboard"
        case .areaFile: "Capture area to file"
        case .areaClipboard: "Capture area to clipboard"
        case .areaEdit: "Capture area & edit"
        case .areaText: "Copy text from area"
        case .pickColor: "Pick color to clipboard"
        case .options: "Record screen…"
        }
    }

    func run() {
        print("[PrtScn] run \(self)")
        switch self {
        case .screenFile: capture(screenshotPaths())
        case .screenClipboard: capture(["-c"])
        case .areaFile: capture(["-i", screenshotPaths()[0]])
        case .areaClipboard: capture(["-ic"])
        case .areaEdit:
            // Saved like ⇧⌘4, then opened in the system Markup editor.
            let url = URL(fileURLWithPath: screenshotPaths()[0])
            capture(["-i", url.path]) { Task { await Self.markup(url) } }
        case .areaText:
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("prtscn-ocr.png")
            try? FileManager.default.removeItem(at: url)
            capture(["-i", url.path]) { Task { await Self.copyText(from: url) } }
        case .pickColor: Self.pickColor()
        // ⇧⌘5 toolbar already in recording mode; macOS's menu bar stop button ends it.
        case .options: capture(["-iUv", screenshotPaths(name: "Screen Recording", ext: "mov")[0]])
        }
    }

    private func capture(_ args: [String], then done: (@Sendable () -> Void)? = nil) {
        print("[PrtScn] screencapture \(args)")
        do { _ = try Process.run(URL(fileURLWithPath: "/usr/sbin/screencapture"), arguments: args) { _ in done?() } }
        catch { print("[PrtScn] screencapture failed: \(error)") }
    }

    // Markup is a system action extension (the editor the screenshot thumbnail opens). Not a documented
    // service name, so fall back to Preview if it's ever missing.
    private static let markupDelegate = MarkupDelegate()
    private static func markup(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return print("[PrtScn] edit cancelled") }
        guard let service = NSSharingService(named: .init("com.apple.MarkupUI.Markup")) else {
            print("[PrtScn] markup unavailable, opening Preview")
            return _ = NSWorkspace.shared.open(url)
        }
        markupDelegate.url = url
        service.delegate = markupDelegate
        NSApp.activate()
        service.perform(withItems: [url])
    }

    // System loupe; clicked pixel goes to the clipboard as #RRGGBB (sRGB). Esc cancels.
    private static var sampler: NSColorSampler?
    private static func pickColor() {
        sampler = NSColorSampler()
        sampler?.show { color in
            sampler = nil
            guard let c = color?.usingColorSpace(.sRGB) else { return print("[PrtScn] color cancelled") }
            let hex = String(format: "#%02X%02X%02X",
                             Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
            print("[PrtScn] color \(hex)")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)
        }
    }

    // OCR the captured area onto the clipboard. No file = selection cancelled with Esc.
    private static func copyText(from url: URL) async {
        defer { try? FileManager.default.removeItem(at: url) }
        guard FileManager.default.fileExists(atPath: url.path) else { return print("[PrtScn] ocr cancelled") }
        StatusMenu.current?.busy = true
        defer { StatusMenu.current?.busy = false }
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        do {
            let lines = try await request.perform(on: url).compactMap { $0.topCandidates(1).first?.string }
            print("[PrtScn] ocr lines=\(lines.count)")
            guard !lines.isEmpty else { return NSSound.beep() }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        } catch {
            print("[PrtScn] ocr failed: \(error)")
            NSSound.beep()
        }
    }

    // Same folder and naming as Cmd+Shift+3; one file per display.
    private func screenshotPaths(name prefix: String = "Screenshot", ext: String = "png") -> [String] {
        let dir = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
            .map { NSString(string: $0).expandingTildeInPath }
            ?? NSHomeDirectory() + "/Desktop"
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let name = "\(dir)/\(prefix) \(f.string(from: Date()))"
        return (1...max(NSScreen.screens.count, 1)).map { $0 == 1 ? "\(name).\(ext)" : "\(name) (\($0)).\(ext)" }
    }
}

// Writes Markup's edited image over the capture on Done.
final class MarkupDelegate: NSObject, NSSharingServiceDelegate {
    var url: URL?

    // Markup centers on this frame; without it, it opens at the screen origin (bottom-left).
    // Use the screen under the mouse, where the area was just captured.
    func sharingService(_ sharingService: NSSharingService, sourceFrameOnScreenForShareItem item: Any) -> NSRect {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return .zero }
        return NSRect(x: frame.midX - 200, y: frame.midY - 150, width: 400, height: 300)
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        print("[PrtScn] markup done items=\(items)")
        guard let url else { return }
        // Markup returns NSItemProviders directly; accept extension-item attachments too.
        let providers = items.flatMap { ($0 as? NSItemProvider).map { [$0] } ?? ($0 as? NSExtensionItem)?.attachments ?? [] }
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else {
            return // No attachment: edited in place, or a plain URL came back.
        }
        let type = provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) ? UTType.png : UTType.image
        _ = provider.loadDataRepresentation(for: type) { data, error in
            guard let data else { return print("[PrtScn] markup load failed: \(String(describing: error))") }
            do { try data.write(to: url); print("[PrtScn] markup saved \(data.count) bytes") }
            catch { print("[PrtScn] markup save failed: \(error)") }
        }
    }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        print("[PrtScn] markup closed: \(error)")
    }
}
