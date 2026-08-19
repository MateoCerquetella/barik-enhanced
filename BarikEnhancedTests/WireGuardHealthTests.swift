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
