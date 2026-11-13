import Foundation
import GestureCore

/// Orchestrates one `TouchSource` and the gesture recognizers.
/// Each physical trackpad gets its OWN recognizer instances (built by `recognizerFactory`),
/// so frames from different devices can never corrupt each other's state.
/// Knows nothing about actions: it only forwards recognized events to a `GestureHandler`.
public final class GestureEngine {
    private let source: TouchSource
    private let recognizerFactory: () -> [GestureRecognizer]
    /// Strong on purpose: the engine owns its handler (handlers never reference the engine, so no cycle).
    public var handler: GestureHandler?

    private let lock = NSLock()
    private var pipelines: [Int: [GestureRecognizer]] = [:]

    public init(source: TouchSource,
                recognizerFactory: @escaping () -> [GestureRecognizer],
                handler: GestureHandler? = nil) {
        self.source = source
        self.recognizerFactory = recognizerFactory
        self.handler = handler
    }

    public func start() throws {
        source.onFrame = { [weak self] frame in self?.process(frame) }
        try source.start()
    }

    public func stop() {
        source.stop()
        source.onFrame = nil
        lock.lock(); pipelines.removeAll(); lock.unlock()
    }

    func process(_ frame: TouchFrame) {
        // Only the dictionary lookup is locked; a device's recognizers are then touched
        // solely by that device's (serial) callback, so no lock is held while recognizing.
        lock.lock()
        let recognizers = pipelines[frame.deviceID] ?? {
            let created = recognizerFactory()
            pipelines[frame.deviceID] = created
            return created
        }()
        lock.unlock()

        for recognizer in recognizers {
            if let event = recognizer.process(frame) {
                handler?.handle(event)
            }
        }
    }
}
