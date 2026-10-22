import SwiftUI

struct BackgroundView: View {
    @ObservedObject var configManager = ConfigManager.shared
    let screen: NSScreen?

    private var wallpaper: NSImage? {
        guard let screen,
              let url = NSWorkspace.shared.desktopImageURL(for: screen)
        else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        if configManager.config.experimental.background.displayed {
            GeometryReader { geometry in
                backgroundColor(geometry)
            }
        }
    }

    @ViewBuilder
    private func backgroundColor(_ geometry: GeometryProxy) -> some View {
        let height = configManager.config.experimental.background.resolveHeight()
            ?? geometry.size.height
        let background = configManager.config.experimental.background
        let theme: ColorScheme? = {
            switch configManager.config.rootToml.theme {
            case "dark": return .dark
            case "light": return .light
            default: return nil
            }
        }()

        Group {
            if background.black {
                Color.black.opacity(0.6)
            } else if let wallpaper {
                // A Material only tints the desktop; this is a real Gaussian
                // blur of the wallpaper, so none of the original colours are
                // replaced by gray.
                Image(nsImage: wallpaper)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: background.blurRadius)
                    .clipped()
            } else {
                Color.clear
                    .background(background.blur)
            }
        }
        .frame(width: geometry.size.width, height: height, alignment: .top)
        .preferredColorScheme(theme)
    }
}
