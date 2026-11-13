import Foundation
import GestureCore

/// Detects pinch in / pinch out with any number of fingers (>= 2).
/// Fires once per touch session, when the hand's spread changes by `threshold` (relative).
public final class PinchRecognizer: GestureRecognizer {
    private let threshold: Double
    private let minFingers: Int
    private var startSpread: Double?
    private var fingerCount = 0
    private var fired = false

    /// - Parameter threshold: relative spread change needed, e.g. 0.25 = 25%.
    public init(threshold: Double = 0.25, minFingers: Int = 2) {
        self.threshold = threshold
        self.minFingers = minFingers
    }

    public func process(_ frame: TouchFrame) -> GestureEvent? {
        guard frame.fingerCount >= minFingers else { reset(); return nil }

        // A change in finger count restarts tracking (fingers landing one by one).
        if frame.fingerCount != fingerCount {
            fingerCount = frame.fingerCount
            startSpread = frame.spread
            fired = false
            return nil
        }
        guard !fired, let start = startSpread, start > 0.001 else { return nil }

        let ratio = (frame.spread - start) / start
        if ratio <= -threshold {
            fired = true
            return GestureEvent(kind: .pinchIn, fingerCount: fingerCount)
        } else if ratio >= threshold {
            fired = true
            return GestureEvent(kind: .pinchOut, fingerCount: fingerCount)
        }
        return nil
    }

    public func reset() {
        startSpread = nil
        fingerCount = 0
        fired = false
    }
}
