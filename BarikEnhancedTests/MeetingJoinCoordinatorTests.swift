import XCTest
@testable import BarikEnhanced

final class MeetingJoinCoordinatorTests: XCTestCase {
    func testJoinDelegatesExactlyOneValidatedURL() throws {
        let opener = RecordingMeetingURLOpener()
        let coordinator = MeetingJoinCoordinator(opener: opener)
        let link = try XCTUnwrap(
            MeetingLinkDetector.validatedLink(
                from: XCTUnwrap(
                    URL(string: "https://us02web.zoom.us/j/123456789"))))

        XCTAssertTrue(coordinator.join(link))
        XCTAssertEqual(
            opener.openedURLs,
            [URL(string: "https://us02web.zoom.us/j/123456789")!])
    }
}

private final class RecordingMeetingURLOpener: MeetingURLOpening {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return true
    }
}
