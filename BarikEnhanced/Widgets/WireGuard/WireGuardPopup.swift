import SwiftUI

struct WireGuardPopup: View {
    @ObservedObject var manager: WireGuardManager
    let settings: WireGuardWidgetSettings

    var body: some View {
        WireGuardPopupContent(
            settings: settings,
            snapshot: manager.snapshot,
            status: manager.healthStatus(for: settings),
            isRefreshing: manager.isRefreshing,
            onRefresh: manager.refresh)
    }
}

struct WireGuardPopupContent: View {
    let settings: WireGuardWidgetSettings
    let snapshot: WireGuardSnapshot
    let status: WireGuardHealthStatus
    let isRefreshing: Bool
    let onRefresh: () -> Void

    private var hasCurrentSnapshot: Bool {
        snapshot.settings == settings
    }

    private var displayedTunnelState: WireGuardTunnelState {
        hasCurrentSnapshot ? snapshot.tunnelState : .unknown
    }

    private var displayedGatewayProbe: WireGuardProbeState {
        hasCurrentSnapshot ? snapshot.gatewayProbe : .unknown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            header
            connectionPanel
            peerSection
            probeNotice
            footer
        }
        .frame(width: 370)
        .padding(20)
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(WireGuardPalette.color(for: status).opacity(0.15))
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WireGuardPalette.color(for: status))
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("WireGuard")
                    .font(.system(size: 14, weight: .semibold))
                Text(status.displayName.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(WireGuardPalette.color(for: status))
            }

            Spacer(minLength: 12)

            Button(action: onRefresh) {
                Label(
                    isRefreshing ? "Checking" : "Refresh",
                    systemImage: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isRefreshing)
            .accessibilityLabel("Refresh WireGuard probes")
            .help("Refresh system state and ICMP probes")
        }
    }

    private var connectionPanel: some View {
        VStack(spacing: 0) {
            detailRow(
                label: "TUNNEL",
                value: settings.tunnelName,
                trailing: displayedTunnelState.displayName,
                trailingColor: tunnelStateColor)

            Divider().overlay(.white.opacity(0.08))

            detailRow(
                label: "GATEWAY",
                value: settings.gateway,
                trailing: displayedGatewayProbe.displayName,
                trailingColor: WireGuardPalette.color(
                    for: displayedGatewayProbe))
        }
        .background(.white.opacity(0.055))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func detailRow(
        label: String,
        value: String,
        trailing: String,
        trailingColor: Color
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(.tertiary)
                .frame(width: 58, alignment: .leading)

            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)

            Spacer(minLength: 8)

            statusBadge(trailing, color: trailingColor)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
    }

    private var peerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PEER ICMP PROBES")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(settings.peers.count)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            if settings.peers.isEmpty {
                Text("No peer probes configured")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 6) {
                    ForEach(settings.peers) { peer in
                        peerRow(peer)
                    }
                }
            }
        }
    }

    private func peerRow(_ peer: WireGuardPeer) -> some View {
        let state = hasCurrentSnapshot
            ? snapshot.peerProbe(for: peer)
            : WireGuardProbeState.unknown

        return HStack(spacing: 10) {
            Circle()
                .fill(WireGuardPalette.color(for: state))
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(peer.name)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(peer.address)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            statusBadge(
                state.displayName,
                color: WireGuardPalette.color(for: state))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private var probeNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WireGuardPalette.accent)
                .padding(.top, 1)

            Text(
                "ICMP reachability probes only — not an authoritative WireGuard or RouterOS handshake.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(WireGuardPalette.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private var footer: some View {
        HStack {
            Text("LAST CHECK")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(.tertiary)
            Spacer()
            Text(lastCheckText)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func statusBadge(_ text: String, color: Color) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var tunnelStateColor: Color {
        switch displayedTunnelState {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .gray
        case .unknown:
            return .gray
        }
    }

    private var lastCheckText: String {
        guard hasCurrentSnapshot, let checkedAt = snapshot.checkedAt else {
            return isRefreshing ? "CHECKING…" : "NEVER"
        }
        return Self.timeFormatter.string(from: checkedAt)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

struct WireGuardPopupContent_Previews: PreviewProvider {
    static var previews: some View {
        let settings = WireGuardWidgetSettings(
            tunnelName: "Example WireGuard",
            gateway: "192.0.2.1",
            peers: [
                WireGuardPeer(name: "Example Router", address: "198.51.100.10"),
                WireGuardPeer(name: "Example Node", address: "203.0.113.20"),
            ])
        let snapshot = WireGuardSnapshot(
            settings: settings,
            tunnelState: .connected,
            gatewayProbe: .reachable,
            peerProbes: [
                WireGuardPeerProbe(peer: settings.peers[0], state: .reachable),
                WireGuardPeerProbe(peer: settings.peers[1], state: .unreachable),
            ],
            checkedAt: Date())

        WireGuardPopupContent(
            settings: settings,
            snapshot: snapshot,
            status: .healthy,
            isRefreshing: false,
            onRefresh: {})
            .background(.black)
            .previewLayout(.sizeThatFits)
    }
}
