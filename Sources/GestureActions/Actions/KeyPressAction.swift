import CoreGraphics
import Foundation
import GestureCore

/// Simulates a key press (optionally with modifiers). Requires Accessibility permission.
public struct KeyPressAction: Action {
    public let keyName: String
    public let modifiers: [String]
    public var summary: String { "Press key " + (modifiers + [keyName]).joined(separator: "+") }

    public enum KeyError: Error, CustomStringConvertible {
        case unknownKey(String), eventCreationFailed, notTrusted
        public var description: String {
            switch self {
            case .unknownKey(let k): return "Unknown key '\(k)'."
            case .eventCreationFailed: return "Could not create the key event."
            case .notTrusted: return AccessibilityPermission.instructions
            }
        }
    }

    public static var supportedKeys: Set<String> { KeyCodes.supportedKeys }

    private static let flags: [String: CGEventFlags] = [
        "command": .maskCommand, "shift": .maskShift,
        "option": .maskAlternate, "control": .maskControl,
    ]

    public init(keyName: String, modifiers: [String] = []) {
        self.keyName = keyName.lowercased()
        self.modifiers = modifiers.map { $0.lowercased() }
    }

    public func perform() throws {
        guard AccessibilityPermission.isGranted else { throw KeyError.notTrusted }
        guard let code = KeyCodes.code(for: keyName).map({ CGKeyCode($0) }) else { throw KeyError.unknownKey(keyName) }
        let flags = modifiers.compactMap { Self.flags[$0] }.reduce(CGEventFlags()) { $0.union($1) }
        let source = CGEventSource(stateID: .hidSystemState)
        for isDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: isDown) else {
                throw KeyError.eventCreationFailed
            }
            event.flags = flags
            event.post(tap: .cghidEventTap)
            if isDown { usleep(20_000) }  // brief hold so apps register the press
        }
    }
}
