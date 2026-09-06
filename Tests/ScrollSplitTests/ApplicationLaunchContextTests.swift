import ApplicationServices
import XCTest
@testable import ScrollSplit

final class ApplicationLaunchContextTests: XCTestCase {
    func testLoginItemOpenApplicationIsSilentLaunch() {
        XCTAssertTrue(
            ApplicationLaunchContext.isLoginItemLaunch(
                eventID: kAEOpenApplication,
                hasLoginItemParameter: true
            )
        )
    }

    func testNormalOpenApplicationIsManualLaunch() {
        XCTAssertFalse(
            ApplicationLaunchContext.isLoginItemLaunch(
                eventID: kAEOpenApplication,
                hasLoginItemParameter: false
            )
        )
    }

    func testUnrelatedEventCannotMasqueradeAsLoginLaunch() {
        XCTAssertFalse(
            ApplicationLaunchContext.isLoginItemLaunch(
                eventID: kAEReopenApplication,
                hasLoginItemParameter: true
            )
        )
    }
}
