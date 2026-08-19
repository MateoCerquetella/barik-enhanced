import Darwin
import Foundation

enum WireGuardTunnelState: Equatable {
    case connected
    case disconnected
    case connecting
    case unknown

    var displayName: String {
        switch self {
        case .connected:
            return "Connected"
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting"
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
        case .connecting, .unknown:
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

struct WireGuardWidgetSettings: Equatable {
    static let defaultTunnelName = "Example WireGuard"
    static let defaultGateway = "192.0.2.1"
    static let defaultRefreshInterval = 30
    static let minimumRefreshInterval = 10
    static let maximumRefreshInterval = 600

    let tunnelName: String
    let gateway: String
    let refreshInterval: Int
    let peers: [WireGuardPeer]

    init(config: ConfigData) {
        let configuredTunnel = config["tunnel-name"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        tunnelName = configuredTunnel.flatMap { $0.isEmpty ? nil : $0 }
            ?? Self.defaultTunnelName

        let configuredGateway = config["gateway"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        gateway = configuredGateway.flatMap {
            WireGuardIPAddress.isValid($0) ? $0 : nil
        } ?? Self.defaultGateway

        refreshInterval = Self.clampedRefreshInterval(
            config["refresh-interval"]?.intValue
                ?? Self.defaultRefreshInterval)

        var seenPeers: Set<String> = []
        peers = (config["peers"]?.arrayValue ?? [])
            .compactMap(\.stringValue)
            .compactMap(WireGuardPeer.parse)
            .filter { seenPeers.insert($0.id).inserted }
    }

    init(
        tunnelName: String,
        gateway: String,
        refreshInterval: Int = defaultRefreshInterval,
        peers: [WireGuardPeer] = []
    ) {
        self.tunnelName = tunnelName
        self.gateway = gateway
        self.refreshInterval = Self.clampedRefreshInterval(refreshInterval)
        self.peers = peers
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
    let tunnelState: WireGuardTunnelState
    let gatewayProbe: WireGuardProbeState
    let peerProbes: [WireGuardPeerProbe]
    let checkedAt: Date?

    static let initial = WireGuardSnapshot(
        settings: nil,
        tunnelState: .unknown,
        gatewayProbe: .unknown,
        peerProbes: [],
        checkedAt: nil)

    func peerProbe(for peer: WireGuardPeer) -> WireGuardProbeState {
        peerProbes.first(where: { $0.peer == peer })?.state ?? .unknown
    }
}
