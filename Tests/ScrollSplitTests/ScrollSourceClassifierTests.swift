import XCTest
@testable import ScrollSplit

final class ScrollSourceClassifierTests: XCTestCase {
    private let classifier = ScrollSourceClassifier()

    func testDiscreteVerticalWheelIsMouse() {
        XCTAssertEqual(
            classifier.classify(evidence(continuous: false, line: 3, fixed: 3, point: 30)),
            .mouseWheel
        )
    }

    func testPhasedContinuousScrollIsTrackpad() {
        XCTAssertEqual(
            classifier.classify(evidence(continuous: true, phase: 2, fixed: 1.25, point: 1)),
            .trackpad
        )
    }

    func testMomentumIsTrackpadEvenWithoutScrollPhase() {
        XCTAssertEqual(
            classifier.classify(evidence(continuous: true, momentum: 2, fixed: 2, point: 2)),
            .trackpad
        )
    }

    func testUnphasedContinuousScrollIsAmbiguous() {
        XCTAssertEqual(
            classifier.classify(evidence(continuous: true, fixed: 1.5, point: 2)),
            .ambiguous
        )
    }

    func testHorizontalOnlyWheelIsAmbiguous() {
        XCTAssertEqual(classifier.classify(evidence(continuous: false)), .ambiguous)
    }

    private func evidence(
        continuous: Bool,
        phase: Int64 = 0,
        momentum: Int64 = 0,
        line: Int64 = 0,
        fixed: Double = 0,
        point: Int64 = 0
    ) -> ScrollEventEvidence {
        ScrollEventEvidence(
            isContinuous: continuous,
            scrollPhase: phase,
            momentumPhase: momentum,
            lineDeltaY: line,
            fixedDeltaY: fixed,
            pointDeltaY: point
        )
    }
}
