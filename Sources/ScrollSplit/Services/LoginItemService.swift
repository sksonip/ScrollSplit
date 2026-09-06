import ServiceManagement

@MainActor
final class LoginItemService {
    enum LoginItemError: LocalizedError {
        case requiresApproval

        var errorDescription: String? {
            switch self {
            case .requiresApproval:
                return "macOS requires approval in System Settings > General > Login Items."
            }
        }
    }

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
            if SMAppService.mainApp.status == .requiresApproval {
                throw LoginItemError.requiresApproval
            }
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
