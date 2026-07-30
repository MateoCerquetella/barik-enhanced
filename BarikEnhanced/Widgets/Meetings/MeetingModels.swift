import Foundation

enum MeetingService: String, CaseIterable, Sendable {
    case googleMeet
    case zoom
    case microsoftTeams

    var displayName: String {
        switch self {
        case .googleMeet:
            return "Google Meet"
        case .zoom:
            return "Zoom"
        case .microsoftTeams:
            return "Microsoft Teams"
        }
    }

    var symbolName: String {
        switch self {
        case .googleMeet:
            return "video.fill"
        case .zoom:
            return "video.circle.fill"
        case .microsoftTeams:
            return "person.2.fill"
        }
    }
}

struct MeetingLink: Equatable, Sendable {
    let url: URL
    let service: MeetingService
}

struct MeetingEvent: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let isCancelled: Bool
    let meetingLink: MeetingLink?

    func isActive(at date: Date) -> Bool {
        startDate <= date && date < endDate
    }
}

enum MeetingsAuthorizationState: Equatable, Sendable {
    case notDetermined
    case requesting
    case granted
    case denied
    case restricted
}
