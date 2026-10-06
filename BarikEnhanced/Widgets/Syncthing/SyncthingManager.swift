import Combine
import Foundation

final class SyncthingManager: ObservableObject {
    static let shared = SyncthingManager()

    @Published private(set) var snapshot: SyncthingSnapshot = .initial
    @Published private(set) var isRefreshing = false

    private let fetcher: any SyncthingSnapshotFetching
    private let workerQueue: DispatchQueue
    private var activeClients: [UUID: SyncthingWidgetSettings] = [:]
    private var activeClientOrder: [UUID] = []
    private var timer: Timer?
    private var refreshPending = false

    init(
        fetcher: any SyncthingSnapshotFetching = SyncthingAPIClient(),
        workerQueue: DispatchQueue = DispatchQueue(
            label: "com.mateocerquetella.BarikEnhanced.syncthing",
            qos: .utility)
    ) {
        self.fetcher = fetcher
        self.workerQueue = workerQueue
    }

    deinit {
        timer?.invalidate()
    }

    func activate(clientID: UUID, settings: SyncthingWidgetSettings) {
        let previous = currentSettings
        if activeClients[clientID] == nil {
            activeClientOrder.append(clientID)
        }
        activeClients[clientID] = settings
        applyConfigurationChange(from: previous)
    }

    func update(clientID: UUID, settings: SyncthingWidgetSettings) {
        guard activeClients[clientID] != nil else { return }
        let previous = currentSettings
        activeClients[clientID] = settings
        applyConfigurationChange(from: previous)
    }

    func deactivate(clientID: UUID) {
        let previous = currentSettings
        guard activeClients.removeValue(forKey: clientID) != nil else {
            return
        }
        activeClientOrder.removeAll { $0 == clientID }
        applyConfigurationChange(from: previous)
    }

    func refresh() {
        guard let settings = currentSettings else { return }
        guard !isRefreshing else {
            refreshPending = true
            return
        }

        isRefreshing = true
        let fetcher = self.fetcher
        workerQueue.async { [weak self] in
            let result = fetcher.fetch(settings: settings)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.currentSettings == settings {
                    self.snapshot = result
                }
                self.isRefreshing = false

                let shouldRefreshAgain = self.refreshPending
                    || (self.currentSettings != nil
                        && self.currentSettings != settings)
                self.refreshPending = false
                if shouldRefreshAgain {
                    self.refresh()
                }
            }
        }
    }

    func state(for settings: SyncthingWidgetSettings) -> SyncthingState {
        snapshot.settings == settings ? snapshot.state : .checking
    }

    private var currentSettings: SyncthingWidgetSettings? {
        activeClientOrder.last.flatMap { activeClients[$0] }
    }

    private func applyConfigurationChange(
        from previous: SyncthingWidgetSettings?
    ) {
        guard let settings = currentSettings else {
            timer?.invalidate()
            timer = nil
            refreshPending = false
            return
        }
        guard previous != settings || timer == nil else { return }

        timer?.invalidate()
        let timer = Timer(
            timeInterval: TimeInterval(settings.refreshInterval),
            repeats: true
        ) { [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = min(
            3, TimeInterval(settings.refreshInterval) / 10)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        refresh()
    }
}
