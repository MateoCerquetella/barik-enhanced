import Foundation

protocol SyncthingSnapshotFetching {
    func fetch(settings: SyncthingWidgetSettings) -> SyncthingSnapshot
}

final class SyncthingAPIClient: SyncthingSnapshotFetching {
    private let session: URLSession
    private let timeout: TimeInterval
    private let now: () -> Date

    init(
        session: URLSession = .shared,
        timeout: TimeInterval = 8,
        now: @escaping () -> Date = Date.init
    ) {
        self.session = session
        self.timeout = timeout
        self.now = now
    }

    func fetch(settings: SyncthingWidgetSettings) -> SyncthingSnapshot {
        guard settings.isConfigured else {
            return failure(
                settings: settings,
                message: "Add the Syncthing API key to the widget configuration.")
        }

        do {
            let status: SystemStatus = try get(
                "rest/system/status", settings: settings)
            let folder: FolderStatus = try get(
                "rest/db/status",
                query: [URLQueryItem(name: "folder", value: settings.folderID)],
                settings: settings)
            let devices: [Device] = try get(
                "rest/config/devices", settings: settings)
            let folderConfig: FolderConfiguration = try get(
                "rest/config/folders/\(settings.folderID)",
                settings: settings)
            let connections: Connections = try get(
                "rest/system/connections", settings: settings)

            let devicesByID = Dictionary(
                uniqueKeysWithValues: devices.map { ($0.deviceID, $0) })
            let configuredPeers = folderConfig.devices.compactMap {
                devicesByID[$0.deviceID]
            }
            let localCompletion = SyncthingSnapshot.localCompletion(
                globalBytes: folder.globalBytes,
                needBytes: folder.needBytes)
            let localItems = folder.needFiles
                + folder.needDirectories
                + folder.needDeletes
            let localPeer = SyncthingSnapshot.Peer(
                id: "local",
                name: settings.localName,
                connected: true,
                state: SyncthingSnapshot.resolvedState(
                    folderState: folder.state,
                    peerConnected: true,
                    completion: localCompletion),
                completion: localCompletion,
                needBytes: folder.needBytes,
                needItems: localItems)
            let remotePeers = configuredPeers.map {
                device -> SyncthingSnapshot.Peer in
                let connected = connections.connections[device.deviceID]?.connected ?? false
                guard let completion = try? get(
                    "rest/db/completion",
                    query: [
                        URLQueryItem(name: "folder", value: settings.folderID),
                        URLQueryItem(name: "device", value: device.deviceID),
                    ],
                    settings: settings) as Completion? else {
                    return .init(id: device.deviceID, name: device.name, connected: connected,
                                 state: .unavailable, completion: 0, needBytes: 0, needItems: 0)
                }
                let percentage = min(max(completion.completion, 0), 100)
                return .init(id: device.deviceID, name: device.name, connected: connected,
                             state: SyncthingSnapshot.resolvedState(folderState: folder.state,
                                                                      peerConnected: connected,
                                                                      completion: percentage),
                             completion: percentage, needBytes: completion.needBytes,
                             needItems: completion.needItems)
            }
            let peerSnapshots = [localPeer] + remotePeers
            let worst = SyncthingSnapshot.leastSyncedPeer(in: peerSnapshots)!
            let state = worst.state

            return SyncthingSnapshot(
                settings: settings,
                state: state,
                folderState: folder.state,
                peerConnected: remotePeers.allSatisfy(\.connected),
                completion: worst.completion,
                globalBytes: folder.globalBytes,
                needBytes: peerSnapshots.map(\.needBytes).max() ?? 0,
                needItems: peerSnapshots.map(\.needItems).max() ?? 0,
                processMemoryBytes: status.sys,
                heapMemoryBytes: status.alloc,
                peerDeviceID: worst.id,
                errorMessage: nil,
                checkedAt: now(),
                peers: peerSnapshots)
        } catch {
            return failure(
                settings: settings,
                message: userFacingMessage(for: error))
        }
    }

    private func get<Response: Decodable>(
        _ path: String,
        query: [URLQueryItem] = [],
        settings: SyncthingWidgetSettings
    ) throws -> Response {
        var url = settings.apiURL
        for component in path.split(separator: "/") {
            url.appendPathComponent(String(component))
        }
        guard var components = URLComponents(
            url: url, resolvingAgainstBaseURL: false)
        else {
            throw APIError.invalidURL
        }
        components.queryItems = query.isEmpty ? nil : query
        guard let requestURL = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.timeoutInterval = timeout
        request.setValue(settings.apiKey, forHTTPHeaderField: "X-API-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<Data, Error>?
        session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error {
                result = .failure(error)
                return
            }
            guard let response = response as? HTTPURLResponse else {
                result = .failure(APIError.invalidResponse)
                return
            }
            guard (200..<300).contains(response.statusCode) else {
                result = .failure(APIError.http(response.statusCode))
                return
            }
            result = .success(data ?? Data())
        }.resume()

        guard semaphore.wait(timeout: .now() + timeout + 1) == .success,
              let result
        else {
            throw APIError.timedOut
        }
        let data = try result.get()
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.invalidData
        }
    }

    private func failure(
        settings: SyncthingWidgetSettings,
        message: String
    ) -> SyncthingSnapshot {
        SyncthingSnapshot(
            settings: settings,
            state: .unavailable,
            folderState: nil,
            peerConnected: false,
            completion: 0,
            globalBytes: 0,
            needBytes: 0,
            needItems: 0,
            processMemoryBytes: 0,
            heapMemoryBytes: 0,
            peerDeviceID: nil,
            errorMessage: message,
            checkedAt: now(),
            peers: [])
    }

    private func userFacingMessage(for error: Error) -> String {
        switch error {
        case APIError.http(401), APIError.http(403):
            return "Syncthing rejected the API key."
        case APIError.http(404):
            return "The folder or Syncthing API endpoint was not found."
        case APIError.timedOut:
            return "The Syncthing API request timed out."
        case APIError.invalidData:
            return "Syncthing returned an unsupported response."
        default:
            return "Could not reach the Syncthing API."
        }
    }
}

private extension SyncthingAPIClient {
    enum APIError: Error {
        case invalidURL
        case invalidResponse
        case invalidData
        case timedOut
        case http(Int)
    }

    struct SystemStatus: Decodable {
        let alloc: Int64
        let sys: Int64

        enum CodingKeys: String, CodingKey {
            case alloc
            case sys
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            alloc = try container.decodeIfPresent(Int64.self, forKey: .alloc) ?? 0
            sys = try container.decodeIfPresent(Int64.self, forKey: .sys) ?? 0
        }
    }

    struct FolderStatus: Decodable {
        let state: String
        let globalBytes: Int64
        let needBytes: Int64
        let needFiles: Int
        let needDirectories: Int
        let needDeletes: Int
    }

    struct Device: Decodable {
        let deviceID: String
        let name: String
    }

    struct FolderConfiguration: Decodable {
        let devices: [FolderDevice]
    }

    struct FolderDevice: Decodable {
        let deviceID: String
    }

    struct Connections: Decodable {
        let connections: [String: Connection]
    }

    struct Connection: Decodable {
        let connected: Bool
    }

    struct Completion: Decodable {
        let completion: Double
        let needBytes: Int64
        let needItems: Int

        enum CodingKeys: String, CodingKey {
            case completion
            case needBytes
            case needItems
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            completion = try container.decode(Double.self, forKey: .completion)
            needBytes = try container.decodeIfPresent(
                Int64.self, forKey: .needBytes) ?? 0
            needItems = try container.decodeIfPresent(
                Int.self, forKey: .needItems) ?? 0
        }
    }
}
