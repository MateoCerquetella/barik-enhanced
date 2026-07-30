import Foundation

struct MeetingLinkDetector {
    private static let textLinkDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue)

    static func detect(
        structuredURL: URL?,
        location: String?,
        notes: String?
    ) -> MeetingLink? {
        if let structuredURL,
            let link = validatedLink(from: structuredURL)
        {
            return link
        }

        if let link = firstValidatedLink(in: location) {
            return link
        }

        return firstValidatedLink(in: notes)
    }

    static func validatedLink(from url: URL) -> MeetingLink? {
        guard
            let components = URLComponents(
                url: url, resolvingAgainstBaseURL: false),
            components.scheme?.lowercased() == "https",
            components.user == nil,
            components.password == nil,
            components.port == nil || components.port == 443,
            let host = components.host?.lowercased(),
            !host.isEmpty,
            let canonicalURL = components.url
        else {
            return nil
        }

        let pathComponents = components.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { $0.lowercased() }

        if host == "meet.google.com",
            isGoogleMeetPath(pathComponents)
        {
            return MeetingLink(url: canonicalURL, service: .googleMeet)
        }

        if hostMatches(host, root: "zoom.us"),
            isZoomPath(pathComponents)
        {
            return MeetingLink(url: canonicalURL, service: .zoom)
        }

        if (hostMatches(host, root: "teams.microsoft.com")
            || hostMatches(host, root: "teams.live.com")),
            isTeamsPath(pathComponents)
        {
            return MeetingLink(url: canonicalURL, service: .microsoftTeams)
        }

        return nil
    }

    private static func firstValidatedLink(in text: String?) -> MeetingLink? {
        guard
            let text,
            !text.isEmpty,
            let textLinkDetector
        else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for match in textLinkDetector.matches(
            in: text, options: [], range: range)
        {
            guard let url = match.url else { continue }
            if let link = validatedLink(from: url) {
                return link
            }
        }

        return nil
    }

    private static func hostMatches(_ host: String, root: String) -> Bool {
        host == root || host.hasSuffix(".\(root)")
    }

    private static func isGoogleMeetPath(_ components: [String]) -> Bool {
        guard let first = components.first else { return false }
        if first == "lookup" {
            return components.count >= 2 && !components[1].isEmpty
        }
        return !first.isEmpty
    }

    private static func isZoomPath(_ components: [String]) -> Bool {
        guard let first = components.first else { return false }

        switch first {
        case "j", "my", "s", "w":
            return components.count >= 2 && !components[1].isEmpty
        case "wc":
            guard components.count >= 3 else { return false }
            return components[1] == "join" || components[1] == "j"
        default:
            return false
        }
    }

    private static func isTeamsPath(_ components: [String]) -> Bool {
        guard let first = components.first else { return false }

        if first == "meet" {
            return components.count >= 2 && !components[1].isEmpty
        }

        if first == "l", components.count >= 3 {
            return components[1] == "meetup-join"
                || components[1] == "meet"
        }

        return false
    }
}
