import XCTest
@testable import BarikEnhanced

final class WireGuardHealthTests: XCTestCase {
    func testHealthStateMatrix() {
        XCTAssertEqual(
            WireGuardHealthStatus.resolve(
                tunnelState: .connected,
                gatewayProbe: .reachable),
            .healthy)
        XCTAssertEqual(
            WireGuardHealthStatus.resolve(
                tunnelState: .connected,
                gatewayProbe: .unreachable),
            .degraded)
        XCTAssertEqual(
            WireGuardHealthStatus.resolve(
                tunnelState: .disconnected,
                gatewayProbe: .unknown),
            .disconnected)
        XCTAssertEqual(
            WireGuardHealthStatus.resolve(
                tunnelState: .connected,
                gatewayProbe: .reachable,
                isChecking: true),
            .checking)
        XCTAssertEqual(
            WireGuardHealthStatus.resolve(
                tunnelState: .unknown,
                gatewayProbe: .unknown),
            .checking)
        XCTAssertEqual(
            WireGuardHealthStatus.resolve(
                tunnelState: .disconnecting,
                gatewayProbe: .reachable),
            .checking)
    }

    func testConnectedTunnelProbesGatewayAndEveryPeer() {
        let peer = WireGuardPeer(
            name: "Example Node",
            address: "198.51.100.10")
        let settings = WireGuardWidgetSettings(
            tunnelName: "Example WireGuard",
            gateway: "192.0.2.1",
            peers: [peer])
        let probe = RecordingWireGuardProbe(states: [
            "192.0.2.1": .reachable,
            "198.51.100.10": .unreachable,
        ])
        let checkedAt = Date(timeIntervalSince1970: 123)
        let checker = WireGuardHealthChecker(
            tunnelStatusProvider: StubWireGuardTunnelStatusProvider(
                state: .connected),
            reachabilityProbe: probe,
            now: { checkedAt })

        let snapshot = checker.check(settings: settings)

        XCTAssertEqual(snapshot.tunnelState, .connected)
        XCTAssertEqual(snapshot.gatewayProbe, .reachable)
        XCTAssertEqual(snapshot.peerProbe(for: peer), .unreachable)
        XCTAssertEqual(snapshot.checkedAt, checkedAt)
        XCTAssertEqual(probe.addresses, ["192.0.2.1", "198.51.100.10"])
    }

    func testDisconnectedTunnelSkipsAllProbes() {
        let peer = WireGuardPeer(
            name: "Example Node",
            address: "198.51.100.10")
        let settings = WireGuardWidgetSettings(
            tunnelName: "Example WireGuard",
            gateway: "192.0.2.1",
            peers: [peer])
        let probe = RecordingWireGuardProbe(states: [:])
        let checker = WireGuardHealthChecker(
            tunnelStatusProvider: StubWireGuardTunnelStatusProvider(
                state: .disconnected),
            reachabilityProbe: probe)

        let snapshot = checker.check(settings: settings)

        XCTAssertEqual(snapshot.gatewayProbe, .unknown)
        XCTAssertEqual(snapshot.peerProbe(for: peer), .unknown)
        XCTAssertTrue(probe.addresses.isEmpty)
    }

    func testPeerMatchingGatewayReusesGatewayProbe() {
        let peer = WireGuardPeer(
            name: "Example Router",
            address: "192.0.2.1")
        let settings = WireGuardWidgetSettings(
            tunnelName: "Example WireGuard",
            gateway: "192.0.2.1",
            peers: [peer])
        let probe = RecordingWireGuardProbe(states: [
            "192.0.2.1": .reachable,
        ])
        let checker = WireGuardHealthChecker(
            tunnelStatusProvider: StubWireGuardTunnelStatusProvider(
                state: .connected),
            reachabilityProbe: probe)

        let snapshot = checker.check(settings: settings)

        XCTAssertEqual(snapshot.gatewayProbe, .reachable)
        XCTAssertEqual(snapshot.peerProbe(for: peer), .reachable)
        XCTAssertEqual(probe.addresses, ["192.0.2.1"])
    }

    func testOnlyConnectedProfileIsProbedAndEveryTunnelIsQueried() {
        let profiles = testProfiles
        let provider = RecordingWireGuardTunnelStatusProvider(states: [
            "office-tunnel": .disconnected,
            "backup-tunnel": .connected,
        ])
        let probe = RecordingWireGuardProbe(states: [
            "198.51.100.1": .reachable,
            "198.51.100.2": .unreachable,
        ])
        let checker = WireGuardHealthChecker(
            tunnelStatusProvider: provider,
            reachabilityProbe: probe)

        let snapshot = checker.check(
            settings: WireGuardWidgetSettings(profiles: profiles),
            preferredProfile: profiles[0])

        XCTAssertEqual(provider.tunnels, ["office-tunnel", "backup-tunnel"])
        XCTAssertEqual(snapshot.activeProfile, profiles[1])
        XCTAssertEqual(snapshot.profileStates, [
            WireGuardProfileState(profile: profiles[0], state: .disconnected),
            WireGuardProfileState(profile: profiles[1], state: .connected),
        ])
        XCTAssertEqual(snapshot.tunnelState, .connected)
        XCTAssertEqual(snapshot.gatewayProbe, .reachable)
        XCTAssertEqual(snapshot.peerProbes, [
            WireGuardPeerProbe(peer: profiles[1].peers[0], state: .unreachable)
        ])
        XCTAssertEqual(probe.addresses, ["198.51.100.1", "198.51.100.2"])
        XCTAssertEqual(WireGuardHealthStatus.healthy.compactLabel, "UP")
    }

    func testFirstConnectedProfileWinsOverPreferredProfile() {
        let profiles = testProfiles
        let probe = RecordingWireGuardProbe(states: [:])
        let checker = WireGuardHealthChecker(
            tunnelStatusProvider: StubWireGuardTunnelStatusProvider(state: .connected),
            reachabilityProbe: probe)

        let snapshot = checker.check(
            settings: WireGuardWidgetSettings(profiles: profiles),
            preferredProfile: profiles[1])

        XCTAssertEqual(snapshot.activeProfile, profiles[0])
        XCTAssertEqual(probe.addresses, ["192.0.2.1", "192.0.2.2"])
    }

    func testNoConnectedProfileRetainsPreferredProfileWithoutProbing() {
        let profiles = testProfiles
        let probe = RecordingWireGuardProbe(states: [:])
        let checker = WireGuardHealthChecker(
            tunnelStatusProvider: StubWireGuardTunnelStatusProvider(state: .disconnected),
            reachabilityProbe: probe)

        let snapshot = checker.check(
            settings: WireGuardWidgetSettings(profiles: profiles),
            preferredProfile: profiles[1])

        XCTAssertEqual(snapshot.activeProfile, profiles[1])
        XCTAssertEqual(snapshot.tunnelState, .disconnected)
        XCTAssertEqual(snapshot.gatewayProbe, .unknown)
        XCTAssertEqual(snapshot.peerProbes, [
            WireGuardPeerProbe(peer: profiles[1].peers[0], state: .unknown)
        ])
        XCTAssertEqual(
            WireGuardHealthStatus.resolve(
                tunnelState: snapshot.tunnelState,
                gatewayProbe: snapshot.gatewayProbe).compactLabel,
            "OFF")
        XCTAssertTrue(probe.addresses.isEmpty)
    }

    func testNoConnectedProfileDefaultsToFirstWhenPreferredProfileIsMissing() {
        let profiles = testProfiles
        let probe = RecordingWireGuardProbe(states: [:])
        let checker = WireGuardHealthChecker(
            tunnelStatusProvider: StubWireGuardTunnelStatusProvider(state: .disconnected),
            reachabilityProbe: probe)
        let removedProfile = WireGuardProfile(
            name: "Removed", tunnelName: "removed", gateway: "203.0.113.1", peers: [])
        let preferredProfiles: [WireGuardProfile?] = [nil, removedProfile]

        for preferred in preferredProfiles {
            let snapshot = checker.check(
                settings: WireGuardWidgetSettings(profiles: profiles),
                preferredProfile: preferred)
            XCTAssertEqual(snapshot.activeProfile, profiles[0])
        }
        XCTAssertTrue(probe.addresses.isEmpty)
    }

    private var testProfiles: [WireGuardProfile] {
        [
            WireGuardProfile(
                name: "Office", tunnelName: "office-tunnel", gateway: "192.0.2.1",
                peers: [WireGuardPeer(name: "Node", address: "192.0.2.2")]),
            WireGuardProfile(
                name: "Backup", tunnelName: "backup-tunnel", gateway: "198.51.100.1",
                peers: [WireGuardPeer(name: "Phone", address: "198.51.100.2")]),
        ]
    }
}

private struct StubWireGuardTunnelStatusProvider:
    WireGuardTunnelStatusProviding
{
    let state: WireGuardTunnelState

    func status(forTunnelNamed tunnelName: String) -> WireGuardTunnelState {
        state
    }
}

private final class RecordingWireGuardProbe: WireGuardReachabilityProbing {
    private let states: [String: WireGuardProbeState]
    private(set) var addresses: [String] = []

    init(states: [String: WireGuardProbeState]) {
        self.states = states
    }

    func probe(address: String) -> WireGuardProbeState {
        addresses.append(address)
        return states[address] ?? .unknown
    }
}

private final class RecordingWireGuardTunnelStatusProvider:
    WireGuardTunnelStatusProviding
{
    let states: [String: WireGuardTunnelState]
    private(set) var tunnels: [String] = []

    init(states: [String: WireGuardTunnelState]) {
        self.states = states
    }

    func status(forTunnelNamed tunnelName: String) -> WireGuardTunnelState {
        tunnels.append(tunnelName)
        return states[tunnelName] ?? .unknown
    }
}
