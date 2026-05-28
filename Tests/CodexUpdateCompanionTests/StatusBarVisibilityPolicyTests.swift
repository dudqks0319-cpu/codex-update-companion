import XCTest
@testable import CodexUpdateCompanionCore

final class StatusBarVisibilityPolicyTests: XCTestCase {
    func testAlwaysVisibleWhenPreferenceIsOff() {
        XCTAssertTrue(
            StatusBarVisibilityPolicy.isVisible(
                onlyShowWhenCodexRuns: false,
                isCodexRunning: false
            )
        )
    }

    func testHiddenWhenPreferenceIsOnAndCodexIsNotRunning() {
        XCTAssertFalse(
            StatusBarVisibilityPolicy.isVisible(
                onlyShowWhenCodexRuns: true,
                isCodexRunning: false
            )
        )
    }

    func testVisibleWhenPreferenceIsOnAndCodexIsRunning() {
        XCTAssertTrue(
            StatusBarVisibilityPolicy.isVisible(
                onlyShowWhenCodexRuns: true,
                isCodexRunning: true
            )
        )
    }
}
