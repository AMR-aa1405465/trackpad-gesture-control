import Foundation

/// A point on the trackpad surface, normalized to 0...1 on both axes.
public struct TouchPoint: Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func distance(to other: TouchPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// A single finger contact at one instant.
public struct Touch: Equatable {
    public let id: Int
    public let position: TouchPoint

    public init(id: Int, position: TouchPoint) {
        self.id = id
        self.position = position
    }
}

/// All fingers currently touching the trackpad at one instant.
public struct TouchFrame {
    public let timestamp: TimeInterval
    public let touches: [Touch]
    /// Which trackpad produced this frame (0 when there is only one source).
    public let deviceID: Int

    public init(timestamp: TimeInterval, touches: [Touch], deviceID: Int = 0) {
        self.timestamp = timestamp
        self.touches = touches
        self.deviceID = deviceID
    }

    public var fingerCount: Int { touches.count }

    /// Average position of all fingers. `nil` when no fingers are down.
    public var centroid: TouchPoint? {
        guard !touches.isEmpty else { return nil }
        let n = Double(touches.count)
        return TouchPoint(
            x: touches.reduce(0) { $0 + $1.position.x } / n,
            y: touches.reduce(0) { $0 + $1.position.y } / n
        )
    }

    /// Average distance of each finger from the centroid (how "spread" the hand is).
    public var spread: Double {
        guard let c = centroid else { return 0 }
        return touches.reduce(0) { $0 + $1.position.distance(to: c) } / Double(touches.count)
    }
}
