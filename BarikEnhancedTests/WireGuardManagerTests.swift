import Combine
import XCTest
@testable import BarikEnhanced

final class WireGuardManagerTests: XCTestCase {
    func testControllerPassesExactTunnelNameAsOneArgument() {
        let runner = RecordingWireGuardCommandRunner()
        let controller = SystemWireGuardTunnelController(commandRunner: runner)

        XCTAssertEqual(
            controller.setConnected(true, tunnelName: "Office Tunnel"),
            runner.result)
        XCTAssertEqual(
            controller.setConnected(false, tunnelName: "Backup; Tunnel"),
            runner.result)

        XCTAssertEqual(runner.executables, ["/usr/sbin/scutil", "/usr/sbin/scutil"])
        XCTAssertEqual(runner.arguments, [
            ["--nc", "start", "Office Tunnel"],
            ["--nc", "stop", "Backup; Tunnel"],
        ])
    }

    func testControllerPreservesCommandFailure() {
        let runner = RecordingWireGuardCommandRunner()
        runner.result = nil
        let controller = SystemWireGuardTunnelController(commandRunner: runner)

        XCTAssertNil(controller.setConnected(true, tunnelName: "Office Tunnel"))
    }

    @MainActor
    func testConnectRefreshesSnapshotAndRetainsSelectionAfterDisconnect() {
        let settings = testSettings
        let runner = RecordingWireGuardCommandRunner()
        let checker = ActionAwareWireGuardChecker(runner: runner)
        let manager = WireGuardManager(
            checker: checker,
            controller: SystemWireGuardTunnelController(commandRunner: runner))
        let clientID = UUID()
        defer { manager.deactivate(clientID: clientID) }
        let initial = expectation(description: "Initial refresh")
        let connected = expectation(description: "Refresh after connect")
        let disconnected = expectation(description: "Refresh after disconnect")
        var snapshots: [WireGuardSnapshot] = []
        let subscription = manager.$snapshot.dropFirst().sink { snapshot in
            snapshots.append(snapshot)
            switch snapshots.count {
            case 1: initial.fulfill()
            case 2: connected.fulfill()
            case 3: disconnected.fulfill()
            default: XCTFail("Unexpected refresh")
            }
        }
        defer { subscription.cancel() }

        manager.activate(clientID: clientID, settings: settings)
        wait(for: [initial], timeout: 2)
        manager.setConnected(true, profile: settings.profiles[1])
        wait(for: [connected], timeout: 2)

        XCTAssertEqual(manager.snapshot.activeProfile, settings.profiles[1])
        XCTAssertEqual(manager.healthStatus(for: settings), .healthy)
        XCTAssertFalse(manager.isChangingTunnel)
        XCTAssertNil(manager.actionError)

        manager.setConnected(false, profile: settings.profiles[1])
        wait(for: [disconnected], timeout: 2)

        XCTAssertEqual(snapshots.count, 3)
        XCTAssertEqual(manager.snapshot.activeProfile, settings.profiles[1])
        XCTAssertEqual(manager.healthStatus(for: settings), .disconnected)
        let preferredNames: [String?] = [nil, "Office", "Backup"]
        XCTAssertEqual(
            checker.preferredProfiles.map { $0?.name },
            preferredNames)
        XCTAssertEqual(runner.arguments, [
            ["--nc", "start", "backup-tunnel"],
            ["--nc", "stop", "backup-tunnel"],
        ])
    }

    @MainActor
    func testFailedActionStillRefreshesAndReportsError() {
        let settings = testSettings
        let runner = RecordingWireGuardCommandRunner()
        runner.result = WireGuardCommandResult(
            terminationStatus: 1, standardOutput: "", standardError: "Denied")
        let checker = ActionAwareWireGuardChecker(runner: runner)
        let manager = WireGuardManager(
            checker: checker,
            controller: SystemWireGuardTunnelController(commandRunner: runner))
        let clientID = UUID()
        defer { manager.deactivate(clientID: clientID) }
        let initial = expectation(description: "Initial refresh")
        let refreshed = expectation(description: "Refresh after failed action")
        var count = 0
        let subscription = manager.$snapshot.dropFirst().sink { _ in
            count += 1
            if count == 1 { initial.fulfill() }
            if count == 2 { refreshed.fulfill() }
        }
        defer { subscription.cancel() }

        manager.activate(clientID: clientID, settings: settings)
        wait(for: [initial], timeout: 2)
        manager.setConnected(true, profile: settings.profiles[1])
        wait(for: [refreshed], timeout: 2)

        XCTAssertEqual(count, 2)
        XCTAssertFalse(manager.isChangingTunnel)
        XCTAssertEqual(manager.actionError, "Could not connect Backup.")
        XCTAssertEqual(manager.healthStatus(for: settings), .disconnected)
    }

    private var testSettings: WireGuardWidgetSettings {
        WireGuardWidgetSettings(profiles: [
            WireGuardProfile(
                name: "Office", tunnelName: "office-tunnel", gateway: "192.0.2.1", peers: []),
            WireGuardProfile(
                name: "Backup", tunnelName: "backup-tunnel", gateway: "198.51.100.1", peers: []),
        ])
    }
}

private final class RecordingWireGuardCommandRunner: WireGuardCommandRunning {
    var result: WireGuardCommandResult? = WireGuardCommandResult(
        terminationStatus: 0, standardOutput: "", standardError: "")
    private(set) var executables: [String] = []
    private(set) var arguments: [[String]] = []

    func run(executable: String, arguments: [String]) -> WireGuardCommandResult? {
        executables.append(executable)
        self.arguments.append(arguments)
        return result
    }
}

private final class ActionAwareWireGuardChecker: WireGuardHealthChecking {
    let runner: RecordingWireGuardCommandRunner
    private(set) var preferredProfiles: [WireGuardProfile?] = []

    init(runner: RecordingWireGuardCommandRunner) {
        self.runner = runner
    }

    func check(
        settings: WireGuardWidgetSettings,
        preferredProfile: WireGuardProfile?
    ) -> WireGuardSnapshot {
        preferredProfiles.append(preferredProfile)
        let command = runner.arguments.last
        let connectedTunnel = runner.result?.terminationStatus == 0
            && command?.dropFirst().first == "start" ? command?.last : nil
        let states = settings.profiles.map {
            WireGuardProfileState(
                profile: $0,
                state: $0.tunnelName == connectedTunnel ? .connected : .disconnected)
        }
        let active = states.first { $0.state == .connected }?.profile
            ?? preferredProfile ?? settings.profiles[0]
        return WireGuardSnapshot(
            settings: settings,
            activeProfile: active,
            profileStates: states,
            gatewayProbe: connectedTunnel == nil ? .unknown : .reachable,
            peerProbes: [],
            checkedAt: Date())
    }
}
