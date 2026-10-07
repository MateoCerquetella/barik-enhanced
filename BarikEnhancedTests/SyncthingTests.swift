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

    func testLocalCompletionUsesFolderDatabaseTotals() {
        XCTAssertEqual(
            SyncthingSnapshot.localCompletion(
                globalBytes: 1_000,
                needBytes: 250),
            75)
        XCTAssertEqual(
            SyncthingSnapshot.localCompletion(
                globalBytes: 0,
                needBytes: 0),
            100)
    }

    func testDisconnectedMachineWinsOverallStatus() {
        let peers = [
            SyncthingSnapshot.Peer(
                id: "local",
                name: "Saturn",
                connected: true,
                state: .syncing,
                completion: 80,
                needBytes: 20,
                needItems: 1),
            SyncthingSnapshot.Peer(
                id: "jupiter",
                name: "Jupiter",
                connected: false,
                state: .disconnected,
                completion: 100,
                needBytes: 0,
                needItems: 0),
        ]

        XCTAssertEqual(
            SyncthingSnapshot.leastSyncedPeer(in: peers)?.id,
            "jupiter")
    }

    func testFolderDeviceListDoesNotDuplicateLocalDevice() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SyncthingTestURLProtocol.self]
        let client = SyncthingAPIClient(
            session: URLSession(configuration: configuration))
        let settings = SyncthingWidgetSettings(
            apiURL: URL(string: "http://127.0.0.1:8384")!,
            apiKey: "test")

        let snapshot = client.fetch(settings: settings)

        XCTAssertNil(snapshot.errorMessage)
        XCTAssertEqual(snapshot.peers.map(\.name), ["Saturn", "jupiter"])
        XCTAssertEqual(snapshot.peers.count, 2)
        XCTAssertTrue(snapshot.peerConnected)
        XCTAssertEqual(snapshot.state, .synced)
    }
}

private final class SyncthingTestURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response: String
        switch request.url?.path {
        case "/rest/system/status":
            response = #"{"myID":"LOCAL","alloc":8500000,"sys":26400000}"#
        case "/rest/db/status":
            response = #"{"state":"idle","globalBytes":100,"needBytes":0,"needFiles":0,"needDirectories":0,"needDeletes":0}"#
        case "/rest/config/devices":
            response = #"[{"deviceID":"LOCAL","name":"saturn"},{"deviceID":"REMOTE","name":"jupiter"}]"#
        case "/rest/config/folders/developer":
            response = #"{"devices":[{"deviceID":"LOCAL"},{"deviceID":"REMOTE"}]}"#
        case "/rest/system/connections":
            response = #"{"connections":{"REMOTE":{"connected":true}}}"#
        case "/rest/db/completion":
            response = #"{"completion":100,"needBytes":0,"needItems":0}"#
        default:
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let httpResponse = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
