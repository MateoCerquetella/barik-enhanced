import AppKit
import SwiftUI
import XCTest
@testable import BarikEnhanced

@MainActor
final class WireGuardRenderingTests: XCTestCase {
    func testConnectedProfileWidgetAndPopupRender() throws {
        let settings = WireGuardWidgetSettings(profiles: [
            WireGuardProfile(
                name: "Office",
                tunnelName: "office-tunnel",
                gateway: "192.0.2.1",
                peers: [
                    WireGuardPeer(name: "Laptop", address: "192.0.2.2"),
                ]),
            WireGuardProfile(
                name: "Backup",
                tunnelName: "backup-tunnel",
                gateway: "198.51.100.1",
                peers: [
                    WireGuardPeer(name: "Phone", address: "198.51.100.2"),
                ]),
        ])
        let activeProfile = settings.profiles[1]
        let snapshot = WireGuardSnapshot(
            settings: settings,
            activeProfile: activeProfile,
            profileStates: [
                WireGuardProfileState(
                    profile: settings.profiles[0],
                    state: .disconnected),
                WireGuardProfileState(
                    profile: activeProfile,
                    state: .connected),
            ],
            gatewayProbe: .reachable,
            peerProbes: [
                WireGuardPeerProbe(
                    peer: activeProfile.peers[0],
                    state: .reachable),
            ],
            checkedAt: Date(timeIntervalSince1970: 2_000_000_000))

        try render(
            WireGuardWidgetContent(
                profile: activeProfile,
                status: .healthy,
                onOpenDetails: {})
                .padding(14)
                .foregroundStyle(.white)
                .background(.black),
            named: "barik-wireguard-widget")

        try render(
            WireGuardPopupContent(
                settings: settings,
                snapshot: snapshot,
                status: .healthy,
                isRefreshing: false,
                isChangingTunnel: false,
                actionError: nil,
                onRefresh: {},
                onSetConnected: { _, _ in })
                .background(.black),
            named: "barik-wireguard-popup")
    }

    private func render<Content: View>(
        _ content: Content,
        named name: String
    ) throws {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage)
        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        let pngData = try XCTUnwrap(
            bitmap.representation(using: .png, properties: [:]))

        try pngData.write(
            to: URL(fileURLWithPath: "/tmp/\(name).png"),
            options: .atomic)
        XCTAssertGreaterThan(pngData.count, 1_000)
        XCTAssertGreaterThan(image.size.width, 40)
        XCTAssertGreaterThan(image.size.height, 20)
    }
}
