import Foundation
import GestureCore

/// A scripted `TouchSource` for tests and demos: replays prepared frames on `start()`.
public final class ReplayTouchSource: TouchSource {
    public var onFrame: ((TouchFrame) -> Void)?
    private let frames: [TouchFrame]

    public init(frames: [TouchFrame]) {
        self.frames = frames
    }

    public func start() throws {
        frames.forEach { onFrame?($0) }
    }

    public func stop() {}
}
