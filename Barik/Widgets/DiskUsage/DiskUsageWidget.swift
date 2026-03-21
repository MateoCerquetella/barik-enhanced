import SwiftUI

struct DiskUsageWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    var config: ConfigData { configProvider.config }
    var showPercentage: Bool { config["show-percentage"]?.boolValue ?? true }
    var warningLevel: Double { Double(config["warning-level"]?.intValue ?? 80) }
    var criticalLevel: Double { Double(config["critical-level"]?.intValue ?? 90) }

    @StateObject private var diskManager = DiskUsageManager()
    @State private var rect: CGRect = .zero

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(diskColor)

            if showPercentage {
                Text("\(Int(diskManager.usagePercent))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.foregroundOutside)
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { rect = geometry.frame(in: .global) }
                    .onChange(of: geometry.frame(in: .global)) { _, newState in rect = newState }
            }
        )
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "disk") {
                DiskUsagePopup()
            }
        }
    }

    private var diskColor: Color {
        if diskManager.usagePercent >= criticalLevel { return .red.opacity(0.8) }
        if diskManager.usagePercent >= warningLevel { return .orange }
        return .icon
    }
}
