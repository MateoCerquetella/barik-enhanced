import SwiftUI
import ServiceManagement

struct SettingsMenuView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Configure Widgets
            SettingsMenuItem(icon: "square.grid.2x2", title: "Configure Widgets...") {
                WidgetConfiguratorWindow.show()
            }

            Divider().background(.white.opacity(0.2)).padding(.vertical, 4)

            // Launch at Login
            HStack(spacing: 10) {
                Image(systemName: "power")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 20)

                Text("Launch at Login")
                    .font(.system(size: 13))
                    .foregroundStyle(.white)

                Spacer()

                Toggle("", isOn: $launchAtLogin)
                    .toggleStyle(.switch)
                    .scaleEffect(0.7)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("Failed to update login item: \(error)")
                            launchAtLogin = !newValue
                        }
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider().background(.white.opacity(0.2)).padding(.vertical, 4)

            // About
            SettingsMenuItem(icon: "info.circle", title: "About Barik") {
                AboutWindow.show()
            }

            // Quit
            SettingsMenuItem(icon: "xmark.circle", title: "Quit Barik") {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 8)
        .frame(width: 220)
    }
}

struct SettingsMenuItem: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color.white.opacity(0.001))
    }
}
