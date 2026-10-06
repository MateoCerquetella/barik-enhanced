import SwiftUI

enum SyncthingPalette {
    static func color(for state: SyncthingState) -> Color {
        switch state {
        case .synced: return .green
        case .syncing: return .blue
        case .scanning: return .yellow
        case .disconnected: return .orange
        case .unavailable: return .red
        case .checking: return .gray
        }
    }
}

struct SyncthingWidget: View {
    @EnvironmentObject private var configProvider: ConfigProvider
    @ObservedObject private var manager: SyncthingManager
    @State private var rect = CGRect.zero
    @State private var activationID = UUID()

    init(manager: SyncthingManager = .shared) {
        self.manager = manager
    }

    private var settings: SyncthingWidgetSettings {
        SyncthingWidgetSettings(config: configProvider.config)
    }

    var body: some View {
        SyncthingWidgetContent(
            state: manager.state(for: settings),
            progress: displayedProgress,
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
                        .onAppear { rect = geometry.frame(in: .global) }
                        .onChange(of: geometry.frame(in: .global)) {
                            _, newRect in rect = newRect
                        }
                })
            .onAppear {
                manager.activate(clientID: activationID, settings: settings)
            }
            .onChange(of: settings) { _, newSettings in
                manager.update(
                    clientID: activationID,
                    settings: newSettings)
            }
            .onDisappear {
                manager.deactivate(clientID: activationID)
            }
    }

    private var displayedProgress: Double {
        guard manager.snapshot.settings == settings else { return 0 }
        return manager.snapshot.completion / 100
    }

    private func showDetails() {
        MenuBarPopup.show(
            rect: rect,
            id: "syncthing-\(activationID.uuidString)"
        ) {
            SyncthingPopup(manager: manager, settings: settings)
        }
    }
}

struct SyncthingWidgetContent: View {
    let state: SyncthingState
    let progress: Double
    let onOpenDetails: () -> Void

    var body: some View {
        Button(action: onOpenDetails) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SyncthingPalette.color(for: state))

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(state.compactLabel)
                            .font(.system(
                                size: 8,
                                weight: .bold,
                                design: .monospaced))
                        if state == .syncing || state == .scanning {
                            Text("\(Int(progress * 100))%")
                                .font(.system(
                                    size: 8,
                                    weight: .medium,
                                    design: .monospaced))
                        }
                    }
                    .foregroundStyle(SyncthingPalette.color(for: state))

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.2))
                            Capsule()
                                .fill(SyncthingPalette.color(for: state))
                                .frame(
                                    width: geometry.size.width
                                        * max(0, min(progress, 1)))
                        }
                    }
                    .frame(width: 48, height: 3)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Syncthing \(state.displayName), \(Int(progress * 100)) percent")
        .help("Syncthing: \(state.displayName)")
        .fixedSize(horizontal: true, vertical: false)
    }
}
