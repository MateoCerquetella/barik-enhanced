import SwiftUI
import UniformTypeIdentifiers

struct WidgetConfiguratorView: View {
    @ObservedObject var configManager = ConfigManager.shared
    @State private var activeWidgetIDs: [String] = []
    @State private var isDropTargeted = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text("Configure Widgets")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(20)

            Divider().background(.white.opacity(0.2))

            HStack(spacing: 0) {
                // LEFT: Available widgets
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Widgets")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.7))

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(allWidgets) { widget in
                                AvailableWidgetCard(widget: widget) {
                                    withAnimation(.spring(duration: 0.3)) {
                                        activeWidgetIDs.append(widget.id)
                                    }
                                }
                                .onDrag {
                                    NSItemProvider(object: widget.id as NSString)
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)

                Divider().background(.white.opacity(0.2))

                // RIGHT: Active widgets (reorderable)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Active Widgets")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        Text("\(activeWidgetIDs.count) widgets")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    List {
                        ForEach(Array(activeWidgetIDs.enumerated()), id: \.offset) { entry in
                            let index: Int = entry.offset
                            let widgetID: String = entry.element
                            ActiveWidgetRow(
                                widget: allWidgets.first(where: { $0.id == widgetID }),
                                widgetID: widgetID,
                                onRemove: {
                                    withAnimation(.spring(duration: 0.3)) {
                                        if index < activeWidgetIDs.count {
                                            activeWidgetIDs.remove(at: index)
                                        }
                                    }
                                }
                            )
                        }
                        .onMove { source, destination in
                            activeWidgetIDs.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
                        guard let provider = providers.first else { return false }
                        provider.loadObject(ofClass: NSString.self) { string, _ in
                            if let widgetID = string as? String {
                                DispatchQueue.main.async {
                                    withAnimation(.spring(duration: 0.3)) {
                                        activeWidgetIDs.append(widgetID)
                                    }
                                }
                            }
                        }
                        return true
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.blue.opacity(isDropTargeted ? 0.5 : 0), lineWidth: 2)
                    )
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }

            Divider().background(.white.opacity(0.2))

            // Bottom bar
            HStack {
                Button("Reset to Default") {
                    withAnimation {
                        activeWidgetIDs = [
                            "default.spaces", "spacer", "default.nowplaying",
                            "default.cpuram", "default.networkactivity",
                            "divider", "default.network", "default.battery",
                            "default.time",
                        ]
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .foregroundStyle(.white.opacity(0.5))

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding(20)
        }
        .frame(width: 650, height: 500)
        .background(.black)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onAppear {
            activeWidgetIDs = configManager.config.rootToml.widgets.displayed.map { $0.id }
        }
        .onChange(of: activeWidgetIDs) { _, _ in
            applyChanges()
        }
    }

    private func applyChanges() {
        // Build TOML array string
        let items = activeWidgetIDs.map { id -> String in
            return "\"\(id)\""
        }
        let arrayStr = "[\n    " + items.joined(separator: ",\n    ") + "\n]"

        // Update config file directly
        guard let path = getConfigFilePath() else { return }
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let updated = replaceDisplayedWidgets(in: content, with: arrayStr)
            try updated.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving widget config: \(error)")
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
        // Find the displayed = [ ... ] block and replace it
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
            let replacement = "displayed = " + newArray
            lines.replaceSubrange(start...end, with: [replacement])
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Subviews

struct AvailableWidgetCard: View {
    let widget: WidgetDefinition
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 8) {
                Image(systemName: widget.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.1)))

                Text(widget.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActiveWidgetRow: View {
    let widget: WidgetDefinition?
    let widgetID: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.3))

            Image(systemName: widget?.icon ?? "questionmark.circle")
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(widget?.name ?? widgetID)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                Text(widget?.description ?? "")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
