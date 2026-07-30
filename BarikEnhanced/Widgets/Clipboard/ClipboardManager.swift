import Combine
import Foundation

final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published private(set) var entries: [ClipboardHistoryEntry] = []

    private let pasteboard: any ClipboardPasteboard
    private let pollingInterval: TimeInterval
    private var activeClients: [UUID: Int] = [:]
    private var lastChangeCount: Int?
    private var timer: Timer?

    init(
        pasteboard: any ClipboardPasteboard = SystemClipboardPasteboard(),
        pollingInterval: TimeInterval = 1
    ) {
        self.pasteboard = pasteboard
        self.pollingInterval = pollingInterval
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

    func activate(clientID: UUID, maximumItems: Int) {
        let wasInactive = activeClients.isEmpty
        activeClients[clientID] = ClipboardWidgetSettings
            .clampedMaximumItems(maximumItems)
        trimHistoryIfNeeded()

        guard wasInactive else { return }
        startMonitoring()
        checkForChanges()
    }

    func update(clientID: UUID, maximumItems: Int) {
        guard activeClients[clientID] != nil else { return }
        activeClients[clientID] = ClipboardWidgetSettings
            .clampedMaximumItems(maximumItems)
        trimHistoryIfNeeded()
    }

    func deactivate(clientID: UUID) {
        guard activeClients.removeValue(forKey: clientID) != nil else {
            return
        }

        if activeClients.isEmpty {
            stopMonitoring()
        } else {
            trimHistoryIfNeeded()
        }
    }

    func checkForChanges() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }

        lastChangeCount = changeCount
        guard let text = pasteboard.plainText else { return }
        record(text)
    }

    func copy(_ entry: ClipboardHistoryEntry) {
        pasteboard.write(entry.text)
        lastChangeCount = pasteboard.changeCount
        record(entry.text)
    }

    func clearHistory() {
        entries.removeAll()
    }

    private func startMonitoring() {
        guard timer == nil else { return }

        let timer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkForChanges()
        }
        timer.tolerance = min(0.25, pollingInterval / 4)
        self.timer = timer
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func record(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard entries.first?.text != text else { return }

        entries.insert(ClipboardHistoryEntry(text: text), at: 0)
        trimHistoryIfNeeded()
    }

    private func trimHistoryIfNeeded() {
        guard let maximumItems = activeClients.values.max() else { return }
        if entries.count > maximumItems {
            entries.removeLast(entries.count - maximumItems)
        }
    }
}
