import AppKit
import Combine
import os
import Foundation

class SpacesViewModel: ObservableObject, ConditionallyActivatableWidget {
    static let shared = SpacesViewModel()
    @Published var spaces: [AnySpace] = []
    private static let perfLog = Logger(subsystem: "com.barik-enhanced.perf", category: "spaces")
    private var timer: Timer?
    private var recoveryTimer: Timer?
    private var provider: AnySpacesProvider?
    private var currentProviderKind: ProviderKind?
    private var currentInterval: TimeInterval = 5.0
    private var lastEventLoadTime: CFAbsoluteTime = 0
    let widgetId = "default.spaces"
    
    private var isActive = false

    private enum ProviderKind: Equatable {
        case yabai
        case aerospace
    }

    private init() {
        setupNotifications()
        setupDarwinNotification()
        refreshProvider(force: true)
        // For now, always activate to ensure widgets work
        activate()
    }

    /// Listens for a Darwin notification posted by AeroSpace's
    /// `exec-on-workspace-change` / `on-focus-changed` hooks via
    /// `notifyutil -p com.barik-enhanced.aerospace-refresh`.
    /// This gives near-instant menu-bar updates on workspace/focus changes
    /// regardless of the polling interval set by the performance mode.
    private func setupDarwinNotification() {
        let callback: CFNotificationCallback = { _, _, _, _, _ in
            let start = CFAbsoluteTimeGetCurrent()
            DispatchQueue.main.async {
                SpacesViewModel.shared.loadSpaces(source: "aerospace-event", triggerTime: start)
            }
        }

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            callback,
            "com.barik-enhanced.aerospace-refresh" as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        stopMonitoring()
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupNotifications() {
        // Listen for performance mode changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PerformanceModeChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let intervals = notification.object as? [String: TimeInterval],
               let newInterval = intervals["spaces"] {
                self?.updateTimerInterval(newInterval)
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.forceRefresh()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.forceRefresh()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.forceRefresh()
        }

        // Instant refresh on app switch — avoids waiting for the poll timer
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.loadSpaces(source: "app-activation", triggerTime: CFAbsoluteTimeGetCurrent())
        }

        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.forceRefresh()
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name("ConfigChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.forceRefresh()
        }

        NotificationCenter.default.addObserver(
            forName: Notification.Name("ManualReloadTriggered"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.forceRefresh()
        }
        
        // For future use - widget activation/deactivation
        // NotificationCenter.default.addObserver(
        //     forName: NSNotification.Name("WidgetActivationChanged"),
        //     object: nil,
        //     queue: .main
        // ) { [weak self] notification in
        //     if let activeWidgets = notification.object as? Set<String> {
        //         if activeWidgets.contains(self?.widgetId ?? "") {
        //             self?.activate()
        //         } else {
        //             self?.deactivate()
        //         }
        //     }
        // }
    }
    
    func activate() {
        guard !isActive else { 
            return 
        }
        
        isActive = true
        
        // Get current performance mode interval
        let performanceManager = PerformanceModeManager.shared
        let intervals = performanceManager.getTimerIntervals(for: performanceManager.currentMode)
        currentInterval = intervals["spaces"] ?? 5.0
        
        startMonitoring()
    }
    
    func deactivate() {
        guard isActive else { return }
        isActive = false
        stopMonitoring()
    }
    
    private func updateTimerInterval(_ newInterval: TimeInterval) {
        guard isActive else { return }
        currentInterval = newInterval
        
        // Restart timer with new interval
        stopMonitoring()
        startMonitoring()
    }

    private func startMonitoring() {
        stopMonitoring()

        let refreshTimer = Timer(timeInterval: currentInterval, repeats: true) { [weak self] _ in
            self?.loadSpaces()
        }
        refreshTimer.tolerance = min(max(currentInterval * 0.2, 0.1), 1.0)
        RunLoop.main.add(refreshTimer, forMode: .common)
        timer = refreshTimer

        let recoveryRefreshTimer = Timer(timeInterval: 900, repeats: true) { [weak self] _ in
            self?.forceRefresh()
        }
        recoveryRefreshTimer.tolerance = 60
        RunLoop.main.add(recoveryRefreshTimer, forMode: .common)
        recoveryTimer = recoveryRefreshTimer

        loadSpaces()
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        recoveryTimer?.invalidate()
        recoveryTimer = nil
    }

    fileprivate func loadSpaces(source: String = "timer", triggerTime: CFAbsoluteTime? = nil) {
        // Debounce event-driven calls: skip if another event-driven load
        // started within the last 100ms (a single switch fires 3 events)
        if let t = triggerTime {
            let now = CFAbsoluteTimeGetCurrent()
            if (now - lastEventLoadTime) < 0.1 {
                return
            }
            lastEventLoadTime = now
        }

        refreshProvider(force: false)

        // Use higher QoS for event-driven loads (user is waiting)
        let qos: DispatchQoS.QoSClass = triggerTime != nil ? .userInitiated : .background
        DispatchQueue.global(qos: qos).async { [weak self] in
            guard let self = self else { return }
            guard let provider = self.provider else {
                DispatchQueue.main.async {
                    if !self.spaces.isEmpty {
                        self.spaces = []
                    }
                }
                return
            }

            guard let spaces = provider.getSpacesWithWindows() else {
                DispatchQueue.main.async {
                    self.refreshProvider(force: true)
                }
                return
            }

            let sortedSpaces = spaces.sorted { $0.id < $1.id }
            DispatchQueue.main.async {
                let changed = sortedSpaces != self.spaces
                if changed {
                    self.spaces = sortedSpaces
                }
                if let t = triggerTime {
                    let latencyMs = (CFAbsoluteTimeGetCurrent() - t) * 1000
                    Self.perfLog.notice("[\(source, privacy: .public)] UI updated in \(String(format: "%.1f", latencyMs), privacy: .public)ms (changed: \(changed, privacy: .public))")
                }
            }
        }
    }

    func forceRefresh() {
        refreshProvider(force: true)
        loadSpaces()
    }

    func switchToSpace(_ space: AnySpace, needWindowFocus: Bool = false) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.refreshProvider(force: false)
            self.provider?.focusSpace(
                spaceId: space.id, needWindowFocus: needWindowFocus)
        }
    }

    func switchToWindow(_ window: AnyWindow) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.refreshProvider(force: false)
            self.provider?.focusWindow(windowId: String(window.id))
        }
    }

    private func refreshProvider(force: Bool) {
        let nextKind = detectProviderKind()
        guard force || nextKind != currentProviderKind else {
            return
        }

        currentProviderKind = nextKind
        provider = switch nextKind {
        case .yabai:
            AnySpacesProvider(YabaiSpacesProvider())
        case .aerospace:
            AnySpacesProvider(AerospaceSpacesProvider())
        case .none:
            nil
        }
    }

    private func detectProviderKind() -> ProviderKind? {
        let runningApps = Set(
            NSWorkspace.shared.runningApplications.compactMap {
                $0.localizedName?.lowercased()
            }
        )

        if runningApps.contains("yabai") {
            return .yabai
        }

        if runningApps.contains("aerospace") {
            return .aerospace
        }

        return nil
    }
}

class IconCache {
    static let shared = IconCache()
    private let cache = NSCache<NSString, NSImage>()
    private init() {}
    func icon(for appName: String) -> NSImage? {
        if let cached = cache.object(forKey: appName as NSString) {
            return cached
        }
        let workspace = NSWorkspace.shared
        if let app = workspace.runningApplications.first(where: {
            $0.localizedName == appName
        }),
            let bundleURL = app.bundleURL
        {
            let icon = workspace.icon(forFile: bundleURL.path)
            cache.setObject(icon, forKey: appName as NSString)
            return icon
        }
        return nil
    }
}
