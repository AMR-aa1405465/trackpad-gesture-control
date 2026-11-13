import Foundation

/// Parsed command-line arguments: positionals plus `--flag value` pairs.
public struct Arguments {
    public let positionals: [String]
    public let flags: [String: String]

    public init(_ raw: [String]) {
        var pos: [String] = [], flags: [String: String] = [:]
        var i = 0
        while i < raw.count {
            if raw[i].hasPrefix("--") {
                let key = String(raw[i].dropFirst(2))
                if i + 1 < raw.count, !raw[i + 1].hasPrefix("--") { flags[key] = raw[i + 1]; i += 2 }
                else { flags[key] = "true"; i += 1 }
            } else { pos.append(raw[i]); i += 1 }
        }
        positionals = pos
        self.flags = flags
    }
}

public struct CLIError: Error, CustomStringConvertible {
    public let description: String
    public init(_ message: String) { description = message }
}

/// One terminal command (Command pattern). Add a command = add a type + register it.
public protocol Command {
    var name: String { get }
    var summary: String { get }
    var usage: String { get }
    func run(_ args: Arguments) throws
}
