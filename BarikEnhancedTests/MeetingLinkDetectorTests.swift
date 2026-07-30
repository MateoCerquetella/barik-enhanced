import XCTest
@testable import BarikEnhanced

final class MeetingLinkDetectorTests: XCTestCase {
    func testStructuredURLHasPriorityOverLocationAndNotes() throws {
        let link = MeetingLinkDetector.detect(
            structuredURL: try XCTUnwrap(
                URL(string: "https://us02web.zoom.us/j/123456789")),
            location: "https://meet.google.com/abc-defg-hij",
            notes:
                "https://teams.microsoft.com/l/meetup-join/19%3ameeting")

        XCTAssertEqual(link?.service, .zoom)
        XCTAssertEqual(link?.url.host, "us02web.zoom.us")
    }

    func testInvalidStructuredURLFallsBackToLocationBeforeNotes() throws {
        let link = MeetingLinkDetector.detect(
            structuredURL: try XCTUnwrap(
                URL(string: "https://example.com/not-a-meeting")),
            location: "Room 3 — https://meet.google.com/abc-defg-hij",
            notes: "https://us02web.zoom.us/j/987654321")

        XCTAssertEqual(link?.service, .googleMeet)
        XCTAssertEqual(link?.url.host, "meet.google.com")
    }

    func testSupportedMeetingShapesAreRecognized() throws {
        let cases: [(String, MeetingService)] = [
            ("https://meet.google.com/abc-defg-hij", .googleMeet),
            ("https://meet.google.com/lookup/team-sync", .googleMeet),
            ("https://zoom.us/j/123456789", .zoom),
            ("https://us02web.zoom.us/my/team-room", .zoom),
            ("https://zoom.us/wc/join/123456789", .zoom),
            (
                "https://teams.microsoft.com/l/meetup-join/19%3ameeting",
                .microsoftTeams
            ),
            ("https://teams.live.com/meet/123456789", .microsoftTeams),
        ]

        for (rawURL, expectedService) in cases {
            let url = try XCTUnwrap(URL(string: rawURL))
            XCTAssertEqual(
                MeetingLinkDetector.validatedLink(from: url)?.service,
                expectedService,
                rawURL)
        }
    }

    func testNotesDetectionHandlesSurroundingPunctuation() {
        let link = MeetingLinkDetector.detect(
            structuredURL: nil,
            location: nil,
            notes:
                "Join here (https://teams.live.com/meet/123456789). See you soon.")

        XCTAssertEqual(link?.service, .microsoftTeams)
        XCTAssertEqual(link?.url.host, "teams.live.com")
    }

    func testHostAndSchemeLookalikesAreRejected() throws {
        let rejected = [
            "http://meet.google.com/abc-defg-hij",
            "ftp://zoom.us/j/123456789",
            "https://meet.google.com.evil.example/abc-defg-hij",
            "https://evil.example/meet.google.com/abc-defg-hij",
            "https://fakezoom.us/j/123456789",
            "https://zoom.us.evil.example/j/123456789",
            "https://meet.google.com@evil.example/abc-defg-hij",
            "https://teams.microsoft.com.evil.example/l/meetup-join/id",
            "https://example.com/j/123456789",
        ]

        for rawURL in rejected {
            let url = try XCTUnwrap(URL(string: rawURL))
            XCTAssertNil(
                MeetingLinkDetector.validatedLink(from: url),
                rawURL)
        }
    }

    func testNonMeetingServicePagesAreRejected() throws {
        let rejected = [
            "https://meet.google.com/",
            "https://zoom.us/",
            "https://zoom.us/pricing",
            "https://teams.microsoft.com/",
            "https://teams.live.com/settings",
        ]

        for rawURL in rejected {
            let url = try XCTUnwrap(URL(string: rawURL))
            XCTAssertNil(
                MeetingLinkDetector.validatedLink(from: url),
                rawURL)
        }
    }

    func testUppercaseSchemeAndHostAreNormalized() throws {
        let url = try XCTUnwrap(
            URL(string: "HTTPS://MEET.GOOGLE.COM/abc-defg-hij"))

        XCTAssertEqual(
            MeetingLinkDetector.validatedLink(from: url)?.service,
            .googleMeet)
    }
}
