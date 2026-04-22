import SwiftUI

struct LocalIPAddressWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject private var manager = LocalIPAddressManager.shared

    private var config: ConfigData { configProvider.config }
    private var showInterface: Bool { config["show-interface"]?.boolValue ?? false }
    private var showIcon: Bool { config["show-icon"]?.boolValue ?? true }

    var body: some View {
        HStack(spacing: 4) {
            if showIcon {
                Image(systemName: manager.isConnected ? "network" : "network.slash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(manager.isConnected ? .icon : .red.opacity(0.8))
            }

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.foregroundOutside)
        }
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .contentShape(Rectangle())
        .onTapGesture {
            guard manager.isConnected else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(manager.ipAddress, forType: .string)
        }
        .help(manager.isConnected ? "Local IP address. Click to copy." : "No local IP address detected")
    }

    private var label: String {
        guard manager.isConnected else { return "No IP" }
        guard showInterface, !manager.interfaceName.isEmpty else {
            return manager.ipAddress
        }
        return "\(manager.interfaceName) \(manager.ipAddress)"
    }
}

struct LocalIPAddressWidget_Previews: PreviewProvider {
    static var previews: some View {
        LocalIPAddressWidget()
            .environmentObject(ConfigProvider(config: [:]))
            .frame(height: 55)
            .background(Color.black)
    }
}
