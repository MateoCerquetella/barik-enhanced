import XCTest
@testable import BarikEnhanced

final class WireGuardRegistrationTests: XCTestCase {
    func testWireGuardIsRegisteredInBothSelectionSurfaces() {
        XCTAssertEqual(
            allWidgets.filter { $0.id == "default.wireguard" }.count,
            1)
        XCTAssertTrue(
            MenuBarContextMenu.widgetEntries.contains {
                $0.id == "default.wireguard" && $0.name == "WireGuard"
            })
    }

    func testDispatcherAndSafeDocumentedConfigurationArePresent() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let menuBarSource = try source(
            at: "BarikEnhanced/Views/MenuBarView.swift",
            repositoryRoot: repositoryRoot)
        let defaultConfigSource = try source(
            at: "BarikEnhanced/Config/ConfigManager.swift",
            repositoryRoot: repositoryRoot)
        let readme = try source(
            at: "README.md",
            repositoryRoot: repositoryRoot)

        XCTAssertTrue(menuBarSource.contains("case \"default.wireguard\":"))

        for documentation in [defaultConfigSource, readme] {
            XCTAssertTrue(
                documentation.contains("[widgets.default.wireguard]"))
            XCTAssertTrue(
                documentation.contains("tunnel-name = \"Example WireGuard\""))
            XCTAssertTrue(
                documentation.contains("gateway = \"192.0.2.1\""))
            XCTAssertTrue(documentation.contains("refresh-interval = 30"))
            XCTAssertTrue(
                documentation.contains(
                    "peers = [\"Example Router=198.51.100.10\", \"Example Node=203.0.113.20\"]"))
        }

        XCTAssertTrue(
            readme.contains(
                "not authoritative WireGuard or RouterOS handshake data"))
    }

    private func source(
        at path: String,
        repositoryRoot: URL
    ) throws -> String {
        try String(
            contentsOf: repositoryRoot.appendingPathComponent(path),
            encoding: .utf8)
    }
}
