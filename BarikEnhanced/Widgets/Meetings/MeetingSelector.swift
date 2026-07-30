import Foundation

struct MeetingSelector {
    static func currentOrNext(
        from events: [MeetingEvent],
        now: Date,
        horizon: Date
    ) -> MeetingEvent? {
        let eligible = events
            .filter { event in
                !event.isAllDay
                    && !event.isCancelled
                    && event.meetingLink != nil
                    && event.endDate > now
                    && event.startDate <= horizon
            }
            .sorted(by: stableEventOrder)

        if let active = eligible.first(where: { $0.isActive(at: now) }) {
            return active
        }

        return eligible.first(where: { $0.startDate > now })
    }

    static func chronological(_ events: [MeetingEvent]) -> [MeetingEvent] {
        events.sorted(by: stableEventOrder)
    }

    private static func stableEventOrder(
        _ lhs: MeetingEvent,
        _ rhs: MeetingEvent
    ) -> Bool {
        if lhs.startDate != rhs.startDate {
            return lhs.startDate < rhs.startDate
        }
        if lhs.endDate != rhs.endDate {
            return lhs.endDate < rhs.endDate
        }
        return lhs.id < rhs.id
    }
}
