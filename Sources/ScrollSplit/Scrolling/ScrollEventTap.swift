import CoreGraphics
import Foundation

private let scrollEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }

    let owner = Unmanaged<ScrollEventTap>.fromOpaque(userInfo).takeUnretainedValue()

    return MainActor.assumeIsolated {
        owner.handle(type: type, event: event)
    }
}

@MainActor
protocol ScrollEventTapControlling: AnyObject {
    var isRunning: Bool { get }

    @discardableResult
    func start() -> Bool
    func stop()
}

@MainActor
final class ScrollEventTap: ScrollEventTapControlling {
    private let classifier: ScrollSourceClassifier
    private let actionResolver = MouseScrollActionResolver()
    private let isReversalEnabled: () -> Bool
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(
        classifier: ScrollSourceClassifier = ScrollSourceClassifier(),
        isReversalEnabled: @escaping () -> Bool
    ) {
        self.classifier = classifier
        self.isReversalEnabled = isReversalEnabled
    }

    var isRunning: Bool {
        guard let tap, runLoopSource != nil, CFMachPortIsValid(tap) else {
            return false
        }

        return CGEvent.tapIsEnabled(tap: tap)
    }

    @discardableResult
    func start() -> Bool {
        if tap != nil || runLoopSource != nil {
            if let tap, runLoopSource != nil, CFMachPortIsValid(tap) {
                CGEvent.tapEnable(tap: tap, enable: true)
                return isRunning
            }

            stop()
        }

        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: scrollEventTapCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CGEvent.tapEnable(tap: newTap, enable: false)
            CFMachPortInvalidate(newTap)
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)

        tap = newTap
        runLoopSource = source

        guard isRunning else {
            stop()
            return false
        }

        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let tap {
            CFMachPortInvalidate(tap)
        }

        runLoopSource = nil
        tap = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap, isReversalEnabled() {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .scrollWheel, isReversalEnabled() else {
            return Unmanaged.passUnretained(event)
        }

        let action = actionResolver.resolve(
            source: classifier.classify(event),
            flags: event.flags,
            verticalDelta: verticalDelta(of: event)
        )

        switch action {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .reverseVertical:
            reverseVerticalFields(of: event)
            return Unmanaged.passUnretained(event)
        case .zoomIn:
            postZoomKey(keyCode: 24) // Command-= (the standard macOS Zoom In shortcut)
            return nil
        case .zoomOut:
            postZoomKey(keyCode: 27) // Command--
            return nil
        }
    }

    private func verticalDelta(of event: CGEvent) -> Double {
        let lineDelta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        if lineDelta != 0 {
            return Double(lineDelta)
        }

        let fixedDelta = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        if fixedDelta != 0 {
            return fixedDelta
        }

        return Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
    }

    private func postZoomKey(keyCode: CGKeyCode) {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func reverseVerticalFields(of event: CGEvent) {
        let lineDelta = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let fixedDelta = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let pointDelta = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)

        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: safelyNegated(lineDelta))
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixedDelta)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: safelyNegated(pointDelta))
    }

    private func safelyNegated(_ value: Int64) -> Int64 {
        value == .min ? .max : -value
    }
}
