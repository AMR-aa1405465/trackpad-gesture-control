import Foundation

/// A keyboard shortcut used as a TRIGGER (e.g. command+t), as opposed to a gesture.
public struct Hotkey: Hashable {
    public let key: String
    /// Canonical, sorted: command, control, option, shift.
    public let modifiers: [String]

    public init(key: String, modifiers: [String]) {
        self.key = key.lowercased()
        let set = Set(modifiers.map { $0.lowercased() })
        self.modifiers = KeyCodes.modifierOrder.filter { set.contains($0) }
    }

    /// Stable text form used in the config file and the menu, e.g. "command+shift+t".
    public var text: String { (modifiers + [key]).joined(separator: "+") }

    /// Bare letters/digits would block normal typing, so a trigger needs a modifier
    /// (function keys are allowed on their own).
    public var isSafeToCapture: Bool {
        !modifiers.isEmpty || (key.hasPrefix("f") && Int(key.dropFirst()) != nil)
    }
}

public struct HotkeyFailure {
    public let hotkey: Hotkey
    public let reason: String
    public init(hotkey: Hotkey, reason: String) {
        self.hotkey = hotkey
        self.reason = reason
    }
}
