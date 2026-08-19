import SwiftUI

enum WireGuardPalette {
    static let accent = Color(
        red: 0.30,
        green: 0.78,
        blue: 0.92)

    static func color(for status: WireGuardHealthStatus) -> Color {
        switch status {
        case .healthy:
            return .green
        case .degraded:
            return .orange
        case .disconnected:
            return .gray
        case .checking:
            return .yellow
        }
    }

    static func color(for state: WireGuardProbeState) -> Color {
        switch state {
        case .reachable:
            return .green
        case .unreachable:
            return .orange
        case .unknown:
            return .gray
        }
    }
}

struct WireGuardWidget: View {
    @EnvironmentObject private var configProvider: ConfigProvider
    @ObservedObject private var manager: WireGuardManager

    @State private var rect = CGRect.zero
    @State private var activationID = UUID()

    init(manager: WireGuardManager = .shared) {
        self.manager = manager
    }

    private var settings: WireGuardWidgetSettings {
        WireGuardWidgetSettings(config: configProvider.config)
    }

    var body: some View {
        WireGuardWidgetContent(
            status: manager.healthStatus(for: settings),
            onOpenDetails: showDetails)
            .foregroundStyle(.foregroundOutside)
            .shadow(color: .foregroundShadowOutside, radius: 3)
            .experimentalConfiguration(cornerRadius: 15)
            .frame(maxHeight: .infinity)
            .background(.black.opacity(0.001))
            .contentShape(Rectangle())
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            rect = geometry.frame(in: .global)
                        }
                        .onChange(of: geometry.frame(in: .global)) {
                            _, newRect in
                            rect = newRect
                        }
                })
            .onAppear {
                manager.activate(
                    clientID: activationID,
                    settings: settings)
            }
            .onChange(of: settings) { _, settings in
                manager.update(
                    clientID: activationID,
                    settings: settings)
            }
            .onDisappear {
                manager.deactivate(clientID: activationID)
            }
    }

    private func showDetails() {
        MenuBarPopup.show(
            rect: rect,
            id: "wireguard-\(activationID.uuidString)"
        ) {
            WireGuardPopup(manager: manager, settings: settings)
        }
    }
}

struct WireGuardWidgetContent: View {
    let status: WireGuardHealthStatus
    let onOpenDetails: () -> Void

    var body: some View {
        Button(action: onOpenDetails) {
            HStack(spacing: 5) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 12, weight: .semibold))

                    Circle()
                        .fill(WireGuardPalette.color(for: status))
                        .frame(width: 5, height: 5)
                        .overlay {
                            Circle()
                                .stroke(.black.opacity(0.7), lineWidth: 1)
                        }
                        .offset(x: 2, y: 1)
                }

                Text(status.compactLabel)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(WireGuardPalette.color(for: status))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("WireGuard \(status.displayName)")
        .help("WireGuard: \(status.displayName)")
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct WireGuardWidgetContent_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 18) {
            ForEach(
                [
                    WireGuardHealthStatus.healthy,
                    .degraded,
                    .disconnected,
                    .checking,
                ],
                id: \.displayName
            ) { status in
                WireGuardWidgetContent(status: status, onOpenDetails: {})
            }
        }
        .padding()
        .background(.black)
        .foregroundStyle(.white)
        .previewLayout(.sizeThatFits)
    }
}
