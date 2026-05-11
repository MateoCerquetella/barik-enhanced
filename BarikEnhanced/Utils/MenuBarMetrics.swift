import AppKit
import Combine

/// Reserves trailing space in Barik Enhanced's menu bar so its widgets don't render
/// where macOS draws its native status icons (WiFi, battery, clock, Control
/// Center, etc.).
///
/// History: previously this measured the actual native-status-area width by
/// placing a probe NSStatusItem at the left edge and reading its frame. That
/// turned out to react to third-party menu-bar utilities (Hidden Bar,
/// Bartender, etc.) — every time the user toggled those, Barik Enhanced's trailing
/// widgets shifted around because the underlying width changed. To avoid that
/// jitter, we now reserve a fixed conservative width that comfortably clears
/// a typical macOS status area.
final class MenuBarMetrics: ObservableObject {
    static let shared = MenuBarMetrics()

    /// Fixed trailing reservation in points. Chosen to clear the native
    /// status-area cluster on a typical macOS setup. Override per-user via
    /// the `experimental.foreground.horizontalPadding` config — Barik Enhanced uses
    /// `max(horizontalPadding, systemStatusAreaWidth)` for the trailing pad.
    @Published var systemStatusAreaWidth: CGFloat = 220

    private init() {}

    /// Kept for API compatibility with AppDelegate's lifecycle hooks; the
    /// reservation is static and does not need to be re-detected on wake or
    /// session changes.
    func startDetecting() {}

    /// Kept for API compatibility. No-op — see `startDetecting`.
    func restartDetection() {}
}
