import SwiftUI

/// Live CPU and RAM readout, matching the NET I/O widget: 1 Hz samples with a
/// neon trace and a colour that turns yellow/red at the configured thresholds.
struct CPURAMWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    var config: ConfigData { configProvider.config }

    var showIcon: Bool { config["show-icon"]?.boolValue ?? false }
    var cpuWarningLevel: Int { config["cpu-warning-level"]?.intValue ?? 70 }
    var cpuCriticalLevel: Int { config["cpu-critical-level"]?.intValue ?? 90 }
    var ramWarningLevel: Int { config["ram-warning-level"]?.intValue ?? 70 }
    var ramCriticalLevel: Int { config["ram-critical-level"]?.intValue ?? 90 }

    @ObservedObject private var systemMonitor = SystemMonitorManager.shared

    @State private var rect: CGRect = CGRect()

    /// Neutral until the configured warning/critical level, then yellow/red,
    /// so colour always means "close to the cap" rather than decoration.
    private static let neutral = Color.foregroundOutside

    var body: some View {
        HStack(spacing: 6) {
            if showIcon {
                Image(systemName: "cpu")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Self.neutral.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 3) {
                channel(
                    title: "CPU",
                    value: systemMonitor.cpuLoad,
                    history: systemMonitor.cpuHistory,
                    color: cpuColor,
                    active: systemMonitor.cpuLoad >= 1)
                channel(
                    title: "RAM",
                    value: systemMonitor.ramUsage,
                    history: systemMonitor.ramHistory,
                    color: ramColor,
                    active: systemMonitor.ramUsage >= 1)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        rect = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) { oldState, newState in
                        rect = newState
                    }
            }
        )
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "systemmonitor") {
                SystemMonitorPopup()
            }
        }
        .help("CPU \(Int(systemMonitor.cpuLoad))% · RAM \(Int(systemMonitor.ramUsage))%")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "CPU \(Int(systemMonitor.cpuLoad)) percent, RAM \(Int(systemMonitor.ramUsage)) percent")
    }

    private func channel(
        title: String,
        value: Double,
        history: [Double],
        color: Color,
        active: Bool
    ) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.65))
                .frame(width: 23, alignment: .leading)

            Text("\(Int(value))%")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 30, alignment: .trailing)

            LiveTrace(
                values: Array(history.suffix(14)),
                color: color,
                scale: 100)
                .frame(width: 34, height: 8)
                .shadow(color: color.opacity(active ? 0.5 : 0.15), radius: 2)
        }
    }

    private var cpuColor: Color {
        thresholdColor(
            systemMonitor.cpuLoad,
            warning: cpuWarningLevel,
            critical: cpuCriticalLevel,
            normal: Self.neutral)
    }

    private var ramColor: Color {
        thresholdColor(
            systemMonitor.ramUsage,
            warning: ramWarningLevel,
            critical: ramCriticalLevel,
            normal: Self.neutral)
    }

    private func thresholdColor(
        _ value: Double,
        warning: Int,
        critical: Int,
        normal: Color
    ) -> Color {
        if value >= Double(critical) {
            return .red
        } else if value >= Double(warning) {
            return .yellow
        }
        return normal
    }
}

struct CPURAMWidget_Previews: PreviewProvider {
    static var previews: some View {
        CPURAMWidget()
            .background(.black)
            .environmentObject(ConfigProvider(config: [:]))
            .previewLayout(.sizeThatFits)
    }
}
