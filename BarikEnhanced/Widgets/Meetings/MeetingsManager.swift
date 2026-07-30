import Combine
import EventKit
import Foundation

final class MeetingsManager: ObservableObject {
    static let shared = MeetingsManager()

    @Published private(set) var authorizationState: MeetingsAuthorizationState
    @Published private(set) var selectedMeeting: MeetingEvent?
    @Published private(set) var todaysEvents: [MeetingEvent] = []
    @Published private(set) var tomorrowsEvents: [MeetingEvent] = []

    private let eventStore: EKEventStore
    private let eventQueue = DispatchQueue(
        label: "com.mateocerquetella.BarikEnhanced.meetings-eventkit",
        qos: .utility)
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var activeClients: Set<UUID> = []
    private var authorizationRequestInFlight = false

    private init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
        authorizationState = Self.authorizationState(
            for: EKEventStore.authorizationStatus(for: .event))
    }

    deinit {
        stopMonitoring()
    }

    func activate(clientID: UUID) {
        let inserted = activeClients.insert(clientID).inserted
        guard inserted, activeClients.count == 1 else { return }

        startMonitoring()
        updateAuthorizationAndRefresh()
    }

    func deactivate(clientID: UUID) {
        activeClients.remove(clientID)
        if activeClients.isEmpty {
            stopMonitoring()
        }
    }

    func refresh() {
        updateAuthorizationAndRefresh()
    }

    private func startMonitoring() {
        guard timer == nil else { return }

        let timer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            self?.updateAuthorizationAndRefresh()
        }
        timer.tolerance = 5
        self.timer = timer

        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: .EKEventStoreChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateAuthorizationAndRefresh()
            })
        observers.append(
            center.addObserver(
                forName: .NSCalendarDayChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.updateAuthorizationAndRefresh()
            })
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil

        let center = NotificationCenter.default
        observers.forEach(center.removeObserver)
        observers.removeAll()
    }

    private func updateAuthorizationAndRefresh() {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .fullAccess, .authorized:
            authorizationState = .granted
            fetchEvents()
        case .notDetermined:
            requestAuthorizationIfNeeded()
        case .denied:
            publishUnavailable(state: .denied)
        case .restricted, .writeOnly:
            publishUnavailable(state: .restricted)
        @unknown default:
            publishUnavailable(state: .restricted)
        }
    }

    private func requestAuthorizationIfNeeded() {
        guard !authorizationRequestInFlight else { return }

        authorizationRequestInFlight = true
        authorizationState = .requesting

        eventQueue.async { [weak self] in
            guard let self else { return }
            self.eventStore.requestFullAccessToEvents { [weak self] _, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.authorizationRequestInFlight = false
                    self.updateAuthorizationAndRefresh()
                }
            }
        }
    }

    private func fetchEvents() {
        eventQueue.async { [weak self] in
            guard let self else { return }

            let now = Date()
            let calendar = Calendar.autoupdatingCurrent
            let startOfToday = calendar.startOfDay(for: now)

            guard
                let startOfTomorrow = calendar.date(
                    byAdding: .day, value: 1, to: startOfToday),
                let startOfDayAfterTomorrow = calendar.date(
                    byAdding: .day, value: 2, to: startOfToday)
            else {
                return
            }

            let calendars = self.eventStore.calendars(for: .event)
            let predicate = self.eventStore.predicateForEvents(
                withStart: startOfToday,
                end: startOfDayAfterTomorrow,
                calendars: calendars)
            let snapshots = self.eventStore.events(matching: predicate).map {
                event in
                Self.snapshot(from: event)
            }

            let remaining = snapshots.filter {
                !$0.isCancelled
                    && $0.endDate > now
                    && $0.startDate < startOfDayAfterTomorrow
            }
            let today = MeetingSelector.chronological(
                remaining.filter {
                    calendar.isDate($0.startDate, inSameDayAs: startOfToday)
                })
            let tomorrow = MeetingSelector.chronological(
                remaining.filter {
                    calendar.isDate($0.startDate, inSameDayAs: startOfTomorrow)
                })
            let horizon = startOfDayAfterTomorrow.addingTimeInterval(-0.001)
            let selected = MeetingSelector.currentOrNext(
                from: snapshots,
                now: now,
                horizon: horizon)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.authorizationState = .granted
                if self.selectedMeeting != selected {
                    self.selectedMeeting = selected
                }
                if self.todaysEvents != today {
                    self.todaysEvents = today
                }
                if self.tomorrowsEvents != tomorrow {
                    self.tomorrowsEvents = tomorrow
                }
            }
        }
    }

    private func publishUnavailable(state: MeetingsAuthorizationState) {
        authorizationState = state
        selectedMeeting = nil
        todaysEvents = []
        tomorrowsEvents = []
    }

    private static func snapshot(from event: EKEvent) -> MeetingEvent {
        let title = event.title?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let identifier = event.eventIdentifier ?? event.calendarItemIdentifier

        return MeetingEvent(
            id: identifier,
            title: title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            isCancelled: event.status == .canceled,
            meetingLink: MeetingLinkDetector.detect(
                structuredURL: event.url,
                location: event.location,
                notes: event.notes))
    }

    private static func authorizationState(
        for status: EKAuthorizationStatus
    ) -> MeetingsAuthorizationState {
        switch status {
        case .fullAccess, .authorized:
            return .granted
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .restricted, .writeOnly:
            return .restricted
        @unknown default:
            return .restricted
        }
    }
}
