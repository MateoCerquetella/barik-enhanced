import XCTest
@testable import BarikEnhanced

final class WireGuardSettingsTests: XCTestCase {
    func testSettingsParsePeersAndClampRefreshInterval() {
        let settings = WireGuardWidgetSettings(config: [
            "tunnel-name": .string("  Office Tunnel  "),
            "gateway": .string(" 192.0.2.1 "),
            "refresh-interval": .int(2),
            "peers": .array([
                .string(" Router = 198.51.100.10 "),
                .string("Node=2001:db8::20"),
                .string("missing separator"),
                .string("Bad Address=not-an-ip"),
                .string("Router=198.51.100.10"),
            ]),
        ])

        XCTAssertEqual(settings.tunnelName, "Office Tunnel")
        XCTAssertEqual(settings.gateway, "192.0.2.1")
        XCTAssertEqual(
            settings.refreshInterval,
            WireGuardWidgetSettings.minimumRefreshInterval)
        XCTAssertEqual(settings.peers, [
            WireGuardPeer(name: "Router", address: "198.51.100.10"),
            WireGuardPeer(name: "Node", address: "2001:db8::20"),
        ])
    }

    func testSettingsUseSafeDefaultsAndUpperClamp() {
        let settings = WireGuardWidgetSettings(config: [
            "tunnel-name": .string("  "),
            "gateway": .string("not-an-ip"),
            "refresh-interval": .int(50_000),
        ])

        XCTAssertEqual(
            settings.tunnelName,
            WireGuardWidgetSettings.defaultTunnelName)
        XCTAssertEqual(
            settings.gateway,
            WireGuardWidgetSettings.defaultGateway)
        XCTAssertEqual(
            settings.refreshInterval,
            WireGuardWidgetSettings.maximumRefreshInterval)
        XCTAssertTrue(settings.peers.isEmpty)
    }

    func testSCUtilStatusParserUsesTheFirstStatusLine() {
        XCTAssertEqual(
            SystemWireGuardTunnelStatusProvider.parseSCUtilStatus(
                WireGuardCommandResult(
                    terminationStatus: 0,
                    standardOutput: "Connected\nExtended Status <dictionary> { }\n",
                    standardError: "")),
            .connected)
        XCTAssertEqual(
            SystemWireGuardTunnelStatusProvider.parseSCUtilStatus(
                WireGuardCommandResult(
                    terminationStatus: 0,
                    standardOutput: "Disconnected\n",
                    standardError: "")),
            .disconnected)
        XCTAssertEqual(
            SystemWireGuardTunnelStatusProvider.parseSCUtilStatus(
                WireGuardCommandResult(
                    terminationStatus: 1,
                    standardOutput: "Connected\n",
                    standardError: "No service")),
            .unknown)
    }
}
