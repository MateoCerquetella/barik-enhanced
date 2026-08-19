import Combine
import Foundation

final class WireGuardManager: ObservableObject {
    static let shared = WireGuardManager()

    @Published private(set) var snapshot: WireGuardSnapshot = .initial
    @Published private(set) var isRefreshing = false

    private let checker: any WireGuardHealthChecking
    private let workerQueue: DispatchQueue
    private var activeClients: [UUID: WireGuardWidgetSettings] = [:]
    private var activeClientOrder: [UUID] = []
    private var timer: Timer?
    private var refreshPending = false

    init(
        checker: any WireGuardHealthChecking = WireGuardHealthChecker(),
        workerQueue: DispatchQueue = DispatchQueue(
            label: "com.mateocerquetella.BarikEnhanced.wireguard",
            qos: .utility)
    ) {
        self.checker = checker
        self.workerQueue = workerQueue
    }

    deinit {
        stopMonitoring()
    }

    var isMonitoring: Bool {
        timer != nil
    }

    var activeClientCount: Int {
        activeClients.count
    }

    func activate(clientID: UUID, settings: WireGuardWidgetSettings) {
        let previousSettings = currentSettings
        if activeClients[clientID] == nil {
            activeClientOrder.append(clientID)
        }
        activeClients[clientID] = settings
        applyActiveConfigurationChange(from: previousSettings)
    }

    func update(clientID: UUID, settings: WireGuardWidgetSettings) {
        guard activeClients[clientID] != nil else { return }

        let previousSettings = currentSettings
        activeClients[clientID] = settings
        applyActiveConfigurationChange(from: previousSettings)
    }

    func deactivate(clientID: UUID) {
        let previousSettings = currentSettings
        guard activeClients.removeValue(forKey: clientID) != nil else {
            return
        }
        activeClientOrder.removeAll(where: { $0 == clientID })
        applyActiveConfigurationChange(from: previousSettings)
    }

    func refresh() {
        guard let settings = currentSettings else { return }
        guard !isRefreshing else {
            refreshPending = true
            return
        }

        isRefreshing = true
        let checker = self.checker
        workerQueue.async { [weak self] in
            let result = checker.check(settings: settings)
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

    func healthStatus(
        for settings: WireGuardWidgetSettings
    ) -> WireGuardHealthStatus {
        WireGuardHealthStatus.resolve(
            tunnelState: snapshot.tunnelState,
            gatewayProbe: snapshot.gatewayProbe,
            isChecking: snapshot.checkedAt == nil
                || snapshot.settings != settings)
    }

    private var currentSettings: WireGuardWidgetSettings? {
        activeClientOrder.last.flatMap { activeClients[$0] }
    }

    private func applyActiveConfigurationChange(
        from previousSettings: WireGuardWidgetSettings?
    ) {
        guard let settings = currentSettings else {
            stopMonitoring()
            refreshPending = false
            return
        }

        guard previousSettings != settings || timer == nil else {
            return
        }

        startMonitoring(interval: TimeInterval(settings.refreshInterval))
        refresh()
    }

    private func startMonitoring(interval: TimeInterval) {
        stopMonitoring()

        let timer = Timer(timeInterval: interval, repeats: true) {
            [weak self] _ in
            self?.refresh()
        }
        timer.tolerance = min(5, interval / 10)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}
