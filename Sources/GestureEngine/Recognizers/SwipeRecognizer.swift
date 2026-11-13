import Foundation
import GestureCore

/// Detects swipes (left/right/up/down) with any number of fingers (>= 1).
/// Fires once per touch session when the centroid travels `distance` in one dominant direction.
public final class SwipeRecognizer: GestureRecognizer {
    private let distance: Double
    private let minFingers: Int
    private var startCentroid: TouchPoint?
    private var fingerCount = 0
    private var fired = false

    /// - Parameter distance: normalized travel needed (0...1 of the trackpad), e.g. 0.2.
    public init(distance: Double = 0.2, minFingers: Int = 3) {
        self.distance = distance
        self.minFingers = minFingers
    }

    public func process(_ frame: TouchFrame) -> GestureEvent? {
        guard frame.fingerCount >= minFingers, let centroid = frame.centroid else { reset(); return nil }

        if frame.fingerCount != fingerCount {
            fingerCount = frame.fingerCount
            startCentroid = centroid
            fired = false
            return nil
        }
        guard !fired, let start = startCentroid else { return nil }

        let dx = centroid.x - start.x
        let dy = centroid.y - start.y
        guard max(abs(dx), abs(dy)) >= distance else { return nil }

        fired = true
        let direction: SwipeDirection
        if abs(dx) >= abs(dy) {
            direction = dx > 0 ? .right : .left
        } else {
            // Trackpad y grows upward, so positive dy is an upward swipe.
            direction = dy > 0 ? .up : .down
        }
        return GestureEvent(kind: .swipe(direction), fingerCount: fingerCount)
    }

    public func reset() {
        startCentroid = nil
        fingerCount = 0
        fired = false
    }
}
