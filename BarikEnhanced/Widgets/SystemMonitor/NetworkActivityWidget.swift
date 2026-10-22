import SwiftUI

/// Live upload/download readout. Network is sampled at 1 Hz by
/// `SystemMonitorManager`, so the numbers and the trace move every second.
struct NetworkActivityWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    var config: ConfigData { configProvider.config }

    @ObservedObject private var systemMonitor = SystemMonitorManager.shared

    @State private var rect: CGRect = CGRect()

    private static let neon = Color(red: 0.30, green: 1.00, blue: 0.45)
    private static let cyan = Color(red: 0.25, green: 0.85, blue: 1.00)
    private static let traceLength = 14

    private var isUploading: Bool { systemMonitor.uploadSpeed > 0.001 }
    private var isDownloading: Bool { systemMonitor.downloadSpeed > 0.001 }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            channel(
                glyph: "▲",
                speed: systemMonitor.uploadSpeed,
                history: systemMonitor.uploadHistory,
                color: Self.neon,
                active: isUploading)
            channel(
                glyph: "▼",
                speed: systemMonitor.downloadSpeed,
                history: systemMonitor.downloadHistory,
                color: Self.cyan,
                active: isDownloading)
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
        .help(speedTooltip)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(speedTooltip)
    }

    private func channel(
        glyph: String,
        speed: Double,
        history: [Double],
        color: Color,
        active: Bool
    ) -> some View {
        HStack(spacing: 4) {
            Text(glyph)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .opacity(active ? 1 : 0.35)
                .animation(
                    active
                        ? .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                        : .easeOut(duration: 0.2),
                    value: active)

            Text(compactSpeed(speed))
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 44, alignment: .leading)

            LiveTrace(
                values: Array(history.suffix(Self.traceLength)),
                color: color)
                .frame(width: 34, height: 8)
                .shadow(color: color.opacity(active ? 0.55 : 0.15), radius: 2)
        }
    }

    private var speedTooltip: String {
        "NET I/O · ↑ \(fullSpeed(systemMonitor.uploadSpeed)) ↓ \(fullSpeed(systemMonitor.downloadSpeed))"
    }

    private func compactSpeed(_ speed: Double) -> String {
        if speed >= 1.0 {
            return String(format: "%.1fM/s", speed)
        } else if speed >= 0.001 {
            return String(format: "%.0fK/s", speed * 1024)
        }
        return "0B/s"
    }

    private func fullSpeed(_ speed: Double) -> String {
        if speed >= 1.0 {
            return String(format: "%.2f MB/s", speed)
        } else if speed >= 0.001 {
            return String(format: "%.0f KB/s", speed * 1024)
        }
        return "0 B/s"
    }
}

/// Terminal-style waveform of the last samples.
struct LiveTrace: View {
    let values: [Double]
    let color: Color
    /// nil scales to the sample peak (network traffic has no fixed maximum);
    /// pass a fixed maximum for percentages, so 40% is drawn at 40% height.
    var scale: Double? = nil

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let peak = max(scale ?? (values.max() ?? 0), 0.05)
            var path = Path()
            for (index, value) in values.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                let y = size.height * (1 - CGFloat(min(max(value / peak, 0), 1)))
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))

            if let last = values.last, let peakValue = values.max(), peakValue > 0 {
                let x = size.width
                let y = size.height * (1 - CGFloat(min(max(last / peak, 0), 1)))
                context.fill(
                    Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                    with: .color(color))
            }
        }
    }
}

struct NetworkActivityWidget_Previews: PreviewProvider {
    static var previews: some View {
        NetworkActivityWidget()
            .background(.black)
            .environmentObject(ConfigProvider(config: [:]))
            .previewLayout(.sizeThatFits)
    }
}
