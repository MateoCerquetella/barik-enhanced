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

        XCTAssertEqual(settings.profiles.count, 1)
        XCTAssertEqual(settings.profiles[0].name, "Office Tunnel")
        XCTAssertEqual(settings.profiles[0].tunnelName, "Office Tunnel")
        XCTAssertEqual(settings.profiles[0].gateway, "192.0.2.1")
        XCTAssertEqual(
            settings.refreshInterval,
            WireGuardWidgetSettings.minimumRefreshInterval)
        XCTAssertEqual(settings.profiles[0].peers, [
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
            settings.profiles[0].tunnelName,
            WireGuardWidgetSettings.defaultTunnelName)
        XCTAssertEqual(
            settings.profiles[0].gateway,
            WireGuardWidgetSettings.defaultGateway)
        XCTAssertEqual(
            settings.refreshInterval,
            WireGuardWidgetSettings.maximumRefreshInterval)
        XCTAssertTrue(settings.profiles[0].peers.isEmpty)
    }

    func testLegacyConfigCreatesOneEquivalentProfile() {
        let settings = WireGuardWidgetSettings(config: [
            "tunnel-name": .string("Office Tunnel"),
            "gateway": .string("192.0.2.1"),
            "refresh-interval": .int(60),
            "peers": .array([
                .string("Router=192.0.2.1"),
                .string("Node=198.51.100.10"),
            ]),
        ])

        XCTAssertEqual(settings.profiles, [
            WireGuardProfile(
                name: "Office Tunnel",
                tunnelName: "Office Tunnel",
                gateway: "192.0.2.1",
                peers: [
                    WireGuardPeer(name: "Router", address: "192.0.2.1"),
                    WireGuardPeer(name: "Node", address: "198.51.100.10"),
                ])
        ])
        XCTAssertEqual(settings.refreshInterval, 60)
    }

    func testInlineProfilesParseInOrderAndReplaceLegacyValues() {
        let settings = WireGuardWidgetSettings(config: [
            "tunnel-name": .string("Legacy"),
            "gateway": .string("203.0.113.1"),
            "refresh-interval": .int(60),
            "profiles": .array([
                .dictionary([
                    "name": .string("Office"),
                    "tunnel-name": .string("office-tunnel"),
                    "gateway": .string("192.0.2.1"),
                    "peers": .array([.string("Node=192.0.2.2")]),
                ]),
                .dictionary([
                    "name": .string("Backup"),
                    "tunnel-name": .string("backup-tunnel"),
                    "gateway": .string("198.51.100.1"),
                    "peers": .array([.string("Phone=198.51.100.2")]),
                ]),
            ]),
        ])

        XCTAssertEqual(settings.profiles, [
            WireGuardProfile(
                name: "Office", tunnelName: "office-tunnel", gateway: "192.0.2.1",
                peers: [WireGuardPeer(name: "Node", address: "192.0.2.2")]),
            WireGuardProfile(
                name: "Backup", tunnelName: "backup-tunnel", gateway: "198.51.100.1",
                peers: [WireGuardPeer(name: "Phone", address: "198.51.100.2")]),
        ])
        XCTAssertEqual(settings.refreshInterval, 60)
    }

    func testProfilesTrimValidateAndDeduplicateTunnelNames() {
        let valid: ConfigData = [
            "name": .string(" Office "),
            "tunnel-name": .string(" office-tunnel "),
            "gateway": .string(" 192.0.2.1 "),
            "peers": .array([
                .string(" Node = 192.0.2.2 "),
                .string("Node=192.0.2.2"),
            ]),
        ]
        var duplicate = valid
        duplicate["name"] = .string("Duplicate")
        var invalid = valid
        invalid["gateway"] = .string("not-an-ip")
        var wrongType = valid
        wrongType["peers"] = .string("Node=192.0.2.2")
        var invalidPeer = valid
        invalidPeer["peers"] = .array([.string("Bad=not-an-ip")])
        let settings = WireGuardWidgetSettings(config: [
            "profiles": .array([
                .string("not a profile"),
                .dictionary(invalid),
                .dictionary(wrongType),
                .dictionary(invalidPeer),
                .dictionary(valid),
                .dictionary(duplicate),
            ]),
        ])

        XCTAssertEqual(settings.profiles, [
            WireGuardProfile(
                name: "Office", tunnelName: "office-tunnel", gateway: "192.0.2.1",
                peers: [WireGuardPeer(name: "Node", address: "192.0.2.2")])
        ])
    }

    func testUnusableProfilesFallBackToLegacySettings() {
        let legacy: ConfigData = [
            "tunnel-name": .string("Legacy"),
            "gateway": .string("192.0.2.1"),
            "peers": .array([.string("Node=192.0.2.2")]),
        ]
        for profiles in [
            TOMLValue.array([]),
            .string("invalid"),
            .array([.dictionary(["name": .string("Missing fields")])]),
        ] {
            var config = legacy
            config["profiles"] = profiles
            XCTAssertEqual(
                WireGuardWidgetSettings(config: config),
                WireGuardWidgetSettings(config: legacy))
        }
    }

    func testCompactLabelsContainOnlyExactStatus() {
        XCTAssertEqual(WireGuardHealthStatus.healthy.compactLabel, "UP")
        XCTAssertEqual(WireGuardHealthStatus.disconnected.compactLabel, "OFF")
        XCTAssertEqual(WireGuardHealthStatus.degraded.compactLabel, "PROBE")
        XCTAssertEqual(WireGuardHealthStatus.checking.compactLabel, "CHECK")
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
                    terminationStatus: 0,
                    standardOutput: "Disconnecting\n",
                    standardError: "")),
            .disconnecting)
        XCTAssertEqual(
            SystemWireGuardTunnelStatusProvider.parseSCUtilStatus(
                WireGuardCommandResult(
                    terminationStatus: 1,
                    standardOutput: "Connected\n",
                    standardError: "No service")),
            .unknown)
    }
}
