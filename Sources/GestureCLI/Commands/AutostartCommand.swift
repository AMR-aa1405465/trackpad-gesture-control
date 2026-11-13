import Foundation
import GestureActions

/// `autostart on|off|status`: run the gesture listener automatically at login.
struct AutostartCommand: Command {
    let manager: LaunchAgentManager
    let name = "autostart"
    let summary = "Start listening automatically at login (on | off | status)"
    let usage = "autostart on|off|status"

    func run(_ args: Arguments) throws {
        switch args.positionals.first {
        case "on":
            try manager.enable()
            print("Start at login: ON (listening in the background now).")
            printAccessibilityNote()
        case "off":
            try manager.disable()
            print("Start at login: OFF (background listener stopped).")
        case "status", nil:
            print("Start at login: \(manager.isInstalled ? "ON" : "OFF")"
                + (manager.isRunning ? " (background listener running)" : ""))
        default:
            throw CLIError("Use: autostart on | off | status")
        }
    }

    private func printAccessibilityNote() {
        if manager.usesDebugBuild {
            print("WARNING: this is a debug build. Run it via ./trackpad (release build) and enable again.")
        }
        print("""

        IMPORTANT: at login the listener runs on its own, so macOS needs Accessibility permission
        for this program itself (not your terminal). If shortcuts/clicks do nothing:
          System Settings > Privacy & Security > Accessibility > "+" > press Cmd+Shift+G and add:
          \(manager.executablePath)
        Rebuilding the app can reset that permission; re-add it if actions stop working.
        Log file: \(manager.logURL.path)
        """)
    }
}
