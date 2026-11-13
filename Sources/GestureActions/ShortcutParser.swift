import Foundation

/// Parses text like "cmd+shift+4" into a key name and modifier list.
public enum ShortcutParser {
    public struct Shortcut: Equatable {
        public let key: String
        public let modifiers: [String]
    }

    public enum ParseError: Error, CustomStringConvertible {
        case empty, unknownKey(String), unknownModifier(String)
        public var description: String {
            switch self {
            case .empty: return "Type a shortcut like cmd+w or escape."
            case .unknownKey(let k): return "Unknown key '\(k)'. Examples: a, 4, f5, escape, left, space."
            case .unknownModifier(let m): return "Unknown modifier '\(m)'. Use cmd, shift, opt, ctrl."
            }
        }
    }

    private static let aliases = ["cmd": "command", "command": "command", "shift": "shift",
                                  "opt": "option", "alt": "option", "option": "option",
                                  "ctrl": "control", "control": "control", "esc": "escape"]

    public static func parse(_ text: String) throws -> Shortcut {
        let parts = text.lowercased().split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        guard var key = parts.last, !key.isEmpty else { throw ParseError.empty }
        var mods: [String] = []
        for m in parts.dropLast() {
            guard let canonical = aliases[m], canonical != "escape" else { throw ParseError.unknownModifier(m) }
            mods.append(canonical)
        }
        if key == "esc" { key = "escape" }
        guard KeyPressAction.supportedKeys.contains(key) else { throw ParseError.unknownKey(key) }
        return Shortcut(key: key, modifiers: mods)
    }
}
