import Foundation
import GestureCore
import GestureActions

/// On-disk shape of the config file.
///
///     { "bindings": [
///         { "gesture": "pinchIn", "fingers": 3, "action": { "type": "launchApp", "app": "Safari" } },
///         { "gesture": "swipeLeft", "fingers": 3, "action": { "type": "keyPress", "key": "escape" } }
///     ] }
public struct GestureConfiguration: Codable, Equatable {
    public struct Binding: Codable, Equatable {
        public let gesture: String
        public let fingers: Int
        public let action: ActionDefinition

        public init(gesture: String, fingers: Int, action: ActionDefinition) {
            self.gesture = gesture
            self.fingers = fingers
            self.action = action
        }
    }

    /// A keyboard shortcut trigger, e.g. { "shortcut": "cmd+t", "action": { ... } }.
    public struct HotkeyBinding: Codable, Equatable {
        public let shortcut: String
        public let action: ActionDefinition

        public init(shortcut: String, action: ActionDefinition) {
            self.shortcut = shortcut
            self.action = action
        }
    }

    public var bindings: [Binding]
    public var hotkeys: [HotkeyBinding]

    public init(bindings: [Binding], hotkeys: [HotkeyBinding] = []) {
        self.bindings = bindings
        self.hotkeys = hotkeys
    }

    // `hotkeys` is optional in the file so configs written before it existed still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        bindings = try c.decodeIfPresent([Binding].self, forKey: .bindings) ?? []
        hotkeys = try c.decodeIfPresent([HotkeyBinding].self, forKey: .hotkeys) ?? []
    }

    private enum CodingKeys: String, CodingKey { case bindings, hotkeys }
}

public enum ConfigError: Error, CustomStringConvertible {
    case unknownGesture(String)
    case badShortcut(String, String)
    public var description: String {
        switch self {
        case .unknownGesture(let g): return "Unknown gesture '\(g)'."
        case .badShortcut(let s, let why): return "Bad shortcut '\(s)': \(why)"
        }
    }
}

/// Loads a configuration file and turns it into ready-to-use bindings.
public final class ConfigurationLoader {
    private let factory: ActionFactory

    public init(factory: ActionFactory = .standard()) { self.factory = factory }

    public static var defaultPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/trackpad-gesture-control/config.json")
    }

    public func load(from url: URL) throws -> [GestureTrigger: Action] {
        let data = try Data(contentsOf: url)
        return try bindings(from: JSONDecoder().decode(GestureConfiguration.self, from: data))
    }

    /// Keyboard-shortcut triggers from the config, keyed by canonical `Hotkey`.
    public func hotkeyBindings(from config: GestureConfiguration) throws -> [Hotkey: Action] {
        var result: [Hotkey: Action] = [:]
        for binding in config.hotkeys {
            do {
                let s = try ShortcutParser.parse(binding.shortcut)
                result[Hotkey(key: s.key, modifiers: s.modifiers)] = try factory.make(binding.action)
            } catch let error as ShortcutParser.ParseError {
                throw ConfigError.badShortcut(binding.shortcut, "\(error)")
            }
        }
        return result
    }

    public func bindings(from config: GestureConfiguration) throws -> [GestureTrigger: Action] {
        var result: [GestureTrigger: Action] = [:]
        for binding in config.bindings {
            guard let kind = GestureKind(name: binding.gesture) else {
                throw ConfigError.unknownGesture(binding.gesture)
            }
            result[GestureTrigger(kind: kind, fingerCount: binding.fingers)] = try factory.make(binding.action)
        }
        return result
    }
}

/// Reads/writes the config file and edits bindings (used by the CLI `bindings` commands).
public final class ConfigurationStore {
    public let url: URL

    public init(url: URL = ConfigurationLoader.defaultPath) { self.url = url }

    public func read() throws -> GestureConfiguration {
        guard FileManager.default.fileExists(atPath: url.path) else { return GestureConfiguration(bindings: []) }
        return try JSONDecoder().decode(GestureConfiguration.self, from: Data(contentsOf: url))
    }

    public func write(_ config: GestureConfiguration) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url)
    }

    /// Adds or replaces the binding for the same gesture + finger count.
    public func upsert(_ binding: GestureConfiguration.Binding) throws {
        var config = try read()
        config.bindings.removeAll { $0.gesture == binding.gesture && $0.fingers == binding.fingers }
        config.bindings.append(binding)
        try write(config)
    }

    /// Adds or replaces the keyboard-shortcut binding with the same canonical shortcut.
    public func upsertHotkey(_ binding: GestureConfiguration.HotkeyBinding) throws {
        var config = try read()
        config.hotkeys.removeAll { $0.shortcut == binding.shortcut }
        config.hotkeys.append(binding)
        try write(config)
    }

    @discardableResult
    public func removeHotkey(shortcut: String) throws -> Bool {
        var config = try read()
        let before = config.hotkeys.count
        config.hotkeys.removeAll { $0.shortcut == shortcut }
        try write(config)
        return config.hotkeys.count < before
    }

    @discardableResult
    public func remove(gesture: String, fingers: Int) throws -> Bool {
        var config = try read()
        let before = config.bindings.count
        config.bindings.removeAll { $0.gesture == gesture && $0.fingers == fingers }
        try write(config)
        return config.bindings.count < before
    }
}
