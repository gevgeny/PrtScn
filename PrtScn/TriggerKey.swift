import AppKit

enum TriggerKey: String, CaseIterable, Identifiable {
    // Raw values are persisted IDs.
    case fn = "Fn", ctrl = "Ctrl", opt = "Opt", cmd = "Cmd", shift = "Shift"
    // Right Control: external keyboards only; Apple keyboards don't have one.
    case rightOpt = "R Opt", rightCmd = "R Cmd", rightShift = "R Shift", rightCtrl = "R Ctrl"
    // Top row as pressed without Fn, i.e. its media/system action, which the action replaces.
    case f1 = "F1", f2 = "F2", f3 = "F3", f4 = "F4", f5 = "F5", f6 = "F6"
    case f7 = "F7", f8 = "F8", f9 = "F9", f10 = "F10", f11 = "F11", f12 = "F12"
    var id: Self { self }

    static let fnKeyCode: UInt16 = 0x3F
    // keyDown the Globe key sends on release ("Press Globe key to" action). Part of an Fn tap, not typing.
    static let globeKeyCode: Int64 = 179

    init?(keyCode: UInt16) {
        switch keyCode {
        case Self.fnKeyCode: self = .fn
        case 0x3A: self = .opt
        case 0x3D: self = .rightOpt
        case 0x3B: self = .ctrl
        case 0x3E: self = .rightCtrl
        case 0x37: self = .cmd
        case 0x36: self = .rightCmd
        case 0x38: self = .shift
        case 0x3C: self = .rightShift
        default: return nil
        }
    }

    var family: NSEvent.ModifierFlags {
        switch self {
        case .fn: .function
        case .opt, .rightOpt: .option
        case .ctrl, .rightCtrl: .control
        case .cmd, .rightCmd: .command
        case .shift, .rightShift: .shift
        default: []
        }
    }

    // What a top-row key sends without Fn: its keycap symbol, NX_SYSDEFINED aux key types and/or special
    // keyDown codes. Lists cover current and older MacBooks (F4 Launchpad, F5/F6 keyboard backlight).
    // Nil for modifiers.
    var media: (symbol: String, nx: [Int], keyCodes: [Int64])? {
        switch self {
        case .f1: ("sun.min", [3], [145])
        case .f2: ("sun.max", [2], [144])
        case .f3: ("rectangle.3.group", [], [160])
        case .f4: ("magnifyingglass", [], [177, 131])
        case .f5: ("mic", [22], [176])
        case .f6: ("moon", [21], [178])
        case .f7: ("backward", [20, 18], [])
        case .f8: ("playpause", [16], [])
        case .f9: ("forward", [19, 17], [])
        case .f10: ("speaker.slash", [7], [])
        case .f11: ("speaker.wave.1", [1], [])
        case .f12: ("speaker.wave.3", [0], [])
        default: nil
        }
    }

    // Device-dependent bits (NX_DEVICE*KEYMASK) tell left from right.
    var deviceMask: UInt {
        switch self {
        case .fn: NSEvent.ModifierFlags.function.rawValue
        case .opt: 0x20
        case .rightOpt: 0x40
        case .ctrl: 0x01
        case .rightCtrl: 0x2000
        case .cmd: 0x08
        case .rightCmd: 0x10
        case .shift: 0x02
        case .rightShift: 0x04
        default: 0
        }
    }
}

// Key -> action assignments, persisted.
enum Bindings {
    static var all: [TriggerKey: Action] {
        get {
            let raw = UserDefaults.standard.dictionary(forKey: "bindings") as? [String: String] ?? [:]
            return Dictionary(uniqueKeysWithValues: raw.compactMap { k, v in
                TriggerKey(rawValue: k).flatMap { key in Action(rawValue: v).map { (key, $0) } }
            })
        }
        set {
            UserDefaults.standard.set(Dictionary(uniqueKeysWithValues: newValue.map { ($0.rawValue, $1.rawValue) }), forKey: "bindings")
            Permission.requestMissing() // Ask as soon as a key needs it.
            KeyMonitor.start()
        }
    }
}

extension TriggerKey {
    // Badge text: a small side word plus the key glyph.
    var side: String? {
        switch self {
        case .fn: nil
        case .ctrl, .opt, .cmd, .shift: "Left"
        case .rightOpt, .rightCmd, .rightShift, .rightCtrl: "Right"
        default: rawValue
        }
    }

    // Shown as N/A in the menu when false. Checked when the menu opens.
    var available: Bool { self != .rightCtrl || KeyMonitor.hasNonAppleKeyboard() }

    var glyph: String {
        switch self {
        case .fn: "fn"
        case .ctrl, .rightCtrl: "⌃"
        case .opt, .rightOpt: "⌥"
        case .cmd, .rightCmd: "⌘"
        case .shift, .rightShift: "⇧"
        default: rawValue
        }
    }
}
