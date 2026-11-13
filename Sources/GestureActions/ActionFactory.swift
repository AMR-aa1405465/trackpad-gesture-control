import Foundation
import GestureCore

/// Describes an action as data (comes from the config file).
public struct ActionDefinition: Codable, Equatable {
    public let type: String
    public let app: String?
    public let key: String?
    public let modifiers: [String]?

    /// Short human-readable form for CLI listings, e.g. "keyPress cmd+w" or "launchApp Safari".
    public var displayText: String {
        switch type {
        case "keyPress": return "shortcut " + ((modifiers ?? []) + [key ?? "?"]).joined(separator: "+")
        case "launchApp": return "launch " + (app ?? "?")
        default: return type
        }
    }

    public init(type: String, app: String? = nil, key: String? = nil, modifiers: [String]? = nil) {
        self.type = type
        self.app = app
        self.key = key
        self.modifiers = modifiers
    }
}

public enum ActionFactoryError: Error, CustomStringConvertible {
    case unknownType(String)
    case missingField(type: String, field: String)

    public var description: String {
        switch self {
        case .unknownType(let t): return "Unknown action type '\(t)'."
        case .missingField(let t, let f): return "Action '\(t)' requires field '\(f)'."
        }
    }
}

/// Registry-based factory (Factory + Open/Closed principle): add a new action type by
/// registering a builder; existing code stays untouched.
public final class ActionFactory {
    public typealias Builder = (ActionDefinition) throws -> Action
    private var builders: [String: Builder] = [:]
    /// type name -> usage text, shown by the CLI (`actions` command).
    public private(set) var usages: [String: String] = [:]

    public init() {}

    public func register(_ type: String, usage: String, builder: @escaping Builder) {
        builders[type] = builder
        usages[type] = usage
    }

    public func make(_ definition: ActionDefinition) throws -> Action {
        guard let builder = builders[definition.type] else {
            throw ActionFactoryError.unknownType(definition.type)
        }
        return try builder(definition)
    }

    /// Factory pre-loaded with every built-in action.
    public static func standard() -> ActionFactory {
        let factory = ActionFactory()
        factory.register("launchApp", usage: "Open an app.  --app <Name>") { def in
            guard let app = def.app else { throw ActionFactoryError.missingField(type: def.type, field: "app") }
            return LaunchAppAction(appName: app)
        }
        factory.register("keyPress", usage: "Press a key.  --key <name> [--mod command,shift,option,control]") { def in
            guard let key = def.key else { throw ActionFactoryError.missingField(type: def.type, field: "key") }
            return KeyPressAction(keyName: key, modifiers: def.modifiers ?? [])
        }
        factory.register("click", usage: "Left-click at the cursor.") { _ in MouseClickAction() }
        return factory
    }
}
