import SwiftUI

struct MeetingsPopup: View {
    @ObservedObject var manager: MeetingsManager
    let joinCoordinator: MeetingJoinCoordinator

    var body: some View {
        MeetingsPopupContent(
            authorizationState: manager.authorizationState,
            todaysEvents: manager.todaysEvents,
            tomorrowsEvents: manager.tomorrowsEvents,
            onJoin: { link in
                joinCoordinator.join(link)
            })
            .onAppear {
                manager.refresh()
            }
    }
}

struct MeetingsPopupContent: View {
    let authorizationState: MeetingsAuthorizationState
    let todaysEvents: [MeetingEvent]
    let tomorrowsEvents: [MeetingEvent]
    let onJoin: (MeetingLink) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(.blue)
                Text("Meetings")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            content
        }
        .frame(width: 340)
        .padding(24)
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var content: some View {
        switch authorizationState {
        case .notDetermined, .requesting:
            MeetingsPopupState(
                symbol: "calendar.badge.clock",
                title: String(localized: "Requesting calendar access"),
                message: String(
                    localized:
                        "Barik Enhanced needs Calendar access to find your meetings."),
                showsProgress: true)
        case .denied:
            MeetingsPopupState(
                symbol: "calendar.badge.exclamationmark",
                title: String(localized: "Calendar access is off"),
                message: String(
                    localized:
                        "Allow Barik Enhanced to read Calendar in System Settings."))
        case .restricted:
            MeetingsPopupState(
                symbol: "calendar.badge.exclamationmark",
                title: String(localized: "Calendar access is restricted"),
                message: String(
                    localized:
                        "This Mac does not currently allow calendar access."))
        case .granted:
            if todaysEvents.isEmpty && tomorrowsEvents.isEmpty {
                MeetingsPopupState(
                    symbol: "calendar",
                    title: String(localized: "No events today or tomorrow"),
                    message: String(
                        localized:
                            "New calendar events will appear here automatically."))
            } else {
                schedule
            }
        }
    }

    @ViewBuilder
    private var schedule: some View {
        if estimatedScheduleHeight > 420 {
            ScrollView {
                scheduleSections
            }
            .frame(height: 420)
        } else {
            scheduleSections
        }
    }

    private var scheduleSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            MeetingsEventSection(
                title: String(localized: "Today"),
                events: todaysEvents,
                onJoin: onJoin)
            MeetingsEventSection(
                title: String(localized: "Tomorrow"),
                events: tomorrowsEvents,
                onJoin: onJoin)
        }
    }

    private var estimatedScheduleHeight: CGFloat {
        let eventCount = todaysEvents.count + tomorrowsEvents.count
        let sectionCount = (todaysEvents.isEmpty ? 0 : 1)
            + (tomorrowsEvents.isEmpty ? 0 : 1)
        return CGFloat(eventCount * 60 + sectionCount * 28)
    }
}

private struct MeetingsPopupState: View {
    let symbol: String
    let title: String
    let message: String
    var showsProgress = false

    var body: some View {
        VStack(spacing: 10) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

private struct MeetingsEventSection: View {
    let title: String
    let events: [MeetingEvent]
    let onJoin: (MeetingLink) -> Void

    var body: some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(events) { event in
                    MeetingsEventRow(event: event, onJoin: onJoin)
                }
            }
        }
    }
}

private struct MeetingsEventRow: View {
    let event: MeetingEvent
    let onJoin: (MeetingLink) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: event.meetingLink?.service.symbolName ?? "calendar")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(event.meetingLink?.service.tintColor ?? .gray)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title.isEmpty
                    ? String(localized: "Untitled event")
                    : event.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(timeText)
                    .font(.caption)
                    .fontWeight(.regular)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let link = event.meetingLink {
                Button {
                    onJoin(link)
                } label: {
                    Text("Join")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(link.service.tintColor)
                .accessibilityLabel(
                    "Join \(event.title.isEmpty ? String(localized: "Untitled event") : event.title)")
            } else {
                Text("No link")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var timeText: String {
        if event.isAllDay {
            return String(localized: "All day")
        }
        return Self.intervalFormatter.string(
            from: event.startDate,
            to: event.endDate)
    }

    private static let intervalFormatter: DateIntervalFormatter = {
        let formatter = DateIntervalFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

struct MeetingsPopupContent_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MeetingsPopupContent(
                authorizationState: .granted,
                todaysEvents: previewEvents,
                tomorrowsEvents: [],
                onJoin: { _ in })
                .previewDisplayName("Mixed schedule")

            MeetingsPopupContent(
                authorizationState: .denied,
                todaysEvents: [],
                tomorrowsEvents: [],
                onJoin: { _ in })
                .previewDisplayName("Permission denied")
        }
        .background(.black)
        .previewLayout(.sizeThatFits)
    }

    private static var previewEvents: [MeetingEvent] {
        [
            MeetingEvent(
                id: "joinable",
                title: "Weekly design review",
                startDate: Date().addingTimeInterval(20 * 60),
                endDate: Date().addingTimeInterval(80 * 60),
                isAllDay: false,
                isCancelled: false,
                meetingLink: MeetingLink(
                    url: URL(
                        string: "https://meet.google.com/abc-defg-hij")!,
                    service: .googleMeet)),
            MeetingEvent(
                id: "linkless",
                title: "Focus time",
                startDate: Date().addingTimeInterval(2 * 60 * 60),
                endDate: Date().addingTimeInterval(3 * 60 * 60),
                isAllDay: false,
                isCancelled: false,
                meetingLink: nil),
        ]
    }
}
