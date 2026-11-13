import ApplicationServices

/// macOS silently discards synthetic keyboard/mouse events unless the app that launched this
/// tool (Terminal, iTerm, Claude, ...) has Accessibility permission.
public enum AccessibilityPermission {
    public static var isGranted: Bool { AXIsProcessTrusted() }

    /// Checks permission and, if missing, asks macOS to show its permission prompt.
    @discardableResult
    public static func request() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    public static let instructions = """
    Accessibility permission is missing, so macOS drops simulated key presses and clicks.
    Fix: System Settings > Privacy & Security > Accessibility, enable the app you run this in
    (Terminal, iTerm, or the Claude app), then restart ./trackpad.
    """
}
