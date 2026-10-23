import Foundation
import SystemConfiguration

struct WireGuardCommandResult: Equatable {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String
}

protocol WireGuardCommandRunning {
    func run(
        executable: String,
        arguments: [String]
    ) -> WireGuardCommandResult?
}

final class ProcessWireGuardCommandRunner: WireGuardCommandRunning {
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 4) {
        self.timeout = timeout
    }

    func run(
        executable: String,
        arguments: [String]
    ) -> WireGuardCommandResult? {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        let termination = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            termination.signal()
        }

        do {
            try process.run()
        } catch {
            return nil
        }

        guard termination.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            _ = termination.wait(timeout: .now() + 1)
            return nil
        }

        return WireGuardCommandResult(
            terminationStatus: process.terminationStatus,
            standardOutput: String(
                data: standardOutput.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8) ?? "",
            standardError: String(
                data: standardError.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8) ?? "")
    }
}

protocol WireGuardTunnelStatusProviding {
    func status(forTunnelNamed tunnelName: String) -> WireGuardTunnelState
}

/// Reads the official macOS WireGuard NetworkExtension service first. The
/// command fallback is kept isolated for systems where SystemConfiguration
/// cannot enumerate the service.
final class SystemWireGuardTunnelStatusProvider:
    WireGuardTunnelStatusProviding
{
    static let wireGuardInterfaceSubtype = "com.wireguard.macos"

    private let commandRunner: any WireGuardCommandRunning

    init(
        commandRunner: any WireGuardCommandRunning =
            ProcessWireGuardCommandRunner()
    ) {
        self.commandRunner = commandRunner
    }

    func status(forTunnelNamed tunnelName: String) -> WireGuardTunnelState {
        if let status = systemConfigurationStatus(
            forTunnelNamed: tunnelName)
        {
            return status
        }

        let result = commandRunner.run(
            executable: "/usr/sbin/scutil",
            arguments: ["--nc", "status", tunnelName])
        return Self.parseSCUtilStatus(result)
    }

    static func parseSCUtilStatus(
        _ result: WireGuardCommandResult?
    ) -> WireGuardTunnelState {
        guard let result, result.terminationStatus == 0 else {
            return .unknown
        }

        let firstLine = result.standardOutput
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })?
            .lowercased()

        switch firstLine {
        case "connected":
            return .connected
        case "connecting":
            return .connecting
        case "disconnecting":
            return .disconnecting
        case "disconnected":
            return .disconnected
        default:
            return .unknown
        }
    }

    private func systemConfigurationStatus(
        forTunnelNamed tunnelName: String
    ) -> WireGuardTunnelState? {
        guard
            let preferences = SCPreferencesCreate(
                nil,
                "BarikEnhanced.WireGuard" as NSString,
                nil),
            let copiedServices = SCNetworkServiceCopyAll(preferences)
        else {
            return nil
        }

        let services = copiedServices as NSArray
        for case let service as SCNetworkService in services {
            guard
                let name = SCNetworkServiceGetName(service),
                name as String == tunnelName,
                isWireGuardService(service)
            else {
                continue
            }

            guard SCNetworkServiceGetEnabled(service) else {
                return .disconnected
            }

            guard
                let serviceID = SCNetworkServiceGetServiceID(service),
                let connection = SCNetworkConnectionCreateWithServiceID(
                    nil,
                    serviceID,
                    nil,
                    nil)
            else {
                return .unknown
            }

            return Self.mapConnectionStatus(
                SCNetworkConnectionGetStatus(connection))
        }

        return nil
    }

    private func isWireGuardService(_ service: SCNetworkService) -> Bool {
        guard var interface = SCNetworkServiceGetInterface(service) else {
            return false
        }

        while true {
            if let interfaceType = SCNetworkInterfaceGetInterfaceType(interface),
                interfaceType as String == Self.wireGuardInterfaceSubtype
            {
                return true
            }

            guard let child = SCNetworkInterfaceGetInterface(interface) else {
                return false
            }
            interface = child
        }
    }

    private static func mapConnectionStatus(
        _ status: SCNetworkConnectionStatus
    ) -> WireGuardTunnelState {
        switch status {
        case .connected:
            return .connected
        case .connecting:
            return .connecting
        case .disconnecting:
            return .disconnecting
        case .disconnected:
            return .disconnected
        default:
            return .unknown
        }
    }
}

protocol WireGuardReachabilityProbing {
    func probe(address: String) -> WireGuardProbeState
}

final class SystemWireGuardReachabilityProbe:
    WireGuardReachabilityProbing
{
    private let commandRunner: any WireGuardCommandRunning

    init(
        commandRunner: any WireGuardCommandRunning =
            ProcessWireGuardCommandRunner()
    ) {
        self.commandRunner = commandRunner
    }

    func probe(address: String) -> WireGuardProbeState {
        guard WireGuardIPAddress.isValid(address) else {
            return .unknown
        }

        let executable = WireGuardIPAddress.isIPv6(address)
            ? "/sbin/ping6"
            : "/sbin/ping"
        let arguments = WireGuardIPAddress.isIPv6(address)
            ? ["-n", "-c", "1", address]
            : [
                "-n",
                "-c", "1",
                "-W", "1000",
                address,
            ]
        guard
            let result = commandRunner.run(
                executable: executable,
                arguments: arguments)
        else {
            return .unknown
        }

        return result.terminationStatus == 0 ? .reachable : .unreachable
    }
}

protocol WireGuardHealthChecking {
    func check(
        settings: WireGuardWidgetSettings,
        preferredProfile: WireGuardProfile?
    ) -> WireGuardSnapshot
}

protocol WireGuardTunnelControlling {
    func connect(
        profile: WireGuardProfile,
        among profiles: [WireGuardProfile]
    ) -> Bool
    func disconnect(profile: WireGuardProfile) -> Bool
}

final class SystemWireGuardTunnelController: WireGuardTunnelControlling {
    private let commandRunner: any WireGuardCommandRunning
    private let statusProvider: any WireGuardTunnelStatusProviding
    private let statusCheckAttempts: Int
    private let statusCheckDelay: TimeInterval
    private let sleep: (TimeInterval) -> Void

    init(
        commandRunner: any WireGuardCommandRunning =
            ProcessWireGuardCommandRunner(),
        statusProvider: (any WireGuardTunnelStatusProviding)? = nil,
        statusCheckAttempts: Int = 8,
        statusCheckDelay: TimeInterval = 0.25,
        sleep: @escaping (TimeInterval) -> Void = {
            Thread.sleep(forTimeInterval: $0)
        }
    ) {
        self.commandRunner = commandRunner
        self.statusProvider = statusProvider
            ?? SystemWireGuardTunnelStatusProvider(commandRunner: commandRunner)
        self.statusCheckAttempts = statusCheckAttempts
        self.statusCheckDelay = statusCheckDelay
        self.sleep = sleep
    }

    func connect(
        profile: WireGuardProfile,
        among profiles: [WireGuardProfile]
    ) -> Bool {
        let otherStates = profiles
            .filter { $0.id != profile.id }
            .map {
                (
                    profile: $0,
                    state: statusProvider.status(
                        forTunnelNamed: $0.tunnelName)
                )
            }
        guard otherStates.allSatisfy({ $0.state != .unknown }) else {
            return false
        }

        for other in otherStates {
            switch other.state {
            case .connected, .connecting:
                guard disconnect(profile: other.profile),
                    waitUntilDisconnected(other.profile)
                else {
                    return false
                }
            case .disconnecting:
                guard waitUntilDisconnected(other.profile) else {
                    return false
                }
            case .disconnected, .unknown:
                continue
            }
        }

        return run(
            action: "start",
            tunnelName: profile.tunnelName)
    }

    func disconnect(profile: WireGuardProfile) -> Bool {
        run(action: "stop", tunnelName: profile.tunnelName)
    }

    private func waitUntilDisconnected(_ profile: WireGuardProfile) -> Bool {
        for attempt in 0..<statusCheckAttempts {
            switch statusProvider.status(forTunnelNamed: profile.tunnelName) {
            case .disconnected:
                return true
            case .unknown:
                return false
            case .connected, .connecting, .disconnecting:
                if attempt + 1 < statusCheckAttempts {
                    sleep(statusCheckDelay)
                }
            }
        }
        return false
    }

    private func run(action: String, tunnelName: String) -> Bool {
        commandRunner.run(
            executable: "/usr/sbin/scutil",
            arguments: ["--nc", action, tunnelName])?.terminationStatus == 0
    }
}

final class WireGuardHealthChecker: WireGuardHealthChecking {
    private let tunnelStatusProvider: any WireGuardTunnelStatusProviding
    private let reachabilityProbe: any WireGuardReachabilityProbing
    private let now: () -> Date

    init(
        tunnelStatusProvider: any WireGuardTunnelStatusProviding =
            SystemWireGuardTunnelStatusProvider(),
        reachabilityProbe: any WireGuardReachabilityProbing =
            SystemWireGuardReachabilityProbe(),
        now: @escaping () -> Date = Date.init
    ) {
        self.tunnelStatusProvider = tunnelStatusProvider
        self.reachabilityProbe = reachabilityProbe
        self.now = now
    }

    func check(
        settings: WireGuardWidgetSettings,
        preferredProfile: WireGuardProfile? = nil
    ) -> WireGuardSnapshot {
        let profileStates = settings.profiles.map { profile in
            WireGuardProfileState(
                profile: profile,
                state: tunnelStatusProvider.status(
                    forTunnelNamed: profile.tunnelName))
        }
        let selected = profileStates.first { $0.state == .connected }
            ?? profileStates.first { $0.profile.id == preferredProfile?.id }
            ?? profileStates[0]
        let profile = selected.profile

        guard selected.state == .connected else {
            return WireGuardSnapshot(
                settings: settings,
                activeProfile: profile,
                profileStates: profileStates,
                gatewayProbe: .unknown,
                peerProbes: profile.peers.map {
                    WireGuardPeerProbe(peer: $0, state: .unknown)
                },
                checkedAt: now())
        }

        let gatewayProbe = reachabilityProbe.probe(
            address: profile.gateway)
        let peerProbes = profile.peers.map { peer in
            WireGuardPeerProbe(
                peer: peer,
                state: peer.address == profile.gateway
                    ? gatewayProbe
                    : reachabilityProbe.probe(address: peer.address))
        }

        return WireGuardSnapshot(
            settings: settings,
            activeProfile: profile,
            profileStates: profileStates,
            gatewayProbe: gatewayProbe,
            peerProbes: peerProbes,
            checkedAt: now())
    }
}
