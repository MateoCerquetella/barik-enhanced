import AppKit
import Combine

/// Detects the width of the native macOS system status area (WiFi, battery,
/// clock, Control Center, etc.) so Barik's widgets can avoid overlapping them.
///
/// Works by creating a zero-width NSStatusItem whose window position tells us
/// where the system items begin from the left edge of the screen.
final class MenuBarMetrics: ObservableObject {
    static let shared = MenuBarMetrics()

    /// The width (in points) of the area occupied by native status items,
    /// including a small breathing-room margin.
    @Published var systemStatusAreaWidth: CGFloat = 220

    private var statusItem: NSStatusItem?
    private var timer: Timer?

    private init() {}

    func startDetecting() {
        // Zero-width status item — invisible but gives us a position probe.
        statusItem = NSStatusBar.system.statusItem(withLength: 0)

        // Initial detection after the status item gets a window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.detect()
        }

        // Periodic re-detection (system items can change width, e.g. clock
        // format, new third-party items, battery icon changes).
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.detect()
        }

        // Re-detect when screens change (external display connected, etc.)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.detect()
            }
        }
    }

    private func detect() {
        guard let window = statusItem?.button?.window,
              let screen = window.screen ?? NSScreen.main else { return }

        let rightEdge = window.frame.origin.x + window.frame.width
        let screenWidth = screen.frame.width
        let width = screenWidth - rightEdge + 16 // +16 breathing room

        // Sanity: at least 50px, at most half the screen.
        if width > 50 && width < screenWidth * 0.5 {
            // Only publish when the change is meaningful (>2px).
            if abs(systemStatusAreaWidth - width) > 2 {
                systemStatusAreaWidth = width
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
