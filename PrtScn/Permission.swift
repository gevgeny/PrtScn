import AppKit

// Permissions the assigned keys need. Requested when a key that needs them is assigned,
// not later on first use (e.g. Screen Recording on the first screenshot).
enum Permission: CaseIterable {
    case inputMonitoring, screenRecording

    // Posted when the set of missing permissions may have changed (icon, menu header refresh).
    static let changed = Notification.Name("PermissionChanged")

    var title: String {
        switch self {
        case .inputMonitoring: "Input Monitoring"
        case .screenRecording: "Screen Recording"
        }
    }

    // Live checks; System Settings changes show up without a restart.
    var granted: Bool {
        switch self {
        case .inputMonitoring: CGPreflightListenEventAccess()
        case .screenRecording: CGPreflightScreenCaptureAccess()
        }
    }

    var settingsURL: URL {
        let pane = switch self {
        case .inputMonitoring: "Privacy_ListenEvent"
        case .screenRecording: "Privacy_ScreenCapture"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
    }

    // Any key -> Input Monitoring; a capture action -> Screen Recording.
    static var needed: [Permission] {
        let actions = Bindings.all.values
        var needed: [Permission] = []
        if !actions.isEmpty { needed.append(.inputMonitoring) }
        if actions.contains(where: \.needsScreenRecording) { needed.append(.screenRecording) }
        return needed
    }

    static var missing: [Permission] { needed.filter { !$0.granted } }

    // System prompt only, like Babbler: it adds PrtScn to the System Settings list (switched off) and its
    // "Open System Settings" button goes straight there. macOS shows it once; later calls do nothing.
    func request() {
        print("[PrtScn] requesting \(title)")
        UserDefaults.standard.set(true, forKey: askedKey)
        switch self {
        case .inputMonitoring: CGRequestListenEventAccess()
        case .screenRecording: CGRequestScreenCaptureAccess()
        }
    }

    // Menu button: the prompt if never shown, else Settings directly. Never both at once.
    func grant() {
        if UserDefaults.standard.bool(forKey: askedKey) { NSWorkspace.shared.open(settingsURL) } else { request() }
    }

    private var askedKey: String { "asked.\(self)" }

    static func requestMissing() {
        missing.forEach { $0.request() }
        NotificationCenter.default.post(name: changed, object: nil)
    }
}

extension Action {
    var needsScreenRecording: Bool {
        switch self {
        case .pickColor: false // System loupe handles it itself.
        default: true
        }
    }
}
