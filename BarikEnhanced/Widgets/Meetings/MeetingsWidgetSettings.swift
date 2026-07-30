import Foundation

struct MeetingsWidgetSettings: Equatable {
    static let defaultTitleMaximumLength = 32
    static let titleLengthRange = 8...80

    let titleMaximumLength: Int

    init(config: ConfigData) {
        self.init(
            titleMaximumLength:
                config["title-max-length"]?.intValue
                    ?? Self.defaultTitleMaximumLength)
    }

    init(titleMaximumLength: Int = Self.defaultTitleMaximumLength) {
        self.titleMaximumLength = min(
            max(titleMaximumLength, Self.titleLengthRange.lowerBound),
            Self.titleLengthRange.upperBound)
    }

    func truncatedTitle(_ title: String) -> String {
        guard title.count > titleMaximumLength else { return title }
        return String(title.prefix(titleMaximumLength - 1)) + "…"
    }
}
