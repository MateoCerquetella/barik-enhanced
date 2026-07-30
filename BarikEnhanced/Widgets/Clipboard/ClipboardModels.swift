import Foundation

struct ClipboardHistoryEntry: Identifiable, Equatable {
    let id: UUID
    let text: String
    let copiedAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        copiedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.copiedAt = copiedAt
    }
}

struct ClipboardWidgetSettings: Equatable {
    static let defaultMaximumItems = 10
    static let maximumItemsRange = 1...20
    static let defaultPreviewMaximumLength = 40
    static let previewLengthRange = 8...120

    let maximumItems: Int
    let previewMaximumLength: Int

    init(config: ConfigData) {
        self.init(
            maximumItems:
                config["max-items"]?.intValue
                    ?? Self.defaultMaximumItems,
            previewMaximumLength:
                config["preview-max-length"]?.intValue
                    ?? Self.defaultPreviewMaximumLength)
    }

    init(
        maximumItems: Int = Self.defaultMaximumItems,
        previewMaximumLength: Int = Self.defaultPreviewMaximumLength
    ) {
        self.maximumItems = Self.clampedMaximumItems(maximumItems)
        self.previewMaximumLength = min(
            max(previewMaximumLength, Self.previewLengthRange.lowerBound),
            Self.previewLengthRange.upperBound)
    }

    static func clampedMaximumItems(_ value: Int) -> Int {
        min(
            max(value, maximumItemsRange.lowerBound),
            maximumItemsRange.upperBound)
    }
}

enum ClipboardTextPresentation {
    static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
    }

    static func preview(_ text: String, maximumLength: Int) -> String {
        let normalizedText = normalized(text)
        let safeMaximumLength = max(1, maximumLength)
        guard normalizedText.count > safeMaximumLength else {
            return normalizedText
        }

        guard safeMaximumLength > 1 else { return "…" }
        return String(normalizedText.prefix(safeMaximumLength - 1)) + "…"
    }
}
