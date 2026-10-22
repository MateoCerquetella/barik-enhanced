import Darwin
import Foundation

class AerospaceSpacesProvider: SpacesProvider, SwitchableSpacesProvider {
    typealias SpaceType = AeroSpace
    private var executablePath: String { ConfigManager.shared.config.aerospace.path }
    private let commandTimeout: DispatchTimeInterval = .seconds(2)

    /// A wedged AeroSpace server accepts the CLI connection but never answers.
    /// Without a circuit breaker the 5 s refresh spawned a new hung process
    /// every cycle. Three failures pause CLI calls for a minute.
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

    func getSpacesWithWindows() -> [AeroSpace]? {
        guard
            var spaces = fetchSpaces(),
            let windows = fetchWindows()
        else {
            return nil
        }

        let focusedSpace = fetchFocusedSpace()
        if let focusedSpace {
            for i in 0..<spaces.count {
                spaces[i].isFocused = (spaces[i].id == focusedSpace.id)
            }
        }

        let focusedWindow = fetchFocusedWindow()
        var spaceDict = Dictionary(
            uniqueKeysWithValues: spaces.map { ($0.id, $0) })

        for window in windows {
            var mutableWindow = window
            if let focused = focusedWindow, window.id == focused.id {
                mutableWindow.isFocused = true
            }

            if let ws = mutableWindow.workspace, !ws.isEmpty {
                if var space = spaceDict[ws] {
                    space.windows.append(mutableWindow)
                    spaceDict[ws] = space
                }
            } else if let focusedSpace {
                if var space = spaceDict[focusedSpace.id] {
                    space.windows.append(mutableWindow)
                    spaceDict[focusedSpace.id] = space
                }
            }
        }
        var resultSpaces = Array(spaceDict.values)
        for i in 0..<resultSpaces.count {
            resultSpaces[i].windows.sort { $0.id < $1.id }
        }
        return resultSpaces.filter { !$0.windows.isEmpty }
    }

    func focusSpace(spaceId: String, needWindowFocus: Bool) {
        _ = runAerospaceCommand(arguments: ["workspace", spaceId])
    }

    func focusWindow(windowId: String) {
        _ = runAerospaceCommand(arguments: ["focus", "--window-id", windowId])
    }

    private func runAerospaceCommand(arguments: [String]) -> Data? {
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
            print("Aerospace error: \(error)")
            return nil
        }

        if exitGroup.wait(timeout: .now() + commandTimeout) == .timedOut {
            // SIGTERM is not enough for a CLI blocked on a dead socket.
            kill(process.processIdentifier, SIGKILL)
            _ = exitGroup.wait(timeout: .now() + 1)
            recordFailure()
            print("Aerospace command timed out: \(arguments.joined(separator: " "))")
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let stderr = String(data: errorData, encoding: .utf8) ?? ""
            recordFailure()
            print("Aerospace command failed (\(process.terminationStatus)): \(stderr)")
            return nil
        }

        recordSuccess()
        return data
    }

    private func fetchSpaces() -> [AeroSpace]? {
        guard
            let data = runAerospaceCommand(arguments: [
                "list-workspaces", "--all", "--json",
            ])
        else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode([AeroSpace].self, from: data)
        } catch {
            print("Decode spaces error: \(error)")
            return nil
        }
    }

    private func fetchWindows() -> [AeroWindow]? {
        guard
            let data = runAerospaceCommand(arguments: [
                "list-windows", "--all", "--json", "--format",
                "%{window-id} %{app-name} %{window-title} %{workspace}",
            ])
        else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode([AeroWindow].self, from: data)
        } catch {
            print("Decode windows error: \(error)")
            return nil
        }
    }

    private func fetchFocusedSpace() -> AeroSpace? {
        guard
            let data = runAerospaceCommand(arguments: [
                "list-workspaces", "--focused", "--json",
            ])
        else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode([AeroSpace].self, from: data).first
        } catch {
            print("Decode focused space error: \(error)")
            return nil
        }
    }

    private func fetchFocusedWindow() -> AeroWindow? {
        guard
            let data = runAerospaceCommand(arguments: [
                "list-windows", "--focused", "--json",
            ])
        else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            return try decoder.decode([AeroWindow].self, from: data).first
        } catch {
            print("Decode focused window error: \(error)")
            return nil
        }
    }
}
