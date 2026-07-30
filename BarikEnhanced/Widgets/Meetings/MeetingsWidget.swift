import SwiftUI

struct MeetingsWidget: View {
    @EnvironmentObject private var configProvider: ConfigProvider
    @ObservedObject private var manager: MeetingsManager

    @State private var currentTime = Date()
    @State private var rect = CGRect.zero
    @State private var activationID = UUID()

    private let joinCoordinator: MeetingJoinCoordinator
    private let clock = Timer.publish(every: 15, on: .main, in: .common)
        .autoconnect()

    init(
        manager: MeetingsManager = .shared,
        joinCoordinator: MeetingJoinCoordinator = MeetingJoinCoordinator()
    ) {
        self.manager = manager
        self.joinCoordinator = joinCoordinator
    }

    private var maximumTitleLength: Int {
        MeetingsWidgetSettings(config: configProvider.config)
            .titleMaximumLength
    }

    var body: some View {
        MeetingsWidgetContent(
            meeting: manager.selectedMeeting,
            authorizationState: manager.authorizationState,
            currentTime: currentTime,
            maximumTitleLength: maximumTitleLength,
            onOpenSchedule: showSchedule)
            .foregroundStyle(.foregroundOutside)
            .shadow(color: .foregroundShadowOutside, radius: 3)
            .experimentalConfiguration(cornerRadius: 15)
            .frame(maxHeight: .infinity)
            .background(.black.opacity(0.001))
            .contentShape(Rectangle())
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            rect = geometry.frame(in: .global)
                        }
                        .onChange(of: geometry.frame(in: .global)) {
                            _, newRect in
                            rect = newRect
                        }
                })
            .onReceive(clock) { date in
                currentTime = date
            }
            .onAppear {
                manager.activate(clientID: activationID)
            }
            .onDisappear {
                manager.deactivate(clientID: activationID)
            }
    }

    private func showSchedule() {
        MenuBarPopup.show(
            rect: rect,
            id: "meetings-\(activationID.uuidString)"
        ) {
            MeetingsPopup(
                manager: manager,
                joinCoordinator: joinCoordinator)
        }
    }
}

struct MeetingsWidgetContent: View {
    let meeting: MeetingEvent?
    let authorizationState: MeetingsAuthorizationState
    let currentTime: Date
    let maximumTitleLength: Int
    let onOpenSchedule: () -> Void

    var body: some View {
        Button(action: onOpenSchedule) {
            primaryLabel
        }
        .buttonStyle(.plain)
        .accessibilityLabel(primaryAccessibilityLabel)
        .help("Open meeting schedule")
        .font(.headline)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var primaryLabel: some View {
        if let meeting, let link = meeting.meetingLink {
            HStack(spacing: 6) {
                Image(systemName: link.service.symbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(link.service.tintColor)

                Text(truncatedTitle(for: meeting))
                    .fontWeight(.semibold)

                Text(statusText(for: meeting))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        } else {
            HStack(spacing: 6) {
                Image(systemName: emptyStateSymbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(emptyStateTitle)
                    .fontWeight(.semibold)
            }
            .contentShape(Rectangle())
        }
    }

    private var primaryAccessibilityLabel: String {
        if let meeting {
            return "Open meeting schedule. \(displayTitle(for: meeting)), \(statusText(for: meeting))"
        }
        return "\(emptyStateTitle). Open meeting schedule"
    }

    private var emptyStateSymbol: String {
        switch authorizationState {
        case .denied, .restricted:
            return "calendar.badge.exclamationmark"
        case .requesting:
            return "calendar.badge.clock"
        case .notDetermined, .granted:
            return "calendar"
        }
    }

    private var emptyStateTitle: String {
        switch authorizationState {
        case .denied, .restricted:
            return String(localized: "Calendar access")
        case .requesting:
            return String(localized: "Loading meetings")
        case .notDetermined, .granted:
            return String(localized: "No meetings")
        }
    }

    private func displayTitle(for meeting: MeetingEvent) -> String {
        meeting.title.isEmpty
            ? String(localized: "Untitled event")
            : meeting.title
    }

    private func truncatedTitle(for meeting: MeetingEvent) -> String {
        MeetingsWidgetSettings(titleMaximumLength: maximumTitleLength)
            .truncatedTitle(displayTitle(for: meeting))
    }

    private func statusText(for meeting: MeetingEvent) -> String {
        if meeting.isActive(at: currentTime) {
            return String(localized: "Now")
        }

        let interval = meeting.startDate.timeIntervalSince(currentTime)
        if interval > 0, interval <= 60 * 60 {
            return Self.relativeFormatter.localizedString(
                for: meeting.startDate,
                relativeTo: currentTime)
        }

        if Calendar.autoupdatingCurrent.isDateInToday(meeting.startDate) {
            return Self.timeFormatter.string(from: meeting.startDate)
        }

        return Self.dayAndTimeFormatter.string(from: meeting.startDate)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("j:mm")
        return formatter
    }()

    private static let dayAndTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEE j:mm")
        return formatter
    }()
}

extension MeetingService {
    var tintColor: Color {
        switch self {
        case .googleMeet:
            return .green
        case .zoom:
            return .blue
        case .microsoftTeams:
            return .purple
        }
    }
}

struct MeetingsWidgetContent_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MeetingsWidgetContent(
                meeting: previewMeeting,
                authorizationState: .granted,
                currentTime: Date(),
                maximumTitleLength: 32,
                onOpenSchedule: {})
                .previewDisplayName("Upcoming meeting")

            MeetingsWidgetContent(
                meeting: nil,
                authorizationState: .denied,
                currentTime: Date(),
                maximumTitleLength: 32,
                onOpenSchedule: {})
                .previewDisplayName("Permission denied")
        }
        .padding()
        .background(.black)
        .foregroundStyle(.white)
        .previewLayout(.sizeThatFits)
    }

    private static var previewMeeting: MeetingEvent {
        MeetingEvent(
            id: "preview",
            title: "Weekly design review",
            startDate: Date().addingTimeInterval(20 * 60),
            endDate: Date().addingTimeInterval(80 * 60),
            isAllDay: false,
            isCancelled: false,
            meetingLink: MeetingLink(
                url: URL(string: "https://meet.google.com/abc-defg-hij")!,
                service: .googleMeet))
    }
}
