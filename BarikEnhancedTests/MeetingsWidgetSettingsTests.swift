import XCTest
@testable import BarikEnhanced

final class MeetingsWidgetSettingsTests: XCTestCase {
    func testTitleMaximumLengthDefaultsAndClamps() {
        XCTAssertEqual(
            MeetingsWidgetSettings(config: [:]).titleMaximumLength,
            32)
        XCTAssertEqual(
            MeetingsWidgetSettings(
                config: ["title-max-length": .int(-10)])
                .titleMaximumLength,
            8)
        XCTAssertEqual(
            MeetingsWidgetSettings(
                config: ["title-max-length": .int(400)])
                .titleMaximumLength,
            80)
    }

    func testTruncatedTitleIncludesEllipsisWithinLimit() {
        let settings = MeetingsWidgetSettings(titleMaximumLength: 8)

        XCTAssertEqual(settings.truncatedTitle("12345678"), "12345678")
        XCTAssertEqual(settings.truncatedTitle("123456789"), "1234567…")
        XCTAssertEqual(settings.truncatedTitle("123456789").count, 8)
    }
}
