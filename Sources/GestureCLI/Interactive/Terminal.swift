import Foundation
import CEditline

/// Abstraction over the terminal so menus can be tested with scripted input.
protocol Terminal {
    func say(_ text: String)
    /// Returns nil on end of input (Ctrl-D). `completions` enables Tab completion.
    func ask(_ prompt: String, completions: [String]) -> String?
}

extension Terminal {
    func ask(_ prompt: String) -> String? { ask(prompt, completions: []) }

    /// Numbered menu. Returns the chosen index, or nil if the user typed 'q' / blank / EOF.
    func choose(_ title: String, options: [String]) -> Int? {
        say("\n\(title)")
        for (i, o) in options.enumerated() { say("  \(i + 1)) \(o)") }
        while true {
            guard let answer = ask("Choose 1-\(options.count) (q = back): ")?
                .trimmingCharacters(in: .whitespaces).lowercased(), !answer.isEmpty, answer != "q"
            else { return nil }
            if let n = Int(answer), (1...options.count).contains(n) { return n - 1 }
            say("Not a valid choice.")
        }
    }
}

struct StandardTerminal: Terminal {
    func say(_ text: String) { print(text); fflush(stdout) }

    func ask(_ prompt: String, completions: [String]) -> String? {
        // Piped input (scripts/tests): plain line reading.
        guard isatty(STDIN_FILENO) != 0 else {
            print(prompt, terminator: ""); fflush(stdout)
            return readLine()
        }
        let owned = completions.map { strdup($0) }
        defer { owned.forEach { free($0) } }
        let items: [UnsafePointer<CChar>?] = owned.map { UnsafePointer($0) }
        guard let raw = ce_readline(prompt, items, Int32(items.count)) else { return nil }
        defer { free(raw) }
        return String(cString: raw)
    }
}
