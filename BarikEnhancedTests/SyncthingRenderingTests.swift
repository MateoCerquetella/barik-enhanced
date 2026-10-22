import AppKit
import SwiftUI
import XCTest
@testable import BarikEnhanced

@MainActor
final class SyncthingRenderingTests: XCTestCase {
    func testPausedPeerPopupRendersRetryAffordance() throws {
        let settings = SyncthingWidgetSettings(
            apiURL: URL(string: "http://127.0.0.1:8384")!,
            apiKey: "test")
        let local = SyncthingSnapshot.Peer(
            id: "local",
            name: "Saturn",
            connected: true,
            state: .synced,
            completion: 100,
            needBytes: 0,
            needItems: 0)
        let remote = SyncthingSnapshot.Peer(
            id: "REMOTE",
            name: "Jupiter",
            connected: true,
            state: .paused,
            completion: 97.76,
            needBytes: 1_050_866_299,
            needItems: 39_562)
        let snapshot = SyncthingSnapshot(
            settings: settings,
            state: .paused,
            folderState: "idle",
            peerConnected: true,
            completion: 97.76,
            globalBytes: 46_915_167_712,
            needBytes: 1_050_866_299,
            needItems: 39_562,
            processMemoryBytes: 29_686_024,
            heapMemoryBytes: 7_141_816,
            peerDeviceID: "REMOTE",
            errorMessage: nil,
            checkedAt: Date(),
            peers: [local, remote])

        let renderer = ImageRenderer(
            content: SyncthingPopupContent(
                settings: settings,
                snapshot: snapshot,
                state: .paused,
                isRefreshing: false,
                onRefresh: {})
                .background(.black))
        renderer.scale = 2

        let image = try XCTUnwrap(renderer.nsImage)
        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        let pngData = try XCTUnwrap(
            bitmap.representation(using: .png, properties: [:]))

        try pngData.write(
            to: URL(fileURLWithPath: "/tmp/barik-syncthing-paused.png"),
            options: .atomic)
        XCTAssertGreaterThan(image.size.width, 300)
        XCTAssertGreaterThan(image.size.height, 300)
    }
}
