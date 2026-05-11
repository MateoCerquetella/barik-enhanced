import AppKit
import Combine
import Foundation

class SpacesViewModel: ObservableObject, ConditionallyActivatableWidget {
    static let shared = SpacesViewModel()
    @Published var spaces: [AnySpace] = []
    private var timer: Timer?
    private var recoveryTimer: Timer?
    private var provider: AnySpacesProvider?
    private var currentProviderKind: ProviderKind?
    private var currentInterval: TimeInterval = 5.0
    let widgetId = "default.spaces"
    
    private var isActive = false

    private enum ProviderKind: Equatable {
        case yabai
        case aerospace
    }

    private init() {
        setupNotifications()
        refreshProvider(force: true)
        // For now, always activate to ensure widgets work
        activate()
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

    private func loadSpaces() {
        refreshProvider(force: false)

        DispatchQueue.global(qos: .background).async { [weak self] in
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
                if sortedSpaces != self.spaces {
                    self.spaces = sortedSpaces
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
