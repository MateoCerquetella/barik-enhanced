import Combine
import XCTest
@testable import BarikEnhanced

final class WireGuardManagerTests: XCTestCase {
    func testControllerPassesExactTunnelNameAsOneArgument() {
        let runner = RecordingWireGuardCommandRunner()
        let statusProvider = ScriptedTunnelStatusProvider(states: [
            "Office Tunnel": [.disconnected],
        ])
        let controller = SystemWireGuardTunnelController(
            commandRunner: runner,
            statusProvider: statusProvider,
            sleep: { _ in })
        let office = profile("Office", tunnel: "Office Tunnel")
        let backup = profile("Backup", tunnel: "Backup; Tunnel")

        XCTAssertTrue(controller.connect(profile: backup, among: [office, backup]))
        XCTAssertTrue(controller.disconnect(profile: backup))

        XCTAssertEqual(runner.executables, ["/usr/sbin/scutil", "/usr/sbin/scutil"])
        XCTAssertEqual(runner.arguments, [
            ["--nc", "start", "Backup; Tunnel"],
            ["--nc", "stop", "Backup; Tunnel"],
        ])
    }

    func testControllerPreservesCommandFailure() {
        let runner = RecordingWireGuardCommandRunner()
        runner.result = nil
        let controller = SystemWireGuardTunnelController(
            commandRunner: runner,
            statusProvider: ScriptedTunnelStatusProvider(states: [:]))

        XCTAssertFalse(
            controller.disconnect(
                profile: profile("Office", tunnel: "Office Tunnel")))
    }

    func testSwitchStopsConnectedProfileBeforeStartingTarget() {
        let runner = RecordingWireGuardCommandRunner()
        let statuses = ScriptedTunnelStatusProvider(states: [
            "office-tunnel": [.connected, .connecting, .disconnected],
        ])
        let controller = SystemWireGuardTunnelController(
            commandRunner: runner,
            statusProvider: statuses,
            statusCheckDelay: 0,
            sleep: { _ in })
        let office = profile("Office", tunnel: "office-tunnel")
        let backup = profile("Backup", tunnel: "backup-tunnel")

        XCTAssertTrue(controller.connect(profile: backup, among: [office, backup]))
        XCTAssertEqual(runner.arguments, [
            ["--nc", "stop", "office-tunnel"],
            ["--nc", "start", "backup-tunnel"],
        ])
        XCTAssertEqual(
            statuses.queries,
            ["office-tunnel", "office-tunnel", "office-tunnel"])
    }

    func testSwitchStopsEveryConfiguredActiveProfileAndLeavesOthersUntouched() {
        let runner = RecordingWireGuardCommandRunner()
        let statuses = ScriptedTunnelStatusProvider(states: [
            "office-tunnel": [.connected, .disconnected],
            "secondary-tunnel": [.connecting, .disconnected],
            "inactive-tunnel": [.disconnected],
            "unconfigured-tunnel": [.connected],
        ])
        let controller = SystemWireGuardTunnelController(
            commandRunner: runner,
            statusProvider: statuses,
            sleep: { _ in })
        let office = profile("Office", tunnel: "office-tunnel")
        let secondary = profile("Secondary", tunnel: "secondary-tunnel")
        let inactive = profile("Inactive", tunnel: "inactive-tunnel")
        let backup = profile("Backup", tunnel: "backup-tunnel")

        XCTAssertTrue(
            controller.connect(
                profile: backup,
                among: [office, secondary, inactive, backup]))
        XCTAssertEqual(runner.arguments, [
            ["--nc", "stop", "office-tunnel"],
            ["--nc", "stop", "secondary-tunnel"],
            ["--nc", "start", "backup-tunnel"],
        ])
        XCTAssertFalse(statuses.queries.contains("unconfigured-tunnel"))
    }

    func testSwitchDoesNotStartWhenStopCommandFails() {
        let runner = RecordingWireGuardCommandRunner()
        runner.result = WireGuardCommandResult(
            terminationStatus: 1, standardOutput: "", standardError: "Denied")
        let statuses = ScriptedTunnelStatusProvider(states: [
            "office-tunnel": [.connected],
        ])
        let controller = SystemWireGuardTunnelController(
            commandRunner: runner,
            statusProvider: statuses)
        let office = profile("Office", tunnel: "office-tunnel")
        let backup = profile("Backup", tunnel: "backup-tunnel")

        XCTAssertFalse(controller.connect(profile: backup, among: [office, backup]))
        XCTAssertEqual(runner.arguments, [["--nc", "stop", "office-tunnel"]])
    }

    func testSwitchDoesNotStartWhenDisconnectTimesOut() {
        let runner = RecordingWireGuardCommandRunner()
        let statuses = ScriptedTunnelStatusProvider(states: [
            "office-tunnel": [.connected, .connecting, .connecting],
        ])
        let controller = SystemWireGuardTunnelController(
            commandRunner: runner,
            statusProvider: statuses,
            statusCheckAttempts: 2,
            statusCheckDelay: 0,
            sleep: { _ in })
        let office = profile("Office", tunnel: "office-tunnel")
        let backup = profile("Backup", tunnel: "backup-tunnel")

        XCTAssertFalse(controller.connect(profile: backup, among: [office, backup]))
        XCTAssertEqual(runner.arguments, [["--nc", "stop", "office-tunnel"]])
    }

    func testSwitchDoesNotStartWhenStoppedProfileBecomesUnknown() {
        let runner = RecordingWireGuardCommandRunner()
        let statuses = ScriptedTunnelStatusProvider(states: [
            "office-tunnel": [.connected, .unknown],
        ])
        let controller = SystemWireGuardTunnelController(
            commandRunner: runner,
            statusProvider: statuses,
            statusCheckDelay: 0,
            sleep: { _ in })
        let office = profile("Office", tunnel: "office-tunnel")
        let backup = profile("Backup", tunnel: "backup-tunnel")

        XCTAssertFalse(controller.connect(profile: backup, among: [office, backup]))
        XCTAssertEqual(runner.arguments, [["--nc", "stop", "office-tunnel"]])
    }

    func testSwitchWaitsForAlreadyDisconnectingProfileWithoutStoppingAgain() {
        let runner = RecordingWireGuardCommandRunner()
        let statuses = ScriptedTunnelStatusProvider(states: [
            "office-tunnel": [.disconnecting, .disconnecting, .disconnected],
        ])
        let controller = SystemWireGuardTunnelController(
            commandRunner: runner,
            statusProvider: statuses,
            statusCheckDelay: 0,
            sleep: { _ in })
        let office = profile("Office", tunnel: "office-tunnel")
        let backup = profile("Backup", tunnel: "backup-tunnel")

        XCTAssertTrue(controller.connect(profile: backup, among: [office, backup]))
        XCTAssertEqual(runner.arguments, [["--nc", "start", "backup-tunnel"]])
    }

    func testSwitchDoesNotStartWhenOtherProfileStateIsUnknown() {
        let runner = RecordingWireGuardCommandRunner()
        let statuses = ScriptedTunnelStatusProvider(states: [
            "office-tunnel": [.unknown],
        ])
        let controller = SystemWireGuardTunnelController(
            commandRunner: runner,
            statusProvider: statuses)
        let office = profile("Office", tunnel: "office-tunnel")
        let backup = profile("Backup", tunnel: "backup-tunnel")

        XCTAssertFalse(controller.connect(profile: backup, among: [office, backup]))
        XCTAssertTrue(runner.arguments.isEmpty)
    }

    func testUnknownProfilePreventsPartialSwitch() {
        let runner = RecordingWireGuardCommandRunner()
        let statuses = ScriptedTunnelStatusProvider(states: [
            "office-tunnel": [.connected],
            "unknown-tunnel": [.unknown],
        ])
        let controller = SystemWireGuardTunnelController(
            commandRunner: runner,
            statusProvider: statuses)
        let office = profile("Office", tunnel: "office-tunnel")
        let unknown = profile("Unknown", tunnel: "unknown-tunnel")
        let backup = profile("Backup", tunnel: "backup-tunnel")

        XCTAssertFalse(
            controller.connect(
                profile: backup,
                among: [office, unknown, backup]))
        XCTAssertTrue(runner.arguments.isEmpty)
    }

    func testConnectSkipsStopWhenOtherProfilesAreDisconnected() {
        let runner = RecordingWireGuardCommandRunner()
        let statuses = ScriptedTunnelStatusProvider(states: [
            "office-tunnel": [.disconnected],
        ])
        let controller = SystemWireGuardTunnelController(
            commandRunner: runner,
            statusProvider: statuses)
        let office = profile("Office", tunnel: "office-tunnel")
        let backup = profile("Backup", tunnel: "backup-tunnel")

        XCTAssertTrue(controller.connect(profile: backup, among: [office, backup]))
        XCTAssertEqual(runner.arguments, [["--nc", "start", "backup-tunnel"]])
    }

    func testPopupActionSwitchesOnlyWhenAnotherProfileIsActive() {
        let office = profile("Office", tunnel: "office-tunnel")
        let backup = profile("Backup", tunnel: "backup-tunnel")

        XCTAssertEqual(
            WireGuardProfileAction.resolve(
                profile: backup,
                state: .disconnected,
                profileStates: [
                    WireGuardProfileState(profile: office, state: .connected),
                    WireGuardProfileState(profile: backup, state: .disconnected),
                ]),
            .switchProfile)
        XCTAssertEqual(
            WireGuardProfileAction.resolve(
                profile: backup,
                state: .disconnected,
                profileStates: [
                    WireGuardProfileState(profile: office, state: .disconnected),
                    WireGuardProfileState(profile: backup, state: .disconnected),
                ]),
            .connect)
        XCTAssertEqual(
            WireGuardProfileAction.resolve(
                profile: office,
                state: .connected,
                profileStates: []),
            .disconnect)
    }

    @MainActor
    func testConnectRefreshesSnapshotAndRetainsSelectionAfterDisconnect() {
        let settings = testSettings
        let runner = RecordingWireGuardCommandRunner()
        let checker = ActionAwareWireGuardChecker(runner: runner)
        let manager = WireGuardManager(
            checker: checker,
            controller: controller(runner: runner))
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
            ["--nc", "stop", "office-tunnel"],
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
            controller: controller(runner: runner))
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

    private func controller(
        runner: RecordingWireGuardCommandRunner
    ) -> SystemWireGuardTunnelController {
        SystemWireGuardTunnelController(
            commandRunner: runner,
            statusProvider: ScriptedTunnelStatusProvider(states: [
                "office-tunnel": [.connected, .disconnected],
            ]),
            sleep: { _ in })
    }

    private func profile(
        _ name: String,
        tunnel: String
    ) -> WireGuardProfile {
        WireGuardProfile(
            name: name,
            tunnelName: tunnel,
            gateway: "192.0.2.1",
            peers: [])
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

private final class ScriptedTunnelStatusProvider:
    WireGuardTunnelStatusProviding
{
    private var states: [String: [WireGuardTunnelState]]
    private(set) var queries: [String] = []

    init(states: [String: [WireGuardTunnelState]]) {
        self.states = states
    }

    func status(forTunnelNamed tunnelName: String) -> WireGuardTunnelState {
        queries.append(tunnelName)
        guard var tunnelStates = states[tunnelName],
            !tunnelStates.isEmpty
        else {
            return .unknown
        }
        let state = tunnelStates.removeFirst()
        states[tunnelName] = tunnelStates
        return state
    }
}
