import XCTest
@testable import BarikEnhanced

final class SyncthingTests: XCTestCase {
    func testSettingsParseAndClampConfiguration() {
        let settings = SyncthingWidgetSettings(config: [
            "api-url": .string(" http://127.0.0.1:8384 "),
            "api-key": .string(" secret "),
            "folder-id": .string(" developer "),
            "local-name": .string(" Saturn "),
            "peer-name": .string(" Jupiter "),
            "peer-device-id": .string(" DEVICE-ID "),
            "refresh-interval": .int(2),
        ])

        XCTAssertEqual(
            settings.apiURL.absoluteString,
            "http://127.0.0.1:8384")
        XCTAssertEqual(settings.apiKey, "secret")
        XCTAssertEqual(settings.folderID, "developer")
        XCTAssertEqual(settings.localName, "Saturn")
        XCTAssertEqual(settings.peerName, "Jupiter")
        XCTAssertEqual(settings.peerDeviceID, "DEVICE-ID")
        XCTAssertEqual(
            settings.refreshInterval,
            SyncthingWidgetSettings.minimumRefreshInterval)
        XCTAssertTrue(settings.isConfigured)
    }

    func testSettingsRejectUnsafeOrMalformedAPIURL() {
        let settings = SyncthingWidgetSettings(config: [
            "api-url": .string("file:///tmp/syncthing"),
            "refresh-interval": .int(50_000),
        ])

        XCTAssertEqual(
            settings.apiURL.absoluteString,
            SyncthingWidgetSettings.defaultAPIURL)
        XCTAssertEqual(
            settings.refreshInterval,
            SyncthingWidgetSettings.maximumRefreshInterval)
        XCTAssertFalse(settings.isConfigured)
    }

    func testStateResolutionTracksProgressAndConnectivity() {
        XCTAssertEqual(
            SyncthingSnapshot.resolvedState(
                folderState: "idle",
                peerConnected: true,
                completion: 100),
            .synced)
        XCTAssertEqual(
            SyncthingSnapshot.resolvedState(
                folderState: "syncing",
                peerConnected: true,
                completion: 42),
            .syncing)
        XCTAssertEqual(
            SyncthingSnapshot.resolvedState(
                folderState: "scanning",
                peerConnected: true,
                completion: 100),
            .scanning)
        XCTAssertEqual(
            SyncthingSnapshot.resolvedState(
                folderState: "idle",
                peerConnected: false,
                completion: 100),
            .disconnected)
    }
}
