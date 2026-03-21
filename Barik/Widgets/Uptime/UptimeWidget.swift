import SwiftUI

struct UptimeWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @StateObject private var uptimeManager = UptimeManager()

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.icon)

            Text(uptimeManager.uptimeString)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.foregroundOutside)
        }
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
    }
}
