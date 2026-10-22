import SwiftUI

struct SystemMonitorPopup: View {
    @ObservedObject private var systemMonitor = SystemMonitorManager.shared
    @State private var liveUpdatesActive = false

    private let willHideWindow = NotificationCenter.default.publisher(
        for: .willHideWindow)
    private let willChangeContent = NotificationCenter.default.publisher(
        for: .willChangeContent)
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: "cpu")
                        .font(.title2)
                        .foregroundStyle(.white)
                    Text("System Monitor")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                        Text("LIVE 1s")
                            .font(.system(
                                size: 9,
                                weight: .bold,
                                design: .monospaced))
                            .foregroundStyle(.green.opacity(0.85))
                    }
                    Text(Date(), style: .time)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                
                // CPU Section with Chart
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("CPU Usage")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(Int(systemMonitor.cpuLoad))%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(cpuColor)
                    }
                    
                    // CPU Chart
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.3))
                            .frame(height: 60)
                        
                        CPUChart(data: systemMonitor.cpuHistory, color: cpuColor)
                            .frame(height: 50)
                            .padding(.horizontal, 8)
                    }
                    
                    // CPU Breakdown
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("User")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                            Text("\(Int(systemMonitor.userLoad))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("System")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                            Text("\(Int(systemMonitor.systemLoad))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Idle")
                                .font(.caption2)
                                .foregroundStyle(.gray)
                            Text("\(Int(systemMonitor.idleLoad))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                        }
                        
                        Spacer()
                    }
                }
            
            Divider()
                .background(.gray.opacity(0.3))
            
                // RAM Section with Chart
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Memory Usage")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(systemMonitor.ramUsage))%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(ramColor)
                            Text("\(String(format: "%.1f", usedRAM)) GB")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    // RAM Chart
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.3))
                            .frame(height: 60)
                        
                        RAMChart(data: systemMonitor.ramHistory, color: ramColor)
                            .frame(height: 50)
                            .padding(.horizontal, 8)
                    }
                    
                    // Memory breakdown with visual bars
                    VStack(spacing: 6) {
                        MemoryBar(label: "Active", value: systemMonitor.activeRAM, total: systemMonitor.totalRAM, color: .blue)
                        MemoryBar(label: "Wired", value: systemMonitor.wiredRAM, total: systemMonitor.totalRAM, color: .orange)
                        MemoryBar(label: "Compressed", value: systemMonitor.compressedRAM, total: systemMonitor.totalRAM, color: .purple)
                    }
                }
                
                Divider()
                    .background(.gray.opacity(0.3))
                
                // Network Section: terminal-style, 1 Hz live
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("NET I/O")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                        Spacer()
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 4, height: 4)
                            Text("LIVE · 1s")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green.opacity(0.8))
                        }
                    }

                    ioChannel(
                        label: "TX",
                        glyph: "▲",
                        speed: systemMonitor.uploadSpeed,
                        history: systemMonitor.uploadHistory,
                        color: .green)
                    ioChannel(
                        label: "RX",
                        glyph: "▼",
                        speed: systemMonitor.downloadSpeed,
                        history: systemMonitor.downloadHistory,
                        color: .cyan)
                }

                Divider()
                    .background(.gray.opacity(0.3))

                TopProcessSection(
                    cpuProcesses: systemMonitor.topCPUProcesses,
                    ramProcesses: systemMonitor.topRAMProcesses,
                    onKill: { systemMonitor.kill(process: $0) })
                
            }
        }
        .padding(16)
        .background(.black.opacity(0.9))
        .cornerRadius(12)
        .frame(width: 320)
        .onAppear { startLiveUpdates() }
        .onDisappear { stopLiveUpdates() }
        .onReceive(willHideWindow) { _ in stopLiveUpdates() }
        .onReceive(willChangeContent) { _ in stopLiveUpdates() }
    }

    /// Panels are only ordered out, so `onDisappear` is not guaranteed when the
    /// popup closes. The window notifications cover that path; the flag keeps
    /// the client count balanced when both fire.
    private func startLiveUpdates() {
        guard !liveUpdatesActive else { return }
        liveUpdatesActive = true
        systemMonitor.beginLiveUpdates()
    }

    private func stopLiveUpdates() {
        guard liveUpdatesActive else { return }
        liveUpdatesActive = false
        systemMonitor.endLiveUpdates()
    }

    private var usedRAM: Double {
        systemMonitor.activeRAM + systemMonitor.wiredRAM + systemMonitor.compressedRAM
    }

    private func ioChannel(
        label: String,
        glyph: String,
        speed: Double,
        history: [Double],
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(glyph)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(formatSpeed(speed))
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(color)

            NetworkTrace(values: history, color: color)
                .frame(height: 26)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(color.opacity(0.06))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(color.opacity(0.18), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var cpuColor: Color {
        let cpu = Int(systemMonitor.cpuLoad)
        if cpu >= 90 {
            return .red
        } else if cpu >= 70 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private var ramColor: Color {
        let ram = Int(systemMonitor.ramUsage)
        if ram >= 90 {
            return .red
        } else if ram >= 70 {
            return .yellow
        } else {
            return .green
        }
    }
    
    private func formatSpeed(_ speed: Double) -> String {
        if speed >= 1.0 {
            return String(format: "%.2f MB/s", speed)
        } else if speed >= 0.001 {
            return String(format: "%.0f KB/s", speed * 1024)
        } else {
            return "0 B/s"
        }
    }
    
}

// MARK: - Chart Views

struct CPUChart: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }
                
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(data.count - 1)
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height - (CGFloat(value) / 100.0) * height
                    
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            
            // Add fill area
            Path { path in
                guard !data.isEmpty else { return }
                
                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(data.count - 1)
                
                path.move(to: CGPoint(x: 0, y: height))
                
                for (index, value) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height - (CGFloat(value) / 100.0) * height
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.addLine(to: CGPoint(x: geometry.size.width, y: height))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [color.opacity(0.3), color.opacity(0.1)], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct RAMChart: View {
    let data: [Double]
    let color: Color
    
    var body: some View {
        CPUChart(data: data, color: color)
    }
}

struct NetworkTrace: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            let peak = max(values.max() ?? 0, 0.05)
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

            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.22), color.opacity(0.01)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)))

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            if let last = values.last {
                let y = size.height * (1 - CGFloat(min(max(last / peak, 0), 1)))
                context.fill(
                    Path(ellipseIn: CGRect(x: size.width - 3, y: y - 2, width: 4, height: 4)),
                    with: .color(color))
            }
        }
    }
}

struct MemoryBar: View {
    let label: String
    let value: Double
    let total: Double
    let color: Color
    
    private var percentage: Double {
        total > 0 ? (value / total) * 100 : 0
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.gray)
                .frame(width: 70, alignment: .leading)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.gray.opacity(0.2))
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: max(2, percentage * 1.5), height: 6)
                    .animation(.easeInOut(duration: 0.3), value: percentage)
            }
            
            Text("\(String(format: "%.1f", value)) GB")
                .font(.caption2)
                .foregroundStyle(.white)
                .frame(width: 50, alignment: .trailing)
        }
    }
}



struct SystemMonitorPopup_Previews: PreviewProvider {
    static var previews: some View {
        SystemMonitorPopup()
            .previewLayout(.sizeThatFits)
    }
} 