import Foundation

/// Produces touch frames (real hardware, or a scripted replay in tests).
/// Implementations live in `GestureEngine`.
public protocol TouchSource: AnyObject {
    /// Called for every frame the source produces.
    var onFrame: ((TouchFrame) -> Void)? { get set }
    func start() throws
    func stop()
}

/// Detects ONE family of gestures from a stream of frames (Strategy pattern).
/// Add a new gesture by adding a new recognizer; nothing else changes.
public protocol GestureRecognizer: AnyObject {
    /// Feed the next frame. Returns an event when a gesture is completed.
    func process(_ frame: TouchFrame) -> GestureEvent?
    func reset()
}

/// Something that can be triggered by a gesture (Command pattern).
/// Implementations live in `GestureActions`.
public protocol Action {
    /// Human-readable description, used in logs.
    var summary: String { get }
    func perform() throws
}

/// Receives recognized gestures. The engine only knows this protocol,
/// so it stays decoupled from actions and configuration.
public protocol GestureHandler: AnyObject {
    func handle(_ event: GestureEvent)
}

/// Registers system-wide keyboard shortcuts and reports presses (Adapter over the OS API).
/// Implementations live in `GestureEngine`.
public protocol HotkeyRegistrar: AnyObject {
    /// Replaces all registered hotkeys. Returns the ones the OS refused (e.g. already taken).
    @discardableResult
    func register(_ hotkeys: [Hotkey], onPress: @escaping (Hotkey) -> Void) -> [HotkeyFailure]
    func unregisterAll()
}
