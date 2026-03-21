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
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 340),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        newWindow.contentView = hostingView
        newWindow.title = ""
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)

            // Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            Spacer().frame(height: 16)

            Text("Barik Enhanced")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Spacer().frame(height: 4)

            Text("Custom Menu Bar for macOS")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text("v\(version) (\(build))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 2)
            }

            Spacer().frame(height: 24)

            // Credits
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.red.opacity(0.7))
                    Link(destination: URL(string: "https://github.com/MateoCerquetella")!) {
                        Text("Mateo Cerquetella")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.blue.opacity(0.8))
                    }
                }

                Text("Based on Barik by mocki-toki")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer().frame(height: 24)

            // Links
            HStack(spacing: 24) {
                Link(destination: URL(string: "https://github.com/MateoCerquetella/barik")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                        Text("GitHub")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.blue.opacity(0.8))
                }

                Link(destination: URL(string: "https://github.com/mocki-toki/barik")!) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                        Text("Original Barik")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.4))
                }
            }

            Spacer().frame(height: 24)
        }
        .frame(width: 320, height: 340)
        .background(Color(red: 0.08, green: 0.08, blue: 0.08))
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}
