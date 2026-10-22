import Foundation

enum SyncthingState: Equatable {
    case synced
    case syncing
    case scanning
    case disconnected
    case paused
    case unavailable
    case checking

    var displayName: String {
        switch self {
        case .synced: return "In Sync"
        case .syncing: return "Syncing"
        case .scanning: return "Scanning"
        case .disconnected: return "Peer Offline"
        case .paused: return "Paused"
        case .unavailable: return "Unavailable"
        case .checking: return "Checking"
        }
    }

    var compactLabel: String {
        switch self {
        case .synced: return "SYNC"
        case .syncing: return "SYNCING"
        case .scanning: return "SCAN"
        case .disconnected: return "OFFLINE"
        case .paused: return "PAUSED"
        case .unavailable: return "ERROR"
        case .checking: return "CHECK"
        }
    }
}

struct SyncthingWidgetSettings: Equatable {
    static let defaultAPIURL = "http://127.0.0.1:8384"
    static let defaultFolderID = "developer"
    static let defaultLocalName = "Saturn"
    static let defaultPeerName = "Jupiter"
    static let defaultRefreshInterval = 15
    static let minimumRefreshInterval = 5
    static let maximumRefreshInterval = 600

    let apiURL: URL
    let apiKey: String
    let folderID: String
    let localName: String
    let peerName: String
    let peerDeviceID: String?
    let refreshInterval: Int

    init(config: ConfigData) {
        let configuredURL = config["api-url"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        apiURL = Self.validAPIURL(configuredURL)
            ?? URL(string: Self.defaultAPIURL)!
        apiKey = config["api-key"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        folderID = Self.nonEmpty(
            config["folder-id"]?.stringValue,
            fallback: Self.defaultFolderID)
        localName = Self.nonEmpty(
            config["local-name"]?.stringValue,
            fallback: Self.defaultLocalName)
        peerName = Self.nonEmpty(
            config["peer-name"]?.stringValue,
            fallback: Self.defaultPeerName)
        peerDeviceID = config["peer-device-id"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        refreshInterval = min(
            max(
                config["refresh-interval"]?.intValue
                    ?? Self.defaultRefreshInterval,
                Self.minimumRefreshInterval),
            Self.maximumRefreshInterval)
    }

    init(
        apiURL: URL,
        apiKey: String,
        folderID: String = defaultFolderID,
        localName: String = defaultLocalName,
        peerName: String = defaultPeerName,
        peerDeviceID: String? = nil,
        refreshInterval: Int = defaultRefreshInterval
    ) {
        self.apiURL = apiURL
        self.apiKey = apiKey
        self.folderID = folderID
        self.localName = localName
        self.peerName = peerName
        self.peerDeviceID = peerDeviceID
        self.refreshInterval = min(
            max(refreshInterval, Self.minimumRefreshInterval),
            Self.maximumRefreshInterval)
    }

    var isConfigured: Bool {
        !apiKey.isEmpty
    }

    private static func validAPIURL(_ value: String?) -> URL? {
        guard let value, let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else {
            return nil
        }
        return url
    }

    private static func nonEmpty(_ value: String?, fallback: String) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? fallback
    }
}

struct SyncthingSnapshot: Equatable {
    struct Peer: Equatable, Identifiable {
        let id: String
        let name: String
        let connected: Bool
        let state: SyncthingState
        let completion: Double
        let needBytes: Int64
        let needItems: Int
    }

    let settings: SyncthingWidgetSettings?
    let state: SyncthingState
    let folderState: String?
    let peerConnected: Bool
    let completion: Double
    let globalBytes: Int64
    let needBytes: Int64
    let needItems: Int
    let processMemoryBytes: Int64
    let heapMemoryBytes: Int64
    let peerDeviceID: String?
    let errorMessage: String?
    let checkedAt: Date?
    let peers: [Peer]

    static let initial = SyncthingSnapshot(
        settings: nil,
        state: .checking,
        folderState: nil,
        peerConnected: false,
        completion: 0,
        globalBytes: 0,
        needBytes: 0,
        needItems: 0,
        processMemoryBytes: 0,
        heapMemoryBytes: 0,
        peerDeviceID: nil,
        errorMessage: nil,
        checkedAt: nil,
        peers: [])

    var syncedBytes: Int64 {
        max(0, globalBytes - needBytes)
    }

    var worstPeer: Peer? {
        Self.leastSyncedPeer(in: peers)
    }

    static func localCompletion(
        globalBytes: Int64,
        needBytes: Int64
    ) -> Double {
        guard globalBytes > 0 else { return needBytes == 0 ? 100 : 0 }
        let completed = Double(max(0, globalBytes - needBytes))
        return min(max(completed / Double(globalBytes) * 100, 0), 100)
    }

    static func leastSyncedPeer(in peers: [Peer]) -> Peer? {
        peers.min { lhs, rhs in
            let lhsPriority = statePriority(lhs.state)
            let rhsPriority = statePriority(rhs.state)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.completion < rhs.completion
        }
    }

    private static func statePriority(_ state: SyncthingState) -> Int {
        switch state {
        case .unavailable: return 0
        case .paused: return 0
        case .disconnected: return 1
        case .syncing: return 2
        case .scanning: return 3
        case .checking: return 4
        case .synced: return 5
        }
    }

    /// Resolves a peer's state from `/rest/db/completion`.
    ///
    /// `remoteState` only reports whether the peer shares the folder and whether
    /// it has it paused. It never says "syncing", so without this the local
    /// folder state plus a completion below 100% makes a paused peer look like
    /// it is syncing forever.
    static func resolvedPeerState(
        folderState: String,
        remoteState: String?,
        peerConnected: Bool,
        completion: Double
    ) -> SyncthingState {
        guard peerConnected else { return .disconnected }
        switch remoteState?.lowercased() {
        case "paused": return .paused
        case "notsharing": return .unavailable
        default: break
        }
        return resolvedState(
            folderState: folderState,
            peerConnected: true,
            completion: completion)
    }

    static func resolvedState(
        folderState: String,
        peerConnected: Bool,
        completion: Double
    ) -> SyncthingState {
        let normalized = folderState.lowercased()
        if normalized.contains("scan") {
            return .scanning
        }
        if normalized.contains("sync") || normalized.contains("clean") {
            if completion >= 99.999 {
                return peerConnected ? .synced : .disconnected
            }
            return peerConnected ? .syncing : .disconnected
        }
        if normalized == "idle" {
            if completion >= 99.999 {
                return peerConnected ? .synced : .disconnected
            }
            return peerConnected ? .syncing : .disconnected
        }
        return peerConnected ? .checking : .disconnected
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
