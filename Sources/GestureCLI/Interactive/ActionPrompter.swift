import Foundation
import GestureActions

/// Interactive builder for ONE action type (Strategy). To make a new action configurable
/// from the menu: add a prompter and register it in `ConfigureCommand`.
protocol ActionPrompter {
    /// Label shown in the "what should it do?" menu.
    var title: String { get }
    /// Walks the user through the options. Returns nil if cancelled.
    func prompt(_ terminal: Terminal) -> ActionDefinition?
}

/// Keyboard shortcut, e.g. cmd+w, escape, ctrl+left.
struct ShortcutPrompter: ActionPrompter {
    let title = "Press a keyboard shortcut"

    func prompt(_ terminal: Terminal) -> ActionDefinition? {
        terminal.say("\nType the shortcut, e.g.  escape   cmd+w   cmd+shift+4   ctrl+left   f5")
        while true {
            guard let text = terminal.ask("Shortcut (blank or q = back): ")?
                .trimmingCharacters(in: .whitespaces), !text.isEmpty, text.lowercased() != "q" else { return nil }
            do {
                let s = try ShortcutParser.parse(text)
                return ActionDefinition(type: "keyPress", key: s.key, modifiers: s.modifiers.isEmpty ? nil : s.modifiers)
            } catch {
                terminal.say("\(error)")
            }
        }
    }
}

/// Launch one of the apps installed on this Mac. Type a name (Tab completes it), or
/// type ? to browse the full list page by page.
struct LaunchAppPrompter: ActionPrompter {
    let title = "Launch an installed app"
    let catalog: AppCatalog
    private let pageSize = 20

    func prompt(_ terminal: Terminal) -> ActionDefinition? {
        let apps = catalog.installedApps()
        let names = apps.map { $0.name }
        terminal.say("\n\(apps.count) installed apps. Type the start of a name and press Tab to complete,")
        terminal.say("or type ? to browse the full list. Blank or q to cancel.")
        while true {
            guard let text = terminal.ask("App: ", completions: names)?
                .trimmingCharacters(in: .whitespaces), !text.isEmpty, text.lowercased() != "q" else { return nil }

            if text == "?" {
                if let app = browse(apps, terminal) { return definition(app) }
                continue
            }
            if let exact = apps.first(where: { $0.name.caseInsensitiveCompare(text) == .orderedSame }) {
                return definition(exact)
            }
            var matches = apps.filter { $0.name.lowercased().hasPrefix(text.lowercased()) }
            if matches.isEmpty { matches = apps.filter { $0.name.localizedCaseInsensitiveContains(text) } }
            switch matches.count {
            case 0: terminal.say("No app matches '\(text)'. Type ? to browse all.")
            case 1: terminal.say("-> \(matches[0].name)"); return definition(matches[0])
            default:
                terminal.say("\(matches.count) apps match '\(text)':")
                if let app = browse(matches, terminal) { return definition(app) }
            }
        }
    }

    private func definition(_ app: InstalledApp) -> ActionDefinition {
        ActionDefinition(type: "launchApp", app: app.name)
    }

    /// Paged list of apps; pick by number. n = next page, p = previous page, q = back.
    private func browse(_ apps: [InstalledApp], _ terminal: Terminal) -> InstalledApp? {
        let pages = (apps.count + pageSize - 1) / pageSize
        var page = 0
        while true {
            let range = (page * pageSize)..<min(apps.count, (page + 1) * pageSize)
            terminal.say("\nApps \(range.lowerBound + 1)-\(range.upperBound) of \(apps.count)  (page \(page + 1)/\(pages))")
            for i in range { terminal.say("  \(i + 1)) \(apps[i].name)") }
            guard let a = terminal.ask("Number to pick, n = next, p = previous, q = back: ")?
                .trimmingCharacters(in: .whitespaces).lowercased(), !a.isEmpty, a != "q" else { return nil }
            if a == "n" { page = min(page + 1, pages - 1) }
            else if a == "p" { page = max(page - 1, 0) }
            else if let n = Int(a), (1...apps.count).contains(n) { return apps[n - 1] }
            else { terminal.say("Not valid.") }
        }
    }
}

/// Mouse click at the current cursor position.
struct ClickPrompter: ActionPrompter {
    let title = "Click the mouse (at the cursor)"
    func prompt(_ terminal: Terminal) -> ActionDefinition? { ActionDefinition(type: "click") }
}
