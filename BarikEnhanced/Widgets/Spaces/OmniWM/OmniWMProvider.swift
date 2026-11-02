import Darwin
import Foundation

/// Spaces provider backed by OmniWM's local IPC CLI (`omniwmctl`).
///
/// Two queries are enough to build the bar: `query workspaces` for the chips and
/// `query windows` for the app icons and titles. Both payloads already carry the
/// focused flags, so no extra round-trips are needed.
class OmniWMSpacesProvider: SpacesProvider, SwitchableSpacesProvider {
    typealias SpaceType = OmniWMSpace

    private var executablePath: String { ConfigManager.shared.config.omniwm.path }
    private let commandTimeout: DispatchTimeInterval = .seconds(2)

    /// Opaque id -> stable Int mapping for the windows seen in the last fetch.
    private let windowIdLock = NSLock()
    private var opaqueIdsByStableId: [Int: String] = [:]

    /// A stalled IPC server accepts the CLI connection but never answers.
    /// Three failures pause CLI calls for a minute, mirroring the AeroSpace
    /// provider so a dead window manager cannot spawn a hung process per cycle.
    private var consecutiveFailures = 0
    private var pausedUntil: Date?

    private func commandCircuitIsOpen() -> Bool {
        if let pausedUntil, pausedUntil > Date() {
            return true
        }
        return false
    }

    private func recordFailure() {
        consecutiveFailures += 1
        if consecutiveFailures >= 3 {
            pausedUntil = Date().addingTimeInterval(60)
            consecutiveFailures = 0
        }
    }

    private func recordSuccess() {
        consecutiveFailures = 0
        pausedUntil = nil
    }

    func getSpacesWithWindows() -> [OmniWMSpace]? {
        guard
            let spaces = fetchSpaces(),
            let windows = fetchWindows()
        else {
            return nil
        }

        var spacesByWorkspace = Dictionary(
            uniqueKeysWithValues: spaces.map { ($0.workspace, $0) })

        var idsByStableId: [Int: String] = [:]
        for window in windows where !window.isScratchpad {
            idsByStableId[window.id] = window.opaqueId
            guard let workspace = window.workspace else { continue }
            guard var space = spacesByWorkspace[workspace] else { continue }
            space.windows.append(window)
            spacesByWorkspace[workspace] = space
        }

        windowIdLock.lock()
        opaqueIdsByStableId = idsByStableId
        windowIdLock.unlock()

        var result = Array(spacesByWorkspace.values)
        for index in result.indices {
            result[index].windows.sort { $0.id < $1.id }
        }
        return result.filter { !$0.windows.isEmpty }
    }

    func focusSpace(spaceId: String, needWindowFocus: Bool) {
        if let number = Int(spaceId) {
            _ = runOmniWMCommand(arguments: ["command", "switch-workspace", String(number)])
        } else {
            _ = runOmniWMCommand(arguments: ["workspace", "focus-name", spaceId])
        }
    }

    func focusWindow(windowId: String) {
        guard let stableId = Int(windowId) else { return }

        windowIdLock.lock()
        let opaqueId = opaqueIdsByStableId[stableId]
        windowIdLock.unlock()

        guard let opaqueId else { return }
        _ = runOmniWMCommand(arguments: ["window", "focus", opaqueId])
    }

    private func runOmniWMCommand(arguments: [String]) -> Data? {
        guard !commandCircuitIsOpen() else { return nil }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let exitGroup = DispatchGroup()
        exitGroup.enter()
        process.terminationHandler = { _ in
            exitGroup.leave()
        }

        do {
            try process.run()
        } catch {
            print("OmniWM error: \(error)")
            return nil
        }

        if exitGroup.wait(timeout: .now() + commandTimeout) == .timedOut {
            // SIGTERM is not enough for a CLI blocked on a dead socket.
            kill(process.processIdentifier, SIGKILL)
            _ = exitGroup.wait(timeout: .now() + 1)
            recordFailure()
            print("OmniWM command timed out: \(arguments.joined(separator: " "))")
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let stderr = String(data: errorData, encoding: .utf8) ?? ""
            recordFailure()
            print("OmniWM command failed (\(process.terminationStatus)): \(stderr)")
            return nil
        }

        recordSuccess()
        return data
    }

    /// Pulls `result.payload[<key>]` out of the CLI's JSON envelope and decodes
    /// it, so version-specific envelope details stay in one place.
    private func fetchPayload<T: Decodable>(query: [String], key: String) -> T? {
        guard let data = runOmniWMCommand(arguments: query),
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = root["result"] as? [String: Any],
            let payload = result["payload"] as? [String: Any],
            let rows = payload[key]
        else {
            return nil
        }

        guard let rowsData = try? JSONSerialization.data(withJSONObject: rows) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(T.self, from: rowsData)
        } catch {
            print("Decode \(key) error: \(error)")
            return nil
        }
    }

    private func fetchSpaces() -> [OmniWMSpace]? {
        fetchPayload(
            query: ["query", "workspaces", "--format", "json"], key: "workspaces")
    }

    private func fetchWindows() -> [OmniWMWindow]? {
        fetchPayload(query: ["query", "windows", "--format", "json"], key: "windows")
    }
}
