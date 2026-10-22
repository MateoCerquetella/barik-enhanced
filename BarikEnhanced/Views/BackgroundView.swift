import SwiftUI

struct BackgroundView: View {
    @ObservedObject var configManager = ConfigManager.shared
    @ObservedObject var menuBarMetrics = MenuBarMetrics.shared

    private func menuBarBlurView(_ geometry: GeometryProxy) -> some View {
        let theme: ColorScheme? = {
            switch configManager.config.rootToml.theme {
            case "dark": return .dark
            case "light": return .light
            default: return nil
            }
        }()

        let menuBarHeight =
            (configManager.config.experimental.foreground.resolveHeight() ?? 32) - 6
        let isBottom = configManager.config.experimental.position == .bottom
        let trailingPad = max(CGFloat(6), menuBarMetrics.systemStatusAreaWidth - 6)

        return VStack(spacing: 0) {
            if !isBottom {
                blurBar(menuBarHeight: menuBarHeight, trailingPad: trailingPad, y: 2)
                Spacer()
            } else {
                Spacer()
                blurBar(menuBarHeight: menuBarHeight, trailingPad: trailingPad, y: -2)
            }
        }
        .preferredColorScheme(theme)
        .animation(
            .easeInOut(duration: 0.3),
            value: configManager.config.experimental.background.black)
    }

    /// Rounded glass behind the whole widget bar, from the left padding to the
    /// system status area. Top and bottom positions mirror the shadow.
    @ViewBuilder
    private func blurBar(
        menuBarHeight: CGFloat,
        trailingPad: CGFloat,
        y: CGFloat
    ) -> some View {
        if configManager.config.experimental.background.black {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .frame(height: menuBarHeight)
                .padding(.leading, 6)
                .padding(.trailing, trailingPad)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: y / 2)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .background(
                    configManager.config.experimental.background.blur,
                    in: RoundedRectangle(cornerRadius: 12))
                .frame(height: menuBarHeight)
                .padding(.leading, 6)
                .padding(.trailing, trailingPad)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: y)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                        .padding(.leading, 6)
                        .padding(.trailing, trailingPad))
        }
    }

    var body: some View {
        if configManager.config.experimental.background.displayed {
            GeometryReader { geometry in
                menuBarBlurView(geometry)
                    .id("refined-blur")
            }
        }
    }
}
