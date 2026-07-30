import XCTest
@testable import BarikEnhanced

final class WidgetRegistrationTests: XCTestCase {
    func testMeetingsIsRegisteredInBothSelectionSurfaces() {
        XCTAssertTrue(
            allWidgets.contains { $0.id == "default.meetings" })
        XCTAssertTrue(
            MenuBarContextMenu.widgetEntries.contains {
                $0.id == "default.meetings" && $0.name == "Meetings"
            })
    }

    func testTimeRemainsIndependentlyRegistered() {
        XCTAssertTrue(allWidgets.contains { $0.id == "default.time" })
        XCTAssertTrue(
            MenuBarContextMenu.widgetEntries.contains {
                $0.id == "default.time" && $0.name == "Time & Calendar"
            })
        XCTAssertNotEqual("default.time", "default.meetings")
    }
}
