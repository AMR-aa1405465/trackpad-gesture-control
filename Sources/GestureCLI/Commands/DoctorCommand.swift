import Foundation
import GestureActions

/// `doctor`: checks that everything the app needs from macOS is in place.
struct DoctorCommand: Command {
    let name = "doctor"
    let summary = "Check permissions (and send a test Escape key press)"
    let usage = "doctor [--test]   (--test presses Escape to prove key simulation works)"

    func run(_ args: Arguments) throws {
        if AccessibilityPermission.isGranted {
            print("Accessibility permission: OK")
        } else {
            print("Accessibility permission: MISSING")
            print(AccessibilityPermission.instructions)
            AccessibilityPermission.request()  // shows the macOS prompt
            return
        }
        if args.flags["test"] != nil {
            try KeyPressAction(keyName: "escape").perform()
            print("Sent an Escape key press.")
        }
    }
}
