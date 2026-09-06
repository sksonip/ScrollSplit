import CoreGraphics

/// The result is deliberately not binary: uncertain input must remain untouched.
enum ScrollSource: Equatable {
    case mouseWheel
    case trackpad
    case ambiguous
}

struct ScrollEventEvidence: Equatable {
    let isContinuous: Bool
    let scrollPhase: Int64
    let momentumPhase: Int64
    let lineDeltaY: Int64
    let fixedDeltaY: Double
    let pointDeltaY: Int64
}

struct ScrollSourceClassifier {
    func classify(_ event: CGEvent) -> ScrollSource {
        classify(
            ScrollEventEvidence(
                isContinuous: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0,
                scrollPhase: event.getIntegerValueField(.scrollWheelEventScrollPhase),
                momentumPhase: event.getIntegerValueField(.scrollWheelEventMomentumPhase),
                lineDeltaY: event.getIntegerValueField(.scrollWheelEventDeltaAxis1),
                fixedDeltaY: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1),
                pointDeltaY: event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
            )
        )
    }

    func classify(_ evidence: ScrollEventEvidence) -> ScrollSource {
        // Scroll and momentum phases are strong evidence of a gesture sequence.
        // Protecting trackpad momentum takes precedence over mouse compatibility.
        if evidence.scrollPhase != 0 || evidence.momentumPhase != 0 {
            return .trackpad
        }

        guard hasVerticalMovement(evidence) else {
            return .ambiguous
        }

        // A non-continuous, unphased event is the documented line-based shape
        // produced by an ordinary physical wheel.
        if !evidence.isContinuous {
            return .mouseWheel
        }

        // Smooth-scrolling mice and unphased trackpad events overlap here. There
        // is no public device identifier on CGEvent, so changing these would risk
        // reversing a trackpad. Pass them through.
        return .ambiguous
    }

    private func hasVerticalMovement(_ evidence: ScrollEventEvidence) -> Bool {
        evidence.lineDeltaY != 0 || evidence.fixedDeltaY != 0 || evidence.pointDeltaY != 0
    }
}
