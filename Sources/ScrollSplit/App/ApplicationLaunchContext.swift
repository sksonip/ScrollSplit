import AppKit
import ApplicationServices

enum ApplicationLaunchContext {
    static func isLoginItemLaunch(
        event: NSAppleEventDescriptor? = NSAppleEventManager.shared().currentAppleEvent
    ) -> Bool {
        isLoginItemLaunch(
            eventID: event?.eventID,
            hasLoginItemParameter: event?.paramDescriptor(
                forKeyword: keyAELaunchedAsLogInItem
            ) != nil
        )
    }

    static func isLoginItemLaunch(
        eventID: UInt32?,
        hasLoginItemParameter: Bool
    ) -> Bool {
        eventID == kAEOpenApplication && hasLoginItemParameter
    }
}
