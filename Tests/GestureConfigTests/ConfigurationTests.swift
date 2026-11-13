import XCTest
import GestureCore
import GestureActions
@testable import GestureConfig

final class ConfigurationTests: XCTestCase {
    func testParsesBindings() throws {
        let json = """
        {"bindings":[{"gesture":"pinchIn","fingers":3,"action":{"type":"launchApp","app":"Safari"}},
                     {"gesture":"swipeLeft","fingers":3,"action":{"type":"keyPress","key":"escape"}}]}
        """
        let config = try JSONDecoder().decode(GestureConfiguration.self, from: Data(json.utf8))
        let bindings = try ConfigurationLoader().bindings(from: config)
        XCTAssertEqual(bindings.count, 2)
        XCTAssertEqual(bindings[GestureTrigger(kind: .pinchIn, fingerCount: 3)]?.summary, "Launch app Safari")
        XCTAssertEqual(bindings[GestureTrigger(kind: .swipe(.left), fingerCount: 3)]?.summary, "Press key escape")
    }

    func testUnknownGestureThrows() {
        let config = GestureConfiguration(bindings: [
            .init(gesture: "wiggle", fingers: 2, action: ActionDefinition(type: "click"))
        ])
        XCTAssertThrowsError(try ConfigurationLoader().bindings(from: config))
    }

    func testGestureKindRoundTrip() {
        for kind in [GestureKind.pinchIn, .pinchOut, .swipe(.up), .swipe(.right)] {
            XCTAssertEqual(GestureKind(name: kind.description), kind)
        }
    }
}
