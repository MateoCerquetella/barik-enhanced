import SwiftUI

class WidgetConfiguratorWindow {
    private static var window: NSWindow?

    static func show() {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let configuratorView = WidgetConfiguratorView()
        let hostingView = NSHostingView(rootView: configuratorView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        newWindow.contentView = hostingView
        newWindow.title = "Barik Enhanced - Widget Configuration"
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.titlebarAppearsTransparent = true
        newWindow.backgroundColor = .black
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        window = newWindow
    }
}
