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

    func testClipboardIsRegisteredInBothSelectionSurfaces() {
        XCTAssertEqual(
            allWidgets.filter { $0.id == "default.clipboard" }.count,
            1)
        XCTAssertTrue(
            MenuBarContextMenu.widgetEntries.contains {
                $0.id == "default.clipboard" && $0.name == "Clipboard"
            })
    }

    func testClipboardDispatcherAndDocumentedConfigArePresent() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let menuBarSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "BarikEnhanced/Views/MenuBarView.swift"),
            encoding: .utf8)
        let configSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "BarikEnhanced/Config/ConfigManager.swift"),
            encoding: .utf8)
        let readme = try String(
            contentsOf: repositoryRoot.appendingPathComponent("README.md"),
            encoding: .utf8)

        XCTAssertTrue(menuBarSource.contains("case \"default.clipboard\":"))
        for documentation in [configSource, readme] {
            XCTAssertTrue(
                documentation.contains("[widgets.default.meetings]"))
            XCTAssertTrue(
                documentation.contains("title-max-length = 32"))
            XCTAssertTrue(
                documentation.contains("[widgets.default.clipboard]"))
            XCTAssertTrue(documentation.contains("max-items = 10"))
            XCTAssertTrue(
                documentation.contains("preview-max-length = 40"))
        }
    }
}
