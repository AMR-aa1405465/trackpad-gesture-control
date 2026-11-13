import Foundation

public enum SwipeDirection: String, Codable, CaseIterable {
    case left, right, up, down
}

/// The kind of gesture, independent of how many fingers perform it.
public enum GestureKind: Hashable, Codable {
    case pinchIn
    case pinchOut
    case swipe(SwipeDirection)
}

extension GestureKind: CustomStringConvertible {
    /// Stable string form used in config files, e.g. "pinchIn", "swipeLeft".
    public var description: String {
        switch self {
        case .pinchIn: return "pinchIn"
        case .pinchOut: return "pinchOut"
        case .swipe(let d): return "swipe" + d.rawValue.prefix(1).uppercased() + d.rawValue.dropFirst()
        }
    }

    /// Every gesture name accepted in config files and CLI arguments.
    public static var allNames: [String] {
        ["pinchIn", "pinchOut"] + SwipeDirection.allCases.map { GestureKind.swipe($0).description }
    }

    public init?(name: String) {
        switch name {
        case "pinchIn": self = .pinchIn
        case "pinchOut": self = .pinchOut
        default:
            guard name.hasPrefix("swipe"),
                  let dir = SwipeDirection(rawValue: name.dropFirst(5).lowercased())
            else { return nil }
            self = .swipe(dir)
        }
    }
}

/// A fully-described gesture occurrence: what happened and with how many fingers.
public struct GestureEvent: Hashable {
    public let kind: GestureKind
    public let fingerCount: Int

    public init(kind: GestureKind, fingerCount: Int) {
        self.kind = kind
        self.fingerCount = fingerCount
    }
}

/// The lookup key that binds a gesture to an action (e.g. "3-finger pinchIn").
public struct GestureTrigger: Hashable {
    public let kind: GestureKind
    public let fingerCount: Int

    public init(kind: GestureKind, fingerCount: Int) {
        self.kind = kind
        self.fingerCount = fingerCount
    }

    public init(_ event: GestureEvent) {
        self.init(kind: event.kind, fingerCount: event.fingerCount)
    }
}
