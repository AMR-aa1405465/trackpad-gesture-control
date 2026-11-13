import Foundation

/// The CLI engine: finds the command for argv and runs it. Also renders help.
public final class CommandRouter {
    private var commands: [String: Command] = [:]
    private var order: [String] = []
    /// Command used when no arguments are given.
    public var defaultCommand: String?

    public init() {}

    public func register(_ command: Command) {
        commands[command.name] = command
        order.append(command.name)
    }

    public func run(_ argv: [String]) -> Int32 {
        guard let name = argv.first ?? defaultCommand, name != "help", name != "--help" else { printHelp(); return 0 }
        guard let command = commands[name] else {
            printError("Unknown command '\(name)'."); printHelp(); return 2
        }
        do {
            try command.run(Arguments(argv.isEmpty ? [] : Array(argv.dropFirst())))
            return 0
        } catch {
            printError("\(error)\nUsage: \(command.usage)")
            return 1
        }
    }

    private func printHelp() {
        print("trackpad-gestures: bind trackpad gestures to actions.\n\nCommands:")
        for case let (name, c?) in order.map({ ($0, commands[$0]) }) {
            print("  \(name.padding(toLength: 10, withPad: " ", startingAt: 0)) \(c.summary)")
        }
        print("\nWith no command, 'start' runs. Run 'trackpad-gestures <command>' with the arguments shown by that command's usage.")
    }

    private func printError(_ message: String) {
        FileHandle.standardError.write(Data("Error: \(message)\n".utf8))
    }
}
