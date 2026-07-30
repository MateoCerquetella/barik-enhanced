import XCTest
@testable import BarikEnhanced

final class ClipboardPresentationTests: XCTestCase {
    func testSettingsDefaultAndClampConfiguredValues() {
        XCTAssertEqual(
            ClipboardWidgetSettings(config: [:]),
            ClipboardWidgetSettings(
                maximumItems: 10,
                previewMaximumLength: 40))

        let minimums = ClipboardWidgetSettings(
            config: [
                "max-items": .int(-2),
                "preview-max-length": .int(0),
            ])
        XCTAssertEqual(minimums.maximumItems, 1)
        XCTAssertEqual(minimums.previewMaximumLength, 8)

        let maximums = ClipboardWidgetSettings(
            config: [
                "max-items": .int(200),
                "preview-max-length": .int(500),
            ])
        XCTAssertEqual(maximums.maximumItems, 20)
        XCTAssertEqual(maximums.previewMaximumLength, 120)
    }

    func testPreviewNormalizesWhitespaceWithoutChangingSource() {
        let source = "  one\n two\tthree  "

        XCTAssertEqual(
            ClipboardTextPresentation.normalized(source),
            "one two three")
        XCTAssertEqual(
            ClipboardTextPresentation.preview(source, maximumLength: 8),
            "one two…")
        XCTAssertEqual(source, "  one\n two\tthree  ")
    }
}
