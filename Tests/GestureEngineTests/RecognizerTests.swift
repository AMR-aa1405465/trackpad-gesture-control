import XCTest
import GestureCore
@testable import GestureEngine

final class RecognizerTests: XCTestCase {
    /// Builds a frame with `n` fingers evenly placed on a circle of `radius` around (0.5, 0.5).
    private func frame(fingers n: Int, radius: Double, shift: Double = 0, t: Double = 0) -> TouchFrame {
        let touches = (0..<n).map { i -> Touch in
            let a = 2 * Double.pi * Double(i) / Double(n)
            return Touch(id: i, position: TouchPoint(x: 0.5 + shift + radius * cos(a), y: 0.5 + radius * sin(a)))
        }
        return TouchFrame(timestamp: t, touches: touches)
    }

    func testPinchInWithThreeFingers() {
        let r = PinchRecognizer()
        XCTAssertNil(r.process(frame(fingers: 3, radius: 0.2)))
        XCTAssertEqual(r.process(frame(fingers: 3, radius: 0.1)),
                       GestureEvent(kind: .pinchIn, fingerCount: 3))
    }

    func testPinchOutWithFourFingersFiresOnce() {
        let r = PinchRecognizer()
        _ = r.process(frame(fingers: 4, radius: 0.1))
        XCTAssertEqual(r.process(frame(fingers: 4, radius: 0.2)),
                       GestureEvent(kind: .pinchOut, fingerCount: 4))
        XCTAssertNil(r.process(frame(fingers: 4, radius: 0.3)))
    }

    func testSwipeLeftWithThreeFingers() {
        let r = SwipeRecognizer()
        _ = r.process(frame(fingers: 3, radius: 0.05))
        XCTAssertEqual(r.process(frame(fingers: 3, radius: 0.05, shift: -0.3)),
                       GestureEvent(kind: .swipe(.left), fingerCount: 3))
    }

    func testEachDeviceHasIndependentRecognizerState() throws {
        final class Spy: GestureHandler { var events: [GestureEvent] = []; func handle(_ e: GestureEvent) { events.append(e) } }
        func frame(_ device: Int, radius: Double) -> TouchFrame {
            let f = self.frame(fingers: 3, radius: radius)
            return TouchFrame(timestamp: 0, touches: f.touches, deviceID: device)
        }
        let spy = Spy()
        // Interleaved frames from two devices: device 1 pinches in, device 2 stays still.
        let source = ReplayTouchSource(frames: [
            frame(1, radius: 0.2), frame(2, radius: 0.2), frame(1, radius: 0.05), frame(2, radius: 0.2),
        ])
        let engine = GestureEngine(source: source, recognizerFactory: { [PinchRecognizer()] }, handler: spy)
        try engine.start()
        XCTAssertEqual(spy.events, [GestureEvent(kind: .pinchIn, fingerCount: 3)])
    }

    func testEngineForwardsEventsToHandler() throws {
        final class Spy: GestureHandler { var events: [GestureEvent] = []; func handle(_ e: GestureEvent) { events.append(e) } }
        let spy = Spy()
        let source = ReplayTouchSource(frames: [frame(fingers: 2, radius: 0.2), frame(fingers: 2, radius: 0.05)])
        let engine = GestureEngine(source: source, recognizerFactory: { [PinchRecognizer()] }, handler: spy)
        try engine.start()
        XCTAssertEqual(spy.events, [GestureEvent(kind: .pinchIn, fingerCount: 2)])
    }
}
