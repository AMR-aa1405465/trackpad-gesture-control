import Foundation
import GestureCore
import GestureActions
import GestureConfig

/// `gestures`: list every gesture name you can bind.
struct GesturesCommand: Command {
    let name = "gestures"
    let summary = "List available gestures"
    let usage = "gestures"
    func run(_ args: Arguments) throws {
        print("Gestures (combine with any finger count, e.g. 3):")
        GestureKind.allNames.forEach { print("  \($0)") }
    }
}

/// `actions`: list every action type and its parameters.
struct ActionsCommand: Command {
    let factory: ActionFactory
    let name = "actions"
    let summary = "List available action types"
    let usage = "actions"
    func run(_ args: Arguments) throws {
        print("Actions:")
        for (type, usage) in factory.usages.sorted(by: { $0.key < $1.key }) {
            print("  \(type.padding(toLength: 10, withPad: " ", startingAt: 0)) \(usage)")
        }
    }
}

/// `init`: write the example config if none exists.
struct InitCommand: Command {
    let store: ConfigurationStore
    let name = "init"
    let summary = "Create a starter config file"
    let usage = "init"
    func run(_ args: Arguments) throws {
        guard !FileManager.default.fileExists(atPath: store.url.path) else {
            print("Config already exists: \(store.url.path)"); return
        }
        try store.write(GestureConfiguration(bindings: [
            .init(gesture: "swipeLeft", fingers: 4, action: ActionDefinition(type: "keyPress", key: "escape")),
            .init(gesture: "pinchIn", fingers: 3, action: ActionDefinition(type: "launchApp", app: "Safari")),
        ]))
        print("Created \(store.url.path)")
    }
}
