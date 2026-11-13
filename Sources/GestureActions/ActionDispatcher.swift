import Foundation
import GestureCore

/// Maps triggers (gestures and keyboard shortcuts) to actions and runs them.
/// Implements `GestureHandler`, the only seam between the recognition engine and this layer.
/// Thread-safe: triggers arrive on input threads while the CLI may swap bindings.
public final class ActionDispatcher: GestureHandler {
    private let lock = NSLock()
    private var bindings: [GestureTrigger: Action]
    private var hotkeyBindings: [Hotkey: Action] = [:]
    private var interceptor: ((GestureEvent) -> Bool)?
    private let log: (String) -> Void
    /// Actions run here, one at a time in the order they were triggered, so a slow action
    /// never blocks the input thread that detects gestures.
    private let actionQueue = DispatchQueue(label: "trackpad.actions", qos: .userInitiated)

    public init(bindings: [GestureTrigger: Action] = [:], log: @escaping (String) -> Void = { print($0) }) {
        self.bindings = bindings
        self.log = log
    }

    public func bind(_ trigger: GestureTrigger, to action: Action) {
        lock.lock(); defer { lock.unlock() }
        bindings[trigger] = action
    }

    /// Replace all gesture bindings at once (used for live config reload).
    public func setBindings(_ new: [GestureTrigger: Action]) {
        lock.lock(); defer { lock.unlock() }
        bindings = new
    }

    /// Replace all keyboard-shortcut bindings at once.
    public func setHotkeyBindings(_ new: [Hotkey: Action]) {
        lock.lock(); defer { lock.unlock() }
        hotkeyBindings = new
    }

    /// While set, every gesture is first offered to this closure; returning true consumes
    /// the event so no action runs (used to "capture" a gesture while configuring).
    public func setInterceptor(_ closure: ((GestureEvent) -> Bool)?) {
        lock.lock(); defer { lock.unlock() }
        interceptor = closure
    }

    public func handle(_ event: GestureEvent) {
        lock.lock()
        let intercept = interceptor
        let action = bindings[GestureTrigger(event)]
        lock.unlock()

        if let intercept = intercept, intercept(event) { return }
        log("Gesture: \(event.fingerCount)-finger \(event.kind)")
        if let action = action { enqueue(action) }
    }

    /// Called when a registered keyboard shortcut is pressed.
    public func handleHotkey(_ hotkey: Hotkey) {
        lock.lock(); let action = hotkeyBindings[hotkey]; lock.unlock()
        log("Gesture: shortcut \(hotkey.text)")
        if let action = action { enqueue(action) }
    }

    /// Hand the action to the queue and return immediately.
    private func enqueue(_ action: Action) {
        actionQueue.async { [log] in
            do {
                try action.perform()
                log("  -> \(action.summary)")
            } catch {
                log("  -> FAILED (\(action.summary)): \(error)")
            }
        }
    }
}
