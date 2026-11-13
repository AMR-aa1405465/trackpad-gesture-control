import Foundation
import GestureCore
import GestureEngine
import GestureActions
import GestureConfig

/// Builds the live pipeline (source -> recognizers -> handler). Shared by `run` and `monitor`.
enum PipelineBuilder {
    static func makeEngine(handler: GestureHandler, source: TouchSource = MultitouchTouchSource()) -> GestureEngine {
        GestureEngine(
            source: source,
            recognizerFactory: { [PinchRecognizer(), SwipeRecognizer()] },
            handler: handler
        )
    }
}

/// `run`: headless listener (no menu). This is what the login service runs. Silent unless
/// started with `debug`; reloads the config file automatically when it changes.
struct RunCommand: Command {
    let session: GestureSession
    let name = "run"
    let summary = "Listen in the background, no menu (used by start-at-login)"
    let usage = "run"

    func run(_ args: Arguments) throws {
        try session.start()
        guard session.isListening else {
            if session.debug { print("Another instance is already listening; exiting.") }
            return  // clean exit: the login service will not restart us
        }
        if !AccessibilityPermission.request(), session.debug {
            print("WARNING: " + AccessibilityPermission.instructions)
        }
        if session.debug {
            print("Listening in the background (debug). Ctrl+C to quit.")
            session.hotkeyFailures.forEach { print("Shortcut \($0.hotkey.text) not registered: \($0.reason)") }
        }
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in session.reloadIfConfigChanged() }
        MainLoop.run()
    }
}

/// `monitor`: print every detected gesture without running any action (safe for testing).
struct MonitorCommand: Command {
    let name = "monitor"
    let summary = "Print detected gestures live, without running actions"
    let usage = "monitor [--raw]   (--raw also prints finger count changes, for diagnosing input)"

    func run(_ args: Arguments) throws {
        var source: TouchSource = MultitouchTouchSource()
        if args.flags["raw"] != nil { source = LoggingTouchSource(wrapping: source) }
        let engine = PipelineBuilder.makeEngine(handler: ActionDispatcher(), source: source)
        try engine.start()
        print("Monitoring gestures. Ctrl+C to quit.")
        RunLoop.main.run()
    }
}

/// Decorator: forwards frames unchanged and prints whenever the finger count changes.
final class LoggingTouchSource: TouchSource {
    var onFrame: ((TouchFrame) -> Void)?
    private let inner: TouchSource
    private var last = -1
    private var lastSpread = 0.0

    init(wrapping inner: TouchSource) { self.inner = inner }

    func start() throws {
        inner.onFrame = { [weak self] frame in
            guard let self = self else { return }
            if frame.fingerCount != self.last {
                self.last = frame.fingerCount
                print("[raw] fingers: \(frame.fingerCount)")
            }
            if frame.fingerCount >= 2, abs(frame.spread - self.lastSpread) > 0.03, let c = frame.centroid {
                self.lastSpread = frame.spread
                print(String(format: "[raw]   spread %.3f  centroid (%.2f, %.2f)", frame.spread, c.x, c.y))
            }
            self.onFrame?(frame)
        }
        try inner.start()
    }

    func stop() { inner.stop() }
}
