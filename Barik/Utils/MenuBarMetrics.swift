import AppKit
import Combine

/// Detects the width of the native macOS system status area (WiFi, battery,
/// clock, Control Center, etc.) so Barik's widgets can avoid overlapping them.
///
/// Works by placing a tiny NSStatusItem at the left edge of the status area.
/// Its window x-coordinate tells us where native items begin.
final class MenuBarMetrics: ObservableObject {
    static let shared = MenuBarMetrics()

    /// The width (in points) of the area occupied by native status items.
    @Published var systemStatusAreaWidth: CGFloat = 0

    private var statusItem: NSStatusItem?
    private var timer: Timer?
    private var hasDetected = false

    private init() {}

    func startDetecting() {
        // 1-pixel wide status item — practically invisible.
        statusItem = NSStatusBar.system.statusItem(withLength: 1)
        statusItem?.button?.alphaValue = 0

        // Retry detection until it succeeds.
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.detect()
        }

        // Also try immediately after a short delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.detect()
        }
    }

    private func detect() {
        guard let button = statusItem?.button,
              let window = button.window,
              let screen = window.screen ?? NSScreen.main else { return }

        // Our status item sits at the left edge of all status items.
        // Everything to its right is native/third-party status items.
        let probeRightEdge = window.frame.origin.x + window.frame.width
        let screenMaxX = screen.frame.maxX
        let width = screenMaxX - probeRightEdge

        if width > 10 && width < screenMaxX * 0.5 {
            if !hasDetected || abs(systemStatusAreaWidth - width) > 2 {
                systemStatusAreaWidth = width
                hasDetected = true
            }
        }

        // Once detected, slow down the timer.
        if hasDetected {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                self?.detect()
            }
        }
    }

    deinit {
        timer?.invalidate()
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
    }
}
