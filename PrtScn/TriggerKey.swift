import AppKit

enum TriggerKey: String, CaseIterable, Identifiable {
    // Raw values are persisted IDs.
    case fn = "Fn", ctrl = "Ctrl", opt = "Opt", cmd = "Cmd", shift = "Shift"
    // No right Control: Apple keyboards don't have one.
    case rightOpt = "R Opt", rightCmd = "R Cmd", rightShift = "R Shift"
    var id: Self { self }

    static let fnKeyCode: UInt16 = 0x3F

    init?(keyCode: UInt16) {
        switch keyCode {
        case Self.fnKeyCode: self = .fn
        case 0x3A: self = .opt
        case 0x3D: self = .rightOpt
        case 0x3B: self = .ctrl
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
        case .ctrl: .control
        case .cmd, .rightCmd: .command
        case .shift, .rightShift: .shift
        }
    }

    // Device-dependent bits (NX_DEVICE*KEYMASK) tell left from right.
    var deviceMask: UInt {
        switch self {
        case .fn: NSEvent.ModifierFlags.function.rawValue
        case .opt: 0x20
        case .rightOpt: 0x40
        case .ctrl: 0x01
        case .cmd: 0x08
        case .rightCmd: 0x10
        case .shift: 0x02
        case .rightShift: 0x04
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
        case .rightOpt, .rightCmd, .rightShift: "Right"
        }
    }

    var glyph: String {
        switch self {
        case .fn: "fn"
        case .ctrl: "⌃"
        case .opt, .rightOpt: "⌥"
        case .cmd, .rightCmd: "⌘"
        case .shift, .rightShift: "⇧"
        }
    }
}
