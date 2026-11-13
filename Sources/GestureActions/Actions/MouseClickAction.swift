import CoreGraphics
import GestureCore

/// Simulates a left mouse click at the current cursor position. Requires Accessibility permission.
public struct MouseClickAction: Action {
    public var summary: String { "Mouse click" }
    public enum ClickError: Error, CustomStringConvertible {
        case eventCreationFailed, notTrusted
        public var description: String {
            switch self {
            case .eventCreationFailed: return "Could not create the mouse event."
            case .notTrusted: return AccessibilityPermission.instructions
            }
        }
    }

    public init() {}

    public func perform() throws {
        guard AccessibilityPermission.isGranted else { throw ClickError.notTrusted }
        let location = CGEvent(source: nil)?.location ?? .zero
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            guard let event = CGEvent(
                mouseEventSource: nil, mouseType: type, mouseCursorPosition: location, mouseButton: .left
            ) else { throw ClickError.eventCreationFailed }
            event.post(tap: .cghidEventTap)
        }
    }
}
