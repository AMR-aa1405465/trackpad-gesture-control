import Foundation
import GestureCore
import GestureEngine
import GestureActions
import GestureConfig

/// A live listening session: engine + dispatcher + config. The menu talks to this, so
/// bindings can change while the trackpad keeps being listened to.
final class GestureSession {
    let store: ConfigurationStore
    private let loader: ConfigurationLoader
    private let dispatcher: ActionDispatcher
    private let engine: GestureEngine

    let debug: Bool
    private let lock: InstanceLock
    private var configStamp: Date?
    /// False when another process (e.g. the login service) already owns the trackpad.
    private(set) var isListening = false
    private let registrar: HotkeyRegistrar = CarbonHotkeyRegistrar()
    /// Shortcuts macOS refused at the last reload (e.g. already taken by another app).
    private(set) var hotkeyFailures: [HotkeyFailure] = []

    /// - Parameter debug: when false the session prints nothing (gesture/action logs are off).
    init(store: ConfigurationStore, factory: ActionFactory, debug: Bool) {
        self.store = store
        self.debug = debug
        lock = InstanceLock(url: store.url.deletingLastPathComponent().appendingPathComponent("instance.lock"))
        loader = ConfigurationLoader(factory: factory)
        dispatcher = ActionDispatcher(log: debug
            ? { print("\r[gesture] " + $0.replacingOccurrences(of: "Gesture: ", with: "")) }
            : { _ in })
        engine = PipelineBuilder.makeEngine(handler: dispatcher)
    }

    /// Starts listening if no other instance is. Returns quietly in config-only mode otherwise.
    func start() throws {
        guard lock.tryAcquire() else { isListening = false; return }
        isListening = true
        do {
            try reload()
            // Apple's framework prints "Recognized ... family" lines when it opens devices;
            // hide them unless debugging.
            if debug { try engine.start() } else { try OutputSilencer.run { try engine.start() } }
        } catch {
            isListening = false
            throw error
        }
    }

    /// Re-read the config file and apply it to the running engine.
    func reload() throws {
        let config = try store.read()
        dispatcher.setBindings(try loader.bindings(from: config))
        let hotkeys = try loader.hotkeyBindings(from: config)
        dispatcher.setHotkeyBindings(hotkeys)
        if isListening { registerHotkeys(Array(hotkeys.keys)) }
        configStamp = modificationDate()
    }

    /// Carbon delivers hotkey presses on the main thread, so register from there.
    private func registerHotkeys(_ hotkeys: [Hotkey]) {
        let work = { [self] in
            hotkeyFailures = registrar.register(hotkeys) { [dispatcher] in dispatcher.handleHotkey($0) }
        }
        if Thread.isMainThread { work() } else { DispatchQueue.main.sync(execute: work) }
    }

    /// Cheap check used by the background service: reload when the file changed on disk.
    func reloadIfConfigChanged() {
        guard isListening, modificationDate() != configStamp else { return }
        try? reload()
    }

    private func modificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: store.url.path))?[.modificationDate] as? Date
    }

    /// Waits for the user to perform one gesture. The gesture is NOT executed.
    func captureGesture(timeout: TimeInterval = 20) -> GestureEvent? {
        guard isListening else { return nil }
        let lock = NSLock()
        var captured: GestureEvent?
        dispatcher.setInterceptor { event in
            lock.lock(); captured = event; lock.unlock()
            return true
        }
        defer { dispatcher.setInterceptor(nil) }
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            lock.lock(); let done = captured; lock.unlock()
            if done != nil { return done }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return nil
    }
}

/// Temporarily redirects stdout/stderr to /dev/null (to hide noise from system frameworks).
enum OutputSilencer {
    static func run<T>(_ body: () throws -> T) rethrows -> T {
        fflush(stdout); fflush(stderr)
        let savedOut = dup(STDOUT_FILENO), savedErr = dup(STDERR_FILENO)
        let null = open("/dev/null", O_WRONLY)
        dup2(null, STDOUT_FILENO); dup2(null, STDERR_FILENO)
        defer {
            fflush(stdout); fflush(stderr)
            dup2(savedOut, STDOUT_FILENO); dup2(savedErr, STDERR_FILENO)
            close(savedOut); close(savedErr); close(null)
        }
        return try body()
    }
}
