import Darwin
import Foundation

enum WireGuardTunnelState: Equatable {
    case connected
    case disconnected
    case connecting
    case disconnecting
    case unknown

    var displayName: String {
        switch self {
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
        case .disconnecting:
            return "Disconnecting"
        case .unknown:
            return "Unknown"
        }
    }
}

enum WireGuardProbeState: Equatable {
    case reachable
    case unreachable
    case unknown

    var displayName: String {
        switch self {
        case .reachable:
            return "Reachable"
        case .unreachable:
            return "Unreachable"
        case .unknown:
            return "Unknown"
        }
    }
}

enum WireGuardHealthStatus: Equatable {
    case healthy
    case degraded
    case disconnected
    case checking

    static func resolve(
        tunnelState: WireGuardTunnelState,
        gatewayProbe: WireGuardProbeState,
        isChecking: Bool = false
    ) -> WireGuardHealthStatus {
        if isChecking {
            return .checking
        }

        switch tunnelState {
        case .connected:
            switch gatewayProbe {
            case .reachable:
                return .healthy
            case .unreachable:
                return .degraded
            case .unknown:
                return .checking
            }
        case .disconnected:
            return .disconnected
        case .connecting, .disconnecting, .unknown:
            return .checking
        }
    }

    var displayName: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .degraded:
            return "Degraded"
        case .disconnected:
            return "Disconnected"
        case .checking:
            return "Checking"
        }
    }

    var compactLabel: String {
        switch self {
        case .healthy:
            return "UP"
        case .degraded:
            return "PROBE"
        case .disconnected:
            return "OFF"
        case .checking:
            return "CHECK"
        }
    }
}

struct WireGuardPeer: Identifiable, Equatable {
    let name: String
    let address: String

    var id: String {
        "\(name)=\(address)"
    }

    static func parse(_ value: String) -> WireGuardPeer? {
        guard let separator = value.firstIndex(of: "=") else {
            return nil
        }

        let name = value[..<separator]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let address = value[value.index(after: separator)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, WireGuardIPAddress.isValid(address) else {
            return nil
        }

        return WireGuardPeer(name: name, address: address)
    }
}

enum WireGuardIPAddress {
    static func isValid(_ value: String) -> Bool {
        var ipv4 = in_addr()
        if value.withCString({ inet_pton(AF_INET, $0, &ipv4) }) == 1 {
            return true
        }

        var ipv6 = in6_addr()
        return value.withCString({ inet_pton(AF_INET6, $0, &ipv6) }) == 1
    }

    static func isIPv6(_ value: String) -> Bool {
        var address = in6_addr()
        return value.withCString({ inet_pton(AF_INET6, $0, &address) }) == 1
    }
}

struct WireGuardProfile: Identifiable, Equatable {
    let name: String
    let tunnelName: String
    let gateway: String
    let peers: [WireGuardPeer]

    var id: String { tunnelName }

    static func parse(_ config: ConfigData) -> WireGuardProfile? {
        guard
            let name = nonemptyString(config["name"]),
            let tunnelName = nonemptyString(config["tunnel-name"]),
            let gateway = nonemptyString(config["gateway"]),
            WireGuardIPAddress.isValid(gateway),
            let peerValues = config["peers"]?.arrayValue,
            peerValues.allSatisfy({
                $0.stringValue.flatMap(WireGuardPeer.parse) != nil
            })
        else {
            return nil
        }

        return WireGuardProfile(
            name: name,
            tunnelName: tunnelName,
            gateway: gateway,
            peers: parsedPeers(config["peers"]))
    }

    fileprivate static func nonemptyString(_ value: TOMLValue?) -> String? {
        guard let string = value?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !string.isEmpty
        else {
            return nil
        }
        return string
    }

    fileprivate static func parsedPeers(_ value: TOMLValue?) -> [WireGuardPeer] {
        var seenPeers: Set<String> = []
        return (value?.arrayValue ?? [])
            .compactMap(\.stringValue)
            .compactMap(WireGuardPeer.parse)
            .filter { seenPeers.insert($0.id).inserted }
    }
}

struct WireGuardWidgetSettings: Equatable {
    static let defaultTunnelName = "Example WireGuard"
    static let defaultGateway = "192.0.2.1"
    static let defaultRefreshInterval = 30
    static let minimumRefreshInterval = 10
    static let maximumRefreshInterval = 600

    let profiles: [WireGuardProfile]
    let refreshInterval: Int

    init(config: ConfigData) {
        let tunnelName = WireGuardProfile.nonemptyString(config["tunnel-name"])
            ?? Self.defaultTunnelName
        let gateway = WireGuardProfile.nonemptyString(config["gateway"]).flatMap {
            WireGuardIPAddress.isValid($0) ? $0 : nil
        } ?? Self.defaultGateway

        var seenTunnels: Set<String> = []
        let configuredProfiles = (config["profiles"]?.arrayValue ?? [])
            .compactMap(\.dictionaryValue)
            .compactMap(WireGuardProfile.parse)
            .filter { seenTunnels.insert($0.tunnelName).inserted }

        self.init(
            profiles: configuredProfiles.isEmpty
                ? [WireGuardProfile(
                    name: tunnelName,
                    tunnelName: tunnelName,
                    gateway: gateway,
                    peers: WireGuardProfile.parsedPeers(config["peers"]))]
                : configuredProfiles,
            refreshInterval: config["refresh-interval"]?.intValue
                ?? Self.defaultRefreshInterval)
    }

    init(
        profiles: [WireGuardProfile],
        refreshInterval: Int = defaultRefreshInterval
    ) {
        precondition(!profiles.isEmpty)
        self.profiles = profiles
        self.refreshInterval = Self.clampedRefreshInterval(refreshInterval)
    }

    init(
        tunnelName: String,
        gateway: String,
        refreshInterval: Int = defaultRefreshInterval,
        peers: [WireGuardPeer] = []
    ) {
        self.init(
            profiles: [WireGuardProfile(
                name: tunnelName,
                tunnelName: tunnelName,
                gateway: gateway,
                peers: peers)],
            refreshInterval: refreshInterval)
    }

    static func clampedRefreshInterval(_ value: Int) -> Int {
        min(max(value, minimumRefreshInterval), maximumRefreshInterval)
    }
}

struct WireGuardPeerProbe: Identifiable, Equatable {
    let peer: WireGuardPeer
    let state: WireGuardProbeState

    var id: String {
        peer.id
    }
}

struct WireGuardSnapshot: Equatable {
    let settings: WireGuardWidgetSettings?
    let activeProfile: WireGuardProfile?
    let profileStates: [WireGuardProfileState]
    let gatewayProbe: WireGuardProbeState
    let peerProbes: [WireGuardPeerProbe]
    let checkedAt: Date?

    static let initial = WireGuardSnapshot(
        settings: nil,
        activeProfile: nil,
        profileStates: [],
        gatewayProbe: .unknown,
        peerProbes: [],
        checkedAt: nil)

    var tunnelState: WireGuardTunnelState {
        profileStates.first { $0.profile.id == activeProfile?.id }?.state
            ?? .unknown
    }

    func peerProbe(for peer: WireGuardPeer) -> WireGuardProbeState {
        peerProbes.first(where: { $0.peer == peer })?.state ?? .unknown
    }
}

struct WireGuardProfileState: Identifiable, Equatable {
    let profile: WireGuardProfile
    let state: WireGuardTunnelState

    var id: String { profile.id }
}
