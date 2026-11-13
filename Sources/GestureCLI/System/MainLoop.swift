import AppKit

/// Keeps the process alive and dispatching OS events on the main thread.
/// A plain RunLoop is not enough: Carbon keyboard-shortcut events are only delivered
/// by a real application event loop. `.accessory` means no Dock icon and no menu bar.
enum MainLoop {
    static func run() -> Never {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.run()
        exit(0)
    }
}
