import SwiftUI

struct SyncthingPopup: View {
    @ObservedObject var manager: SyncthingManager
    let settings: SyncthingWidgetSettings

    var body: some View {
        SyncthingPopupContent(
            settings: settings,
            snapshot: manager.snapshot,
            state: manager.state(for: settings),
            isRefreshing: manager.isRefreshing,
            onRefresh: manager.refresh)
    }
}

struct SyncthingPopupContent: View {
    let settings: SyncthingWidgetSettings
    let snapshot: SyncthingSnapshot
    let state: SyncthingState
    let isRefreshing: Bool
    let onRefresh: () -> Void

    private var isCurrent: Bool {
        snapshot.settings == settings
    }

    private var progress: Double {
        isCurrent ? snapshot.completion / 100 : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            header
            progressSection
            detailPanel
            if let error = isCurrent ? snapshot.errorMessage : nil {
                notice(error, icon: "exclamationmark.triangle")
            } else {
                notice(
                    "RAM is reported by \(settings.localName)'s Syncthing process. Query the other machine's API to see its RAM.",
                    icon: "info.circle")
            }
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
                    .fill(SyncthingPalette.color(for: state).opacity(0.15))
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SyncthingPalette.color(for: state))
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text("Syncthing")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(settings.localName) ↔ \(settings.peerName)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                    .animation(
                        isRefreshing
                            ? .linear(duration: 0.8).repeatForever(
                                autoreverses: false)
                            : .default,
                        value: isRefreshing)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isRefreshing)
            .accessibilityLabel("Refresh Syncthing status")
            .help("Refresh Syncthing status")
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(state.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SyncthingPalette.color(for: state))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(SyncthingPalette.color(for: state))
                        .frame(
                            width: geometry.size.width
                                * max(0, min(progress, 1)))
                }
            }
            .frame(height: 7)

            HStack {
                Text("\(displayedBytes(snapshot.syncedBytes)) synced")
                Spacer()
                Text("\(displayedBytes(snapshot.needBytes)) remaining")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
        }
    }

    private var detailPanel: some View {
        VStack(spacing: 0) {
            detailRow(
                label: "FOLDER",
                value: settings.folderID,
                trailing: snapshot.folderState?.uppercased() ?? "UNKNOWN")
            Divider().overlay(.white.opacity(0.08))
            detailRow(
                label: "PEER",
                value: settings.peerName,
                trailing: snapshot.peerConnected ? "CONNECTED" : "OFFLINE")
            Divider().overlay(.white.opacity(0.08))
            detailRow(
                label: "ITEMS",
                value: "Pending changes",
                trailing: "\(snapshot.needItems)")
            Divider().overlay(.white.opacity(0.08))
            detailRow(
                label: "RAM",
                value: "Runtime reserved",
                trailing: displayedMemory(snapshot.processMemoryBytes))
            Divider().overlay(.white.opacity(0.08))
            detailRow(
                label: "HEAP",
                value: "Allocated",
                trailing: displayedMemory(snapshot.heapMemoryBytes))
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
        trailing: String
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(trailing)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
    }

    private func notice(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SyncthingPalette.color(for: state))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(SyncthingPalette.color(for: state).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private var footer: some View {
        HStack {
            Text("LAST CHECK")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
            Spacer()
            Text(lastCheckText)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var lastCheckText: String {
        guard isCurrent, let checkedAt = snapshot.checkedAt else {
            return isRefreshing ? "CHECKING..." : "NEVER"
        }
        return Self.timeFormatter.string(from: checkedAt)
    }

    private func displayedBytes(_ bytes: Int64) -> String {
        guard isCurrent, snapshot.checkedAt != nil,
              snapshot.state != .unavailable
        else {
            return "-"
        }
        return Self.byteFormatter.string(fromByteCount: max(0, bytes))
    }

    private func displayedMemory(_ bytes: Int64) -> String {
        guard isCurrent, snapshot.checkedAt != nil, bytes > 0 else {
            return "-"
        }
        return Self.byteFormatter.string(fromByteCount: bytes)
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .memory
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}
