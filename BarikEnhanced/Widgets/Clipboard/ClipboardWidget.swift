import SwiftUI

enum ClipboardPalette {
    static let accent = Color(
        red: 0.27,
        green: 0.82,
        blue: 0.66)
}

struct ClipboardWidget: View {
    @EnvironmentObject private var configProvider: ConfigProvider
    @ObservedObject private var manager: ClipboardManager

    @State private var rect = CGRect.zero
    @State private var activationID = UUID()

    init(manager: ClipboardManager = .shared) {
        self.manager = manager
    }

    private var settings: ClipboardWidgetSettings {
        ClipboardWidgetSettings(config: configProvider.config)
    }

    private var latestEntry: ClipboardHistoryEntry? {
        manager.entries.prefix(settings.maximumItems).first
    }

    var body: some View {
        ClipboardWidgetContent(
            entry: latestEntry,
            previewMaximumLength: settings.previewMaximumLength,
            onOpenHistory: showHistory)
            .foregroundStyle(.foregroundOutside)
            .shadow(color: .foregroundShadowOutside, radius: 3)
            .experimentalConfiguration(cornerRadius: 15)
            .frame(maxHeight: .infinity)
            .background(.black.opacity(0.001))
            .contentShape(Rectangle())
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            rect = geometry.frame(in: .global)
                        }
                        .onChange(of: geometry.frame(in: .global)) {
                            _, newRect in
                            rect = newRect
                        }
                })
            .onAppear {
                manager.activate(
                    clientID: activationID,
                    maximumItems: settings.maximumItems)
            }
            .onChange(of: settings.maximumItems) { _, maximumItems in
                manager.update(
                    clientID: activationID,
                    maximumItems: maximumItems)
            }
            .onDisappear {
                manager.deactivate(clientID: activationID)
            }
    }

    private func showHistory() {
        MenuBarPopup.show(
            rect: rect,
            id: "clipboard-\(activationID.uuidString)"
        ) {
            ClipboardPopup(
                manager: manager,
                maximumItems: settings.maximumItems)
        }
    }
}

struct ClipboardWidgetContent: View {
    let entry: ClipboardHistoryEntry?
    let previewMaximumLength: Int
    let onOpenHistory: () -> Void

    private var previewText: String {
        guard let entry else {
            return String(localized: "Clipboard empty")
        }
        return ClipboardTextPresentation.preview(
            entry.text,
            maximumLength: previewMaximumLength)
    }

    private var accessibilityText: String {
        guard entry != nil else {
            return "Clipboard empty. Open clipboard history"
        }
        return "Open clipboard history. Latest copy: \(previewText)"
    }

    var body: some View {
        Button(action: onOpenHistory) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        ClipboardPalette.accent.opacity(entry == nil ? 0.6 : 1))

                Text(previewText)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .help("Open clipboard history")
        .font(.headline)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct ClipboardWidgetContent_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ClipboardWidgetContent(
                entry: ClipboardHistoryEntry(
                    text: "A useful snippet copied from the project brief"),
                previewMaximumLength: 32,
                onOpenHistory: {})
                .previewDisplayName("Recent text")

            ClipboardWidgetContent(
                entry: nil,
                previewMaximumLength: 32,
                onOpenHistory: {})
                .previewDisplayName("Empty")
        }
        .padding()
        .background(.black)
        .foregroundStyle(.white)
        .previewLayout(.sizeThatFits)
    }
}
