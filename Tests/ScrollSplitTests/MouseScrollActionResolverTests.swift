import CoreGraphics
import XCTest
@testable import ScrollSplit

final class MouseScrollActionResolverTests: XCTestCase {
    private let resolver = MouseScrollActionResolver()

    func testCommandScrollUpZoomsInForMouseWheel() {
        XCTAssertEqual(
            resolver.resolve(source: .mouseWheel, flags: .maskCommand, verticalDelta: 1),
            .zoomIn
        )
    }

    func testCommandScrollDownZoomsOutForMouseWheel() {
        XCTAssertEqual(
            resolver.resolve(source: .mouseWheel, flags: .maskCommand, verticalDelta: -1),
            .zoomOut
        )
    }

    func testOrdinaryMouseWheelStillReverses() {
        XCTAssertEqual(
            resolver.resolve(source: .mouseWheel, flags: [], verticalDelta: 1),
            .reverseVertical
        )
    }

    func testCommandTrackpadScrollPassesThrough() {
        XCTAssertEqual(
            resolver.resolve(source: .trackpad, flags: .maskCommand, verticalDelta: 1),
            .passThrough
        )
    }

    func testAmbiguousCommandScrollPassesThrough() {
        XCTAssertEqual(
            resolver.resolve(source: .ambiguous, flags: .maskCommand, verticalDelta: -1),
            .passThrough
        )
    }
}
