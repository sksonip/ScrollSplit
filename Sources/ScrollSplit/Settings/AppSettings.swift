import Foundation

@MainActor
final class AppSettings {
    private enum Key {
        static let reverseMouseScrolling = "reverseMouseScrolling"
        static let hasRequestedInputMonitoring = "hasRequestedInputMonitoring"
        static let hasRequestedAccessibility = "hasRequestedAccessibility"
        static let hasRequestedPostEvent = "hasRequestedPostEvent"
        static let hasShownPermissionGuidance = "hasShownPermissionGuidance"
        static let hasShownEventTapFailure = "hasShownEventTapFailure"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [Key.reverseMouseScrolling: true])
    }

    var reverseMouseScrolling: Bool {
        get { defaults.bool(forKey: Key.reverseMouseScrolling) }
        set { defaults.set(newValue, forKey: Key.reverseMouseScrolling) }
    }

    var hasRequestedInputMonitoring: Bool {
        get { defaults.bool(forKey: Key.hasRequestedInputMonitoring) }
        set { defaults.set(newValue, forKey: Key.hasRequestedInputMonitoring) }
    }

    var hasRequestedAccessibility: Bool {
        get { defaults.bool(forKey: Key.hasRequestedAccessibility) }
        set { defaults.set(newValue, forKey: Key.hasRequestedAccessibility) }
    }

    var hasRequestedPostEvent: Bool {
        get { defaults.bool(forKey: Key.hasRequestedPostEvent) }
        set { defaults.set(newValue, forKey: Key.hasRequestedPostEvent) }
    }

    var hasShownPermissionGuidance: Bool {
        get { defaults.bool(forKey: Key.hasShownPermissionGuidance) }
        set { defaults.set(newValue, forKey: Key.hasShownPermissionGuidance) }
    }

    var hasShownEventTapFailure: Bool {
        get { defaults.bool(forKey: Key.hasShownEventTapFailure) }
        set { defaults.set(newValue, forKey: Key.hasShownEventTapFailure) }
    }
}
