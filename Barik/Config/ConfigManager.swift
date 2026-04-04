import Foundation
import SwiftUI
import TOMLDecoder

final class ConfigManager: ObservableObject {
    static let shared = ConfigManager()

    @Published private(set) var config = Config()
    @Published private(set) var initError: String?
    
    private var fileWatchSource: DispatchSourceFileSystemObject?
    private var fileDescriptor: CInt = -1
    private var configFilePath: String?
    private var debounceWorkItem: DispatchWorkItem?

    private init() {
        loadOrCreateConfigIfNeeded()
    }

    private func loadOrCreateConfigIfNeeded() {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        let path1 = "\(homePath)/.barik-config.toml"
        let path2 = "\(homePath)/.config/barik/config.toml"
        var chosenPath: String?

        if FileManager.default.fileExists(atPath: path1) {
            chosenPath = path1
        } else if FileManager.default.fileExists(atPath: path2) {
            chosenPath = path2
        } else {
            do {
                try createDefaultConfig(at: path1)
                chosenPath = path1
            } catch {
                initError = "Error creating default config: \(error.localizedDescription)"
                print("Error when creating default config:", error)
                return
            }
        }

        if let path = chosenPath {
            configFilePath = path
            parseConfigFile(at: path)
            startWatchingFile(at: path)
        }
    }

    func reloadConfig() {
        guard let path = configFilePath else { return }
        parseConfigFile(at: path)
    }

    private func parseConfigFile(at path: String) {
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let decoder = TOMLDecoder()
            let rootToml = try decoder.decode(RootToml.self, from: content)
            DispatchQueue.main.async {
                self.config = Config(rootToml: rootToml)
                
                // Notify about config change for widget activation
                NotificationCenter.default.post(name: NSNotification.Name("ConfigChanged"), object: nil)
            }
        } catch {
            initError = "Error parsing TOML file: \(error.localizedDescription)"
            print("Error when parsing TOML file:", error)
        }
    }

    private func createDefaultConfig(at path: String) throws {
        let defaultTOML = """
            # If you installed yabai or aerospace without using Homebrew,
            # manually set the path to the binary. For example:
            #
            # yabai.path = "/run/current-system/sw/bin/yabai"
            # aerospace.path = ...
            
            theme = "system" # system, light, dark

            [widgets]
            displayed = [ # widgets on menu bar
                "default.spaces",
                "spacer",
                "default.network",
                "default.battery",
                "default.cpuram",
                "default.networkactivity",
                "default.performance",
                "default.reload",
                "divider",
                # { "default.time" = { time-zone = "America/Los_Angeles", format = "E d, hh:mm" } },
                "default.time"
            ]

            [widgets.default.spaces]
            space.show-key = true        # show space number (or character, if you use AeroSpace)
            window.show-title = true
            window.title.max-length = 50

            [widgets.default.battery]
            show-percentage = true
            warning-level = 30
            critical-level = 10

            [widgets.default.time]
            format = "E d, J:mm"
            calendar.format = "J:mm"

            calendar.show-events = false
            # calendar.allow-list = ["Home", "Personal"] # show only these calendars
            # calendar.deny-list = ["Work", "Boss"] # show all calendars except these

            [widgets.default.cpuram]
            show-icon = false
            cpu-warning-level = 70
            cpu-critical-level = 90
            ram-warning-level = 70
            ram-critical-level = 90

            [widgets.default.networkactivity]
            # No specific configuration options yet

            [widgets.default.performance]
            # Performance mode widget - replaces volume widget
            # Controls energy consumption by adjusting update intervals
            # Modes: battery-saver (default), balanced, max-performance

            [widgets.default.reload]
            show-label = false
            label = "Reload"

            [widgets.default.claude-usage]
            warning-threshold = 60
            critical-threshold = 80

            [widgets.default.codex-usage]
            warning-threshold = 60
            critical-threshold = 80

            [popup.default.time]
            view-variant = "box"
            
            [background]
            enabled = true
            """
        try defaultTOML.write(toFile: path, atomically: true, encoding: .utf8)
    }

    private func startWatchingFile(at path: String) {
        stopWatchingFile()

        fileDescriptor = open(path, O_EVTONLY)
        if fileDescriptor == -1 { return }

        fileWatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename],
            queue: DispatchQueue.global()
        )

        fileWatchSource?.setEventHandler { [weak self] in
            guard let self = self, let path = self.configFilePath else { return }

            self.debounceWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                guard FileManager.default.fileExists(atPath: path) else { return }
                self.parseConfigFile(at: path)
            }
            self.debounceWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }

        fileWatchSource?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd != -1 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }

        fileWatchSource?.resume()
    }

    private func stopWatchingFile() {
        fileWatchSource?.cancel()
        fileWatchSource = nil
    }

    func updateConfigValue(key: String, newValue: String, wrapInQuotes: Bool = true) {
        guard let path = configFilePath else {
            print("Config file path is not set")
            return
        }
        do {
            let currentText = try String(contentsOfFile: path, encoding: .utf8)
            let updatedText = updatedTOMLString(
                original: currentText,
                key: key,
                newValue: newValue,
                wrapInQuotes: wrapInQuotes
            )
            try updatedText.write(
                toFile: path, atomically: false, encoding: .utf8)
            DispatchQueue.main.async {
                self.parseConfigFile(at: path)
            }
        } catch {
            print("Error updating config:", error)
        }
    }

    private func updatedTOMLString(
        original: String,
        key: String,
        newValue: String,
        wrapInQuotes: Bool
    ) -> String {
        let renderedValue = wrapInQuotes ? "\"\(newValue)\"" : newValue

        if key.contains(".") {
            let components = key.split(separator: ".").map(String.init)
            guard components.count >= 2 else {
                return original
            }

            let tablePath = components.dropLast().joined(separator: ".")
            let actualKey = components.last!

            let tableHeader = "[\(tablePath)]"
            let lines = original.components(separatedBy: "\n")
            var newLines: [String] = []
            var insideTargetTable = false
            var updatedKey = false
            var foundTable = false

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                    if insideTargetTable && !updatedKey {
                        newLines.append("\(actualKey) = \(renderedValue)")
                        updatedKey = true
                    }
                    if trimmed == tableHeader {
                        foundTable = true
                        insideTargetTable = true
                    } else {
                        insideTargetTable = false
                    }
                    newLines.append(line)
                } else {
                    if insideTargetTable && !updatedKey {
                        let pattern =
                            "^\(NSRegularExpression.escapedPattern(for: actualKey))\\s*="
                        if line.range(of: pattern, options: .regularExpression)
                            != nil
                        {
                            newLines.append("\(actualKey) = \(renderedValue)")
                            updatedKey = true
                            continue
                        }
                    }
                    newLines.append(line)
                }
            }

            if foundTable && insideTargetTable && !updatedKey {
                newLines.append("\(actualKey) = \(renderedValue)")
            }

            if !foundTable {
                newLines.append("")
                newLines.append("[\(tablePath)]")
                newLines.append("\(actualKey) = \(renderedValue)")
            }
            return newLines.joined(separator: "\n")
        } else {
            let lines = original.components(separatedBy: "\n")
            var newLines: [String] = []
            var updatedAtLeastOnce = false

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.hasPrefix("#") {
                    let pattern =
                        "^\(NSRegularExpression.escapedPattern(for: key))\\s*="
                    if line.range(of: pattern, options: .regularExpression)
                        != nil
                    {
                        newLines.append("\(key) = \(renderedValue)")
                        updatedAtLeastOnce = true
                        continue
                    }
                }
                newLines.append(line)
            }
            if !updatedAtLeastOnce {
                newLines.append("\(key) = \(renderedValue)")
            }
            return newLines.joined(separator: "\n")
        }
    }

    func toggleWidget(_ widgetId: String) {
        guard let path = configFilePath else { return }
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            var displayedIds = config.rootToml.widgets.displayed.map(\.id)

            if let index = displayedIds.firstIndex(of: widgetId) {
                displayedIds.remove(at: index)
            } else {
                displayedIds.append(widgetId)
            }

            let widgetStrings = displayedIds.map { "\"\($0)\"" }
            let arrayStr = "[\n    " + widgetStrings.joined(separator: ",\n    ") + "\n]"
            let updated = replaceDisplayedWidgets(in: content, with: arrayStr)
            try updated.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("Error toggling widget: \(error)")
        }
    }

    private func replaceDisplayedWidgets(in content: String, with newArray: String) -> String {
        var lines = content.components(separatedBy: "\n")
        var startIndex: Int?
        var endIndex: Int?
        var bracketCount = 0

        for (i, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("displayed") && trimmed.contains("[") {
                startIndex = i
                bracketCount = trimmed.filter({ $0 == "[" }).count - trimmed.filter({ $0 == "]" }).count
                if bracketCount <= 0 {
                    endIndex = i
                    break
                }
            } else if startIndex != nil && endIndex == nil {
                bracketCount += trimmed.filter({ $0 == "[" }).count - trimmed.filter({ $0 == "]" }).count
                if bracketCount <= 0 {
                    endIndex = i
                    break
                }
            }
        }

        if let start = startIndex, let end = endIndex {
            lines.replaceSubrange(start...end, with: ["displayed = " + newArray])
        }

        return lines.joined(separator: "\n")
    }

    func globalWidgetConfig(for widgetId: String) -> ConfigData {
        config.rootToml.widgets.config(for: widgetId) ?? [:]
    }

    func resolvedWidgetConfig(for item: TomlWidgetItem) -> ConfigData {
        let global = globalWidgetConfig(for: item.id)
        if item.inlineParams.isEmpty {
            return global
        }
        var merged = global
        for (key, value) in item.inlineParams {
            merged[key] = value
        }
        return merged
    }
}
