import Foundation
import GestureCore
import GestureActions
import GestureConfig

/// `bindings list | add | remove`: manage gesture -> action bindings from the terminal.
struct BindingsCommand: Command {
    let store: ConfigurationStore
    let factory: ActionFactory
    let name = "bindings"
    let summary = "List, add or remove gesture bindings"
    let usage = """
    bindings list
           bindings add <gesture> <fingers> <actionType> [--app Name] [--key name] [--mod command,shift]
           bindings remove <gesture> <fingers>
           bindings addkey <shortcut> <actionType> [--app Name] [--key name] [--mod command,shift]
           bindings removekey <shortcut>
    """

    func run(_ args: Arguments) throws {
        let p = args.positionals
        switch p.first {
        case "list", nil:
            let config = try store.read()
            if config.bindings.isEmpty && config.hotkeys.isEmpty { print("No bindings. Add one with 'bindings add'."); return }
            for b in config.bindings {
                print("\(b.fingers)-finger \(b.gesture) -> \(b.action.displayText)")
            }
            for h in config.hotkeys { print("shortcut \(h.shortcut) -> \(h.action.displayText)") }
        case "addkey":
            guard p.count >= 3 else { throw CLIError("Missing arguments.") }
            let s = try ShortcutParser.parse(p[1])
            let hotkey = Hotkey(key: s.key, modifiers: s.modifiers)
            guard hotkey.isSafeToCapture else { throw CLIError("Add a modifier (cmd, ctrl, opt, shift).") }
            let def = ActionDefinition(
                type: p[2], app: args.flags["app"], key: args.flags["key"],
                modifiers: args.flags["mod"]?.split(separator: ",").map(String.init))
            _ = try factory.make(def)
            try store.upsertHotkey(.init(shortcut: hotkey.text, action: def))
            print("Bound shortcut \(hotkey.text) -> \(def.displayText)")
        case "removekey":
            guard p.count >= 2 else { throw CLIError("Missing arguments.") }
            let s = try ShortcutParser.parse(p[1])
            print(try store.removeHotkey(shortcut: Hotkey(key: s.key, modifiers: s.modifiers).text) ? "Removed." : "No such shortcut.")
        case "add":
            guard p.count >= 4, let fingers = Int(p[2]), fingers > 0 else { throw CLIError("Missing arguments.") }
            guard GestureKind(name: p[1]) != nil else {
                throw CLIError("Unknown gesture '\(p[1])'. Try: \(GestureKind.allNames.joined(separator: ", "))")
            }
            let def = ActionDefinition(
                type: p[3], app: args.flags["app"], key: args.flags["key"],
                modifiers: args.flags["mod"]?.split(separator: ",").map(String.init))
            _ = try factory.make(def)  // validate before saving
            try store.upsert(.init(gesture: p[1], fingers: fingers, action: def))
            print("Bound \(fingers)-finger \(p[1]) -> \(p[3])")
        case "remove":
            guard p.count >= 3, let fingers = Int(p[2]) else { throw CLIError("Missing arguments.") }
            print(try store.remove(gesture: p[1], fingers: fingers) ? "Removed." : "No such binding.")
        default:
            throw CLIError("Unknown subcommand '\(p[0])'.")
        }
    }
}
