import AppKit

enum Action: String, CaseIterable {
    // Raw value (case name) is the persisted ID; title is display-only.
    case screenFile, screenClipboard, areaFile, areaClipboard, options

    var title: String {
        switch self {
        case .screenFile: "Capture screen to file"
        case .screenClipboard: "Capture screen to clipboard"
        case .areaFile: "Capture area to file"
        case .areaClipboard: "Capture area to clipboard"
        case .options: "Record"
        }
    }

    func run() {
        print("[PrtScn] run \(self)")
        switch self {
        case .screenFile: capture(screenshotPaths())
        case .screenClipboard: capture(["-c"])
        case .areaFile: capture(["-i", screenshotPaths()[0]])
        case .areaClipboard: capture(["-ic"])
        case .options: NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app"))
        }
    }

    private func capture(_ args: [String]) {
        print("[PrtScn] screencapture \(args)")
        do { _ = try Process.run(URL(fileURLWithPath: "/usr/sbin/screencapture"), arguments: args) }
        catch { print("[PrtScn] screencapture failed: \(error)") }
    }

    // Same folder and naming as Cmd+Shift+3; one file per display.
    private func screenshotPaths() -> [String] {
        let dir = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location")
            .map { NSString(string: $0).expandingTildeInPath }
            ?? NSHomeDirectory() + "/Desktop"
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let name = "\(dir)/Screenshot \(f.string(from: Date()))"
        return (1...max(NSScreen.screens.count, 1)).map { $0 == 1 ? "\(name).png" : "\(name) (\($0)).png" }
    }
}
