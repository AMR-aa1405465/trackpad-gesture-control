import Foundation
import GestureCore
import GestureActions
import GestureConfig

/// `start` (the default): listens for gestures AND shows the configuration menu in the same
/// process. Changes made in the menu apply immediately, no restart needed.
struct StartCommand: Command {
    let session: GestureSession
    let agent: LaunchAgentManager
    let prompters: [ActionPrompter]
    let name = "start"
    let summary = "Listen for gestures and configure them live (default)"
    let usage = "start   (or run with no command; prefix with 'debug' to log gestures)"

    private let terminal: Terminal = StandardTerminal()

    init(session: GestureSession, agent: LaunchAgentManager, prompters: [ActionPrompter]) {
        self.session = session
        self.agent = agent
        self.prompters = prompters
    }

    func run(_ args: Arguments) throws {
        try session.start()
        if !session.isListening {
            terminal.say("The background service is already listening. This menu edits the same config;")
            terminal.say("changes apply automatically within a couple of seconds.")
        } else if !AccessibilityPermission.request() {
            terminal.say("\nWARNING: " + AccessibilityPermission.instructions + "\n")
        }
        if session.debug {
            terminal.say("DEBUG MODE. Config: \(session.store.url.path)")
            terminal.say("Gestures and actions are logged as [gesture] lines; menu changes apply instantly.")
        }

        // The menu blocks on keyboard input, so it runs on its own thread while the main
        // thread keeps the run loop alive for the OS input callbacks.
        let menu = Thread { self.menuLoop() }  // never exits the process: only Ctrl-C quits
        menu.start()
        MainLoop.run()
    }

    private var mainOptions: [String] {
        ["Show bindings", "Add or change a gesture binding", "Add or change a keyboard-shortcut binding",
         "Remove a binding",
         "Start at login: \(agent.isInstalled ? "ON" : "OFF")  (select to switch)"]
    }

    /// Runs until input is closed. Blank Enter / 'q' just redraws the menu; only Ctrl-C quits.
    private func menuLoop() {
        while true {
            terminal.say("\nMain menu")
            for (i, o) in mainOptions.enumerated() { terminal.say("  \(i + 1)) \(o)") }
            guard let answer = terminal.ask("Choose 1-\(mainOptions.count)  (Ctrl-C quits): ") else {
                terminal.say("Input closed. Still listening; press Ctrl-C to quit.")
                return
            }
            guard let n = Int(answer.trimmingCharacters(in: .whitespaces)),
                  (1...mainOptions.count).contains(n) else { continue }
            do {
                switch n {
                case 1: try show()
                case 2: try add()
                case 3: try addHotkey()
                case 4: try remove()
                default: try toggleAutostart()
                }
            } catch {
                terminal.say("Error: \(error)")
            }
        }
    }

    private func toggleAutostart() throws {
        if agent.isInstalled {
            try agent.disable()
            terminal.say("\nStart at login: OFF. The background listener was stopped.")
        } else {
            if agent.usesDebugBuild { terminal.say("\nNote: this is a debug build; use ./trackpad (release) for login use.") }
            try agent.enable()
            terminal.say("\nStart at login: ON. A background listener now runs and starts at every login.")
            terminal.say("Give Accessibility permission to this program so shortcuts/clicks work at login:")
            terminal.say("  \(agent.executablePath)")
            terminal.say("(System Settings > Privacy & Security > Accessibility > + , Cmd+Shift+G to paste the path)")
            terminal.say("Close this menu (Ctrl-C) so only the background listener handles gestures.")
        }
    }

    private func show() throws {
        let config = try session.store.read()
        if config.bindings.isEmpty && config.hotkeys.isEmpty { terminal.say("\nNo bindings yet."); return }
        terminal.say("\nCurrent bindings (active now):")
        for b in config.bindings { terminal.say("  gesture  \(b.fingers)-finger \(b.gesture)  ->  \(b.action.displayText)") }
        for h in config.hotkeys { terminal.say("  shortcut \(h.shortcut)  ->  \(h.action.displayText)") }
    }

    private func add() throws {
        guard let (gesture, fingers) = pickGesture() else { return }
        guard let i = terminal.choose("What should \(fingers)-finger \(gesture) do?", options: prompters.map { $0.title }),
              let action = prompters[i].prompt(terminal) else { return }
        try session.store.upsert(.init(gesture: gesture, fingers: fingers, action: action))
        try session.reload()
        terminal.say("\nSaved and active: \(fingers)-finger \(gesture) -> \(action.displayText)")
    }

    private func remove() throws {
        let config = try session.store.read()
        var entries: [(label: String, delete: () throws -> Void)] = []
        for b in config.bindings {
            entries.append(("gesture  \(b.fingers)-finger \(b.gesture) -> \(b.action.displayText)",
                            { try self.session.store.remove(gesture: b.gesture, fingers: b.fingers) }))
        }
        for h in config.hotkeys {
            entries.append(("shortcut \(h.shortcut) -> \(h.action.displayText)",
                            { try self.session.store.removeHotkey(shortcut: h.shortcut) }))
        }
        guard !entries.isEmpty else { terminal.say("\nNothing to remove."); return }
        guard let i = terminal.choose("Remove which binding?", options: entries.map { $0.label }) else { return }
        try entries[i].delete()
        try session.reload()
        terminal.say("Removed.")
    }

    /// Keyboard shortcut (e.g. cmd+t) as the trigger instead of a gesture.
    private func addHotkey() throws {
        terminal.say("\nType the shortcut that should TRIGGER an action, e.g.  cmd+t   cmd+shift+space   ctrl+opt+f")
        terminal.say("Note: while the listener runs, this shortcut is taken over system-wide (other apps won't get it).")
        var hotkey: Hotkey?
        while hotkey == nil {
            guard let text = terminal.ask("Trigger shortcut (blank or q = back): ")?
                .trimmingCharacters(in: .whitespaces), !text.isEmpty, text.lowercased() != "q" else { return }
            do {
                let s = try ShortcutParser.parse(text)
                let candidate = Hotkey(key: s.key, modifiers: s.modifiers)
                if candidate.isSafeToCapture { hotkey = candidate }
                else { terminal.say("Add a modifier (cmd, ctrl, opt, shift); a bare key would block typing.") }
            } catch {
                terminal.say("\(error)")
            }
        }
        guard let trigger = hotkey,
              let i = terminal.choose("What should \(trigger.text) do?", options: prompters.map { $0.title }),
              let action = prompters[i].prompt(terminal) else { return }
        try session.store.upsertHotkey(.init(shortcut: trigger.text, action: action))
        try session.reload()
        terminal.say("\nSaved: \(trigger.text) -> \(action.displayText)")
        if let failure = session.hotkeyFailures.first(where: { $0.hotkey == trigger }) {
            terminal.say("WARNING: macOS would not register \(trigger.text): \(failure.reason). Pick a different shortcut.")
        } else if !session.isListening {
            terminal.say("(The background service will pick this up within a couple of seconds.)")
        } else {
            terminal.say("Active now.")
        }
    }

    /// Pick a gesture from the list, or perform it live on the trackpad.
    private func pickGesture() -> (String, Int)? {
        guard let how = terminal.choose("Which gesture?", options: [
            "Perform it now on the trackpad (auto-detect)", "Pick from a list",
        ]) else { return nil }

        if how == 0, !session.isListening {
            terminal.say("\nAuto-detect is unavailable while the background service owns the trackpad. Pick from the list.")
            return nil
        }
        if how == 0 {
            terminal.say("\nPerform the gesture now (waiting up to 20s; it will not trigger its action)...")
            if let e = session.captureGesture() {
                terminal.say("Detected: \(e.fingerCount)-finger \(e.kind)")
                return (e.kind.description, e.fingerCount)
            }
            terminal.say("Nothing detected. Try again or pick from the list.")
            return nil
        }

        // Gesture list -> finger count. 'q' at the finger prompt goes back to the gesture list.
        while true {
            guard let g = terminal.choose("Gesture", options: GestureKind.allNames) else { return nil }
            while true {
                guard let text = terminal.ask("Number of fingers (1-5, blank = 3, q = back): ")?
                    .trimmingCharacters(in: .whitespaces).lowercased() else { return nil }
                if text == "q" { break }
                if text.isEmpty { return (GestureKind.allNames[g], 3) }
                if let n = Int(text), (1...5).contains(n) { return (GestureKind.allNames[g], n) }
                terminal.say("Enter a number from 1 to 5, or q to go back.")
            }
        }
    }
}
