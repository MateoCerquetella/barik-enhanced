import SwiftUI

class AboutWindow {
    private static var window: NSWindow?

    static func show() {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutView = AboutView()
        let hostingView = NSHostingView(rootView: aboutView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 300),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newWindow.contentView = hostingView
        newWindow.title = "About Barik"
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.titlebarAppearsTransparent = true
        newWindow.backgroundColor = .black
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            // App icon
            Image(systemName: "menubar.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.white)
                .padding(.top, 20)

            Text("Barik")
                .font(.system(size: 28, weight: .bold))

            Text("Custom Menu Bar for macOS")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Version \(version)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            }

            Divider().background(.white.opacity(0.2)).padding(.horizontal, 40)

            VStack(spacing: 8) {
                Text("Built with love by")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))

                Text("Mateo Cerquetella")
                    .font(.system(size: 14, weight: .semibold))

                Text("Based on Barik by mocki-toki")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/MateoCerquetella/barik")!)
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)

                Link("Original Barik", destination: URL(string: "https://github.com/mocki-toki/barik")!)
                    .font(.system(size: 12))
                    .foregroundStyle(.blue)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 350, height: 300)
        .background(.black)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}
