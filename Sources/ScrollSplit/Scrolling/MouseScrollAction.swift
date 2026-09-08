import CoreGraphics

enum MouseScrollAction: Equatable {
    case passThrough
    case reverseVertical
    case zoomIn
    case zoomOut
}

struct MouseScrollActionResolver {
    func resolve(
        source: ScrollSource,
        flags: CGEventFlags,
        verticalDelta: Double
    ) -> MouseScrollAction {
        guard source == .mouseWheel else {
            return .passThrough
        }

        if flags.contains(.maskCommand), verticalDelta != 0 {
            return verticalDelta > 0 ? .zoomIn : .zoomOut
        }

        return .reverseVertical
    }
}
