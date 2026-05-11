import SwiftUI
import ServiceManagement

struct SettingsMenuView: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            SettingsMenuItem(icon: "square.grid.2x2", title: "Configure Widgets") {
                WidgetConfiguratorWindow.show()
            }

            // Launch at Login
            Button(action: {
                launchAtLogin.toggle()
                do {
                    if launchAtLogin {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLogin = !launchAtLogin
                }
            }) {
                HStack(spacing: 10) {
                    Image(systemName: launchAtLogin ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 13))
                        .foregroundStyle(launchAtLogin ? .green : .white.opacity(0.4))
                        .frame(width: 20)

                    Text("Launch at Login")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            Divider().background(.white.opacity(0.15)).padding(.horizontal, 12).padding(.vertical, 2)

            SettingsMenuItem(icon: "info.circle", title: "About Barik Enhanced") {
                AboutWindow.show()
            }

            SettingsMenuItem(icon: "power", title: "Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 200)
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
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
