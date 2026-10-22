import XCTest
@testable import BarikEnhanced

final class ConfigUpdateTests: XCTestCase {
    func testBackgroundToggleUpdatesNestedTableInPlace() {
        let original = """
        theme = "system"

        [experimental.background]
        displayed = false
        blur = 0
        """

        let updated = ConfigManager.shared.updatedTOMLString(
            original: original,
            key: "experimental.background.displayed",
            newValue: "true",
            wrapInQuotes: false)

        XCTAssertTrue(updated.contains("[experimental.background]"))
        XCTAssertTrue(updated.contains("displayed = true"))
        XCTAssertFalse(updated.contains("displayed = false"))

        let blurLine = updated
            .components(separatedBy: "\n")
            .first { $0.hasPrefix("blur") }
        XCTAssertEqual(blurLine?.trimmingCharacters(in: .whitespaces), "blur = 0")
    }

    func testBackgroundToggleAppendsMissingTable() {
        let updated = ConfigManager.shared.updatedTOMLString(
            original: "theme = \"system\"\n",
            key: "experimental.background.blur",
            newValue: "3",
            wrapInQuotes: false)

        XCTAssertTrue(updated.contains("[experimental.background]"))
        XCTAssertTrue(updated.contains("blur = 3"))
    }
}
