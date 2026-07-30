import XCTest
@testable import BarikEnhanced

final class MeetingSelectorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    func testActiveMeetingWinsOverEarlierFutureMeeting() {
        let active = event(
            id: "active",
            start: now.addingTimeInterval(-15 * 60),
            end: now.addingTimeInterval(45 * 60))
        let future = event(
            id: "future",
            start: now.addingTimeInterval(5 * 60),
            end: now.addingTimeInterval(35 * 60))

        let selected = MeetingSelector.currentOrNext(
            from: [future, active],
            now: now,
            horizon: now.addingTimeInterval(48 * 60 * 60))

        XCTAssertEqual(selected?.id, "active")
    }

    func testEarliestUpcomingMeetingIsSelectedRegardlessOfInputOrder() {
        let later = event(
            id: "later",
            start: now.addingTimeInterval(60 * 60),
            end: now.addingTimeInterval(90 * 60))
        let earlier = event(
            id: "earlier",
            start: now.addingTimeInterval(10 * 60),
            end: now.addingTimeInterval(40 * 60))

        let selected = MeetingSelector.currentOrNext(
            from: [later, earlier],
            now: now,
            horizon: now.addingTimeInterval(48 * 60 * 60))

        XCTAssertEqual(selected?.id, "earlier")
    }

    func testSelectionExcludesIneligibleEvents() {
        let valid = event(
            id: "valid",
            start: now.addingTimeInterval(30 * 60),
            end: now.addingTimeInterval(60 * 60))
        let allDay = event(
            id: "all-day",
            start: now.addingTimeInterval(5 * 60),
            end: now.addingTimeInterval(2 * 60 * 60),
            isAllDay: true)
        let cancelled = event(
            id: "cancelled",
            start: now.addingTimeInterval(10 * 60),
            end: now.addingTimeInterval(40 * 60),
            isCancelled: true)
        let ended = event(
            id: "ended",
            start: now.addingTimeInterval(-60 * 60),
            end: now)
        let linkless = event(
            id: "linkless",
            start: now.addingTimeInterval(15 * 60),
            end: now.addingTimeInterval(45 * 60),
            hasLink: false)
        let beyondHorizon = event(
            id: "beyond",
            start: now.addingTimeInterval(49 * 60 * 60),
            end: now.addingTimeInterval(50 * 60 * 60))

        let selected = MeetingSelector.currentOrNext(
            from: [
                allDay, cancelled, ended, linkless, beyondHorizon, valid,
            ],
            now: now,
            horizon: now.addingTimeInterval(48 * 60 * 60))

        XCTAssertEqual(selected?.id, "valid")
    }

    func testBoundaryAtStartIsActiveAndBoundaryAtEndIsExcluded() {
        let endingNow = event(
            id: "ending-now",
            start: now.addingTimeInterval(-30 * 60),
            end: now)
        let startingNow = event(
            id: "starting-now",
            start: now,
            end: now.addingTimeInterval(30 * 60))

        let selected = MeetingSelector.currentOrNext(
            from: [endingNow, startingNow],
            now: now,
            horizon: now.addingTimeInterval(48 * 60 * 60))

        XCTAssertEqual(selected?.id, "starting-now")
    }

    func testMeetingStartingAtHorizonIsIncluded() {
        let horizon = now.addingTimeInterval(48 * 60 * 60)
        let atHorizon = event(
            id: "horizon",
            start: horizon,
            end: horizon.addingTimeInterval(30 * 60))

        let selected = MeetingSelector.currentOrNext(
            from: [atHorizon],
            now: now,
            horizon: horizon)

        XCTAssertEqual(selected?.id, "horizon")
    }

    func testSimultaneousMeetingsUseEndThenIdentifierForStableOrder() {
        let longest = event(
            id: "a",
            start: now.addingTimeInterval(10 * 60),
            end: now.addingTimeInterval(60 * 60))
        let sameEndLaterID = event(
            id: "z",
            start: now.addingTimeInterval(10 * 60),
            end: now.addingTimeInterval(40 * 60))
        let sameEndEarlierID = event(
            id: "b",
            start: now.addingTimeInterval(10 * 60),
            end: now.addingTimeInterval(40 * 60))

        XCTAssertEqual(
            MeetingSelector.chronological([
                longest, sameEndLaterID, sameEndEarlierID,
            ]).map(\.id),
            ["b", "z", "a"])
    }

    private func event(
        id: String,
        start: Date,
        end: Date,
        isAllDay: Bool = false,
        isCancelled: Bool = false,
        hasLink: Bool = true
    ) -> MeetingEvent {
        MeetingEvent(
            id: id,
            title: id,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            isCancelled: isCancelled,
            meetingLink: hasLink
                ? MeetingLink(
                    url: URL(
                        string: "https://meet.google.com/abc-defg-hij")!,
                    service: .googleMeet)
                : nil)
    }
}
