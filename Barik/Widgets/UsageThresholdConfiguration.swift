import SwiftUI

struct UsageThresholdConfiguration {
    let warningLevel: Int
    let criticalLevel: Int

    init(config: ConfigData, defaultWarning: Int = 60, defaultCritical: Int = 80) {
        let resolvedWarning = Self.clamp(config["warning-threshold"]?.intValue ?? defaultWarning)
        let resolvedCritical = Self.clamp(config["critical-threshold"]?.intValue ?? defaultCritical)

        warningLevel = min(resolvedWarning, resolvedCritical)
        criticalLevel = max(resolvedWarning, resolvedCritical)
    }

    var warningPercentage: Double {
        Double(warningLevel) / 100
    }

    var criticalPercentage: Double {
        Double(criticalLevel) / 100
    }

    func color(for percentage: Double) -> Color {
        if percentage >= criticalPercentage { return .red }
        if percentage >= warningPercentage { return .orange }
        return .white
    }

    static func clamp(_ value: Int) -> Int {
        max(0, min(100, value))
    }
}

struct UsageThresholdSettingsView: View {
    let title: String
    let widgetConfigKey: String
    let accentColor: Color
    let initialConfiguration: UsageThresholdConfiguration

    @State private var warningLevel: Int
    @State private var criticalLevel: Int

    init(
        title: String,
        widgetConfigKey: String,
        accentColor: Color,
        initialConfiguration: UsageThresholdConfiguration
    ) {
        self.title = title
        self.widgetConfigKey = widgetConfigKey
        self.accentColor = accentColor
        self.initialConfiguration = initialConfiguration
        _warningLevel = State(initialValue: initialConfiguration.warningLevel)
        _criticalLevel = State(initialValue: initialConfiguration.criticalLevel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Usage thresholds")
                    .font(.system(size: 13, weight: .semibold))
                Text("Adjust when \(title) changes from normal to warning or critical.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }

            thresholdControl(
                label: "Warning",
                value: $warningLevel,
                range: 0...100
            ) { newValue in
                warningLevel = newValue
                if criticalLevel < newValue {
                    criticalLevel = newValue
                }
                persist()
            }

            thresholdControl(
                label: "Critical",
                value: $criticalLevel,
                range: warningLevel...100
            ) { newValue in
                criticalLevel = max(newValue, warningLevel)
                persist()
            }

            HStack(spacing: 8) {
                statusChip(label: "Normal", color: .white.opacity(0.2), textColor: .white)
                statusChip(label: "Warning", color: .orange.opacity(0.25), textColor: .orange)
                statusChip(label: "Critical", color: .red.opacity(0.25), textColor: .red)
            }

            Text("Saved to `~/.barik-config.toml` automatically.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func thresholdControl(
        label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        onCommit: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Text("\(value.wrappedValue)%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accentColor)
            }

            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { newValue in
                        value.wrappedValue = UsageThresholdConfiguration.clamp(Int(newValue.rounded()))
                    }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: 1,
                onEditingChanged: { editing in
                    if !editing {
                        onCommit(value.wrappedValue)
                    }
                }
            )
            .tint(accentColor)

            HStack {
                Button("-5") {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - 5)
                    onCommit(value.wrappedValue)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Button("+5") {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + 5)
                    onCommit(value.wrappedValue)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.7))
            }
            .font(.system(size: 11, weight: .medium))
        }
    }

    private func statusChip(label: String, color: Color, textColor: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }

    private func persist() {
        ConfigManager.shared.updateConfigValue(
            key: "widgets.\(widgetConfigKey).warning-threshold",
            newValue: String(warningLevel),
            wrapInQuotes: false
        )
        ConfigManager.shared.updateConfigValue(
            key: "widgets.\(widgetConfigKey).critical-threshold",
            newValue: String(criticalLevel),
            wrapInQuotes: false
        )
    }
}
