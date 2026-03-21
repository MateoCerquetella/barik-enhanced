import SwiftUI

struct DiskUsagePopup: View {
    @ObservedObject private var diskManager = DiskUsageManager.shared

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Disk Usage")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Macintosh HD")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
            }

            // Progress bar
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor)
                            .frame(width: geometry.size.width * CGFloat(diskManager.usagePercent / 100.0))
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(String(format: "%.1f GB used", diskManager.usedGB))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Text(String(format: "%.1f GB total", diskManager.totalGB))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            HStack {
                Text(String(format: "%.1f GB free", diskManager.totalGB - diskManager.usedGB))
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text(String(format: "%.1f%%", diskManager.usagePercent))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
            }
        }
        .padding(25)
        .frame(width: 280)
        .foregroundStyle(.white)
    }

    private var barColor: Color {
        if diskManager.usagePercent >= 90 { return .red }
        if diskManager.usagePercent >= 80 { return .orange }
        return .green
    }
}
