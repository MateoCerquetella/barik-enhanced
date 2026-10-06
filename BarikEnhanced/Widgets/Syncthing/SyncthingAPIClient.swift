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
            let connections: Connections = try get(
                "rest/system/connections", settings: settings)

            let peerID = resolvePeerID(devices: devices, settings: settings)
            let peerConnected = peerID.flatMap {
                connections.connections[$0]?.connected
            } ?? false

            guard let peerID else {
                return SyncthingSnapshot(
                    settings: settings,
                    state: .unavailable,
                    folderState: folder.state,
                    peerConnected: false,
                    completion: 0,
                    globalBytes: folder.globalBytes,
                    needBytes: folder.needBytes,
                    needItems: folder.needFiles
                        + folder.needDirectories
                        + folder.needDeletes,
                    processMemoryBytes: status.sys,
                    heapMemoryBytes: status.alloc,
                    peerDeviceID: nil,
                    errorMessage:
                        "Peer \"\(settings.peerName)\" was not found in Syncthing.",
                    checkedAt: now())
            }

            let completion: Completion = try get(
                "rest/db/completion",
                query: [
                    URLQueryItem(name: "folder", value: settings.folderID),
                    URLQueryItem(name: "device", value: peerID),
                ],
                settings: settings)
            let percentage = min(
                max(completion.completion, 0),
                100)
            let state = SyncthingSnapshot.resolvedState(
                folderState: folder.state,
                peerConnected: peerConnected,
                completion: percentage)

            return SyncthingSnapshot(
                settings: settings,
                state: state,
                folderState: folder.state,
                peerConnected: peerConnected,
                completion: percentage,
                globalBytes: folder.globalBytes,
                needBytes: completion.needBytes,
                needItems: completion.needItems,
                processMemoryBytes: status.sys,
                heapMemoryBytes: status.alloc,
                peerDeviceID: peerID,
                errorMessage: nil,
                checkedAt: now())
        } catch {
            return failure(
                settings: settings,
                message: userFacingMessage(for: error))
        }
    }

    private func resolvePeerID(
        devices: [Device],
        settings: SyncthingWidgetSettings
    ) -> String? {
        if let peerDeviceID = settings.peerDeviceID {
            return peerDeviceID
        }
        return devices.first {
            $0.name.caseInsensitiveCompare(settings.peerName) == .orderedSame
        }?.deviceID
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
            checkedAt: now())
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
