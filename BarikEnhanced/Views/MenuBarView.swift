import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var configManager = ConfigManager.shared
    @ObservedObject var menuBarMetrics = MenuBarMetrics.shared
    @State private var draggedItem: TomlWidgetItem?
    @State private var displayedItems: [TomlWidgetItem] = []
    @State private var settingsRect: CGRect = .zero

    /// Trailing reservation. Narrow screens get 220 pt clearance from macOS
    /// status icons; wide screens use only horizontal-padding so the bar
    /// stays visually close to the right edge. Override with
    /// `experimental.foreground.system-status-reservation`.
    private var trailingReservation: CGFloat {
        let hp = configManager.config.experimental.foreground.horizontalPadding
        if let userReservation = configManager.config.experimental.foreground.systemStatusReservation {
            return max(hp, userReservation)
        }
        let narrowestScreenWidth = NSScreen.screens.map { $0.frame.width }.min() ?? .infinity
        if narrowestScreenWidth < 1500 {
            return max(hp, 220)
        }
        return hp
    }

    /// Splits regular items at the first spacer or divider widget.
    /// Everything before becomes the left (clipped) section;
    /// everything after becomes the right (pinned) section.
    private func splitItems(_ items: [TomlWidgetItem]) -> (left: [TomlWidgetItem], right: [TomlWidgetItem]) {
        var left: [TomlWidgetItem] = []
        var right: [TomlWidgetItem] = []
        var foundSplit = false
        for item in items {
            if !foundSplit, item.id == "spacer" || item.id == "divider" {
                foundSplit = true
                continue
            }
            if foundSplit {
                right.append(item)
            } else {
                left.append(item)
            }
        }
        return (left, right)
    }

    var body: some View {
        let timeItems = displayedItems.filter { $0.id == "default.time" }
        let regularItems = displayedItems.filter { $0.id != "default.time" }
        let (leftItems, rightItems) = splitItems(regularItems)

        let theme: ColorScheme? =
            switch configManager.config.rootToml.theme {
            case "dark":
                .dark
            case "light":
                .light
            default:
                .none
            }

        ZStack(alignment: .topLeading) {
            HStack(spacing: configManager.config.experimental.foreground.spacing) {
                ForEach(leftItems) { item in
                    draggableWidget(for: item)
                }
            }
            .clipped()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.trailing, 180)

            HStack(spacing: configManager.config.experimental.foreground.spacing) {
                Spacer(minLength: 0)

                ForEach(rightItems) { item in
                    draggableWidget(for: item)
                }

                if !timeItems.isEmpty {
                    ForEach(timeItems) { item in
                        draggableWidget(for: item)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }

                if !displayedItems.contains(where: { $0.id == "system-banner" }) {
                    SystemBannerWidget(withLeftPadding: false)
                }

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxHeight: .infinity)
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear { settingsRect = geometry.frame(in: .global) }
                                .onChange(of: geometry.frame(in: .global)) { _, newState in settingsRect = newState }
                        }
                    )
                    .background(.black.opacity(0.001))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        MenuBarPopup.show(rect: settingsRect, id: "settings") {
                            SettingsMenuView()
                        }
                    }
                    .padding(.leading, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
        .contextMenu {
            Button("Configure Widgets...") {
                WidgetConfiguratorWindow.show()
            }
            Button("Edit Config...") {
                openConfigFile()
            }
            Divider()
            Button("Quit Barik Enhanced") {
                NSApp.terminate(nil)
            }
        }
        .foregroundStyle(Color.foregroundOutside)
        .clipped()
        .frame(height: max(configManager.config.experimental.foreground.resolveHeight(), 1.0))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: configManager.config.experimental.position == .bottom ? .bottomLeading : .topLeading)
        .padding(.leading, configManager.config.experimental.foreground.horizontalPadding)
        .padding(.trailing, trailingReservation)
        .background(.black.opacity(0.001))
        .preferredColorScheme(theme)
        .onAppear {
            displayedItems = configManager.config.rootToml.widgets.displayed
        }
        .onReceive(configManager.$config) { newConfig in
            displayedItems = newConfig.rootToml.widgets.displayed
        }
    }

    @ViewBuilder
    private func draggableWidget(for item: TomlWidgetItem) -> some View {
        buildView(for: item)
            .lineLimit(1)
            .contentShape(Rectangle())
            .onDrag {
                draggedItem = item
                return NSItemProvider(object: item.id as NSString)
            }
            .onDrop(of: [.text], delegate: WidgetDropDelegate(
                item: item,
                items: displayedItems,
                draggedItem: $draggedItem,
                onReorder: { newItems in
                    displayedItems = newItems
                    saveWidgetOrder(newItems)
                }
            ))
            .opacity(draggedItem?.instanceID == item.instanceID ? 0.5 : 1.0)
    }

    @ViewBuilder
    private func buildView(for item: TomlWidgetItem) -> some View {
        let config = ConfigProvider(
            config: configManager.resolvedWidgetConfig(for: item))

        switch item.id {
        case "default.spaces":
            SpacesWidget().environmentObject(config)

        case "default.network":
            NetworkWidget().environmentObject(config)

        case "default.battery":
            BatteryWidget().environmentObject(config)

        case "default.time":
            TimeWidget(calendarManager: CalendarManager.shared)
                .environmentObject(config)

        case "default.meetings":
            MeetingsWidget()
                .environmentObject(config)

        case "default.nowplaying":
            NowPlayingWidget()
                .environmentObject(config)

        case "default.cpuram":
            CPURAMWidget()
                .environmentObject(config)

        case "default.networkactivity":
            NetworkActivityWidget()
                .environmentObject(config)

        case "default.volume":
            VolumeWidget()
                .environmentObject(config)

        case "default.microphone":
            MicrophoneWidget()
                .environmentObject(config)

        case "default.weather":
            WeatherWidget()
                .environmentObject(config)

        case "default.brightness":
            BrightnessWidget()
                .environmentObject(config)

        case "default.dnd":
            DoNotDisturbWidget()
                .environmentObject(config)

        case "default.disk":
            DiskUsageWidget()
                .environmentObject(config)

        case "default.uptime":
            UptimeWidget()
                .environmentObject(config)

        case "default.pomodoro":
            PomodoroWidget()
                .environmentObject(config)

        case "default.performance":
            PerformanceModeWidget()
                .environmentObject(config)

        case "default.reload":
            ReloadWidget()
                .environmentObject(config)

        case "default.keyboardlayout":
            KeyboardLayoutWidget()
                .environmentObject(config)

        case "default.claude-usage":
            ClaudeUsageWidget()
                .environmentObject(config)

        case "default.codex-usage":
            CodexUsageWidget()
                .environmentObject(config)

        case "default.opencode-usage":
            OpenCodeUsageWidget()
                .environmentObject(config)

        case "default.countdown":
            CountdownWidget()
                .environmentObject(config)

        case "spacer":
            Spacer().frame(minWidth: 8, maxWidth: .infinity)

        case "divider":
            Rectangle()
                .fill(Color.active)
                .frame(width: 2, height: 15)
                .clipShape(Capsule())

        case "system-banner":
            SystemBannerWidget()

        default:
            Text("?\(item.id)?").foregroundColor(.red)
        }
    }

    // MARK: - Actions

    private func openConfigFile() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path1 = "\(home)/.barik-config.toml"
        let path2 = "\(home)/.config/barik/config.toml"

        if FileManager.default.fileExists(atPath: path1) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path1))
        } else if FileManager.default.fileExists(atPath: path2) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path2))
        }
    }

    // MARK: - Config Persistence

    private func saveWidgetOrder(_ items: [TomlWidgetItem]) {
        guard let path = getConfigFilePath() else { return }
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let widgetStrings = items.map { "\"\($0.id)\"" }
            let arrayStr = "[\n    " + widgetStrings.joined(separator: ",\n    ") + "\n]"
            let updated = replaceDisplayedWidgets(in: content, with: arrayStr)
            try updated.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving widget order: \(error)")
        }
    }

    private func getConfigFilePath() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path1 = "\(home)/.barik-config.toml"
        let path2 = "\(home)/.config/barik/config.toml"
        if FileManager.default.fileExists(atPath: path1) { return path1 }
        if FileManager.default.fileExists(atPath: path2) { return path2 }
        return nil
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
}

private struct ReloadWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider

    private var config: ConfigData { configProvider.config }
    private var showLabel: Bool { config["show-label"]?.boolValue ?? false }
    private var label: String { config["label"]?.stringValue ?? "Reload" }

    @State private var isReloading = false

    var body: some View {
        HStack(spacing: showLabel ? 5 : 0) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.icon)
                .rotationEffect(.degrees(isReloading ? 360 : 0))
                .animation(.easeInOut(duration: 0.45), value: isReloading)

            if showLabel {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.foregroundOutside)
            }
        }
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .contentShape(Rectangle())
        .onTapGesture {
            isReloading = true
            ConfigManager.shared.reloadConfig()
            SpacesViewModel.shared.forceRefresh()
            NotificationCenter.default.post(
                name: Notification.Name("ManualReloadTriggered"),
                object: nil
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                isReloading = false
            }
        }
        .help("Reload config and refresh widgets")
    }
}
