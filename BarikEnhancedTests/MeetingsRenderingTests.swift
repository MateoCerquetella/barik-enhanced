import AppKit
import SwiftUI
import XCTest
@testable import BarikEnhanced

@MainActor
final class MeetingsRenderingTests: XCTestCase {
    func testSafeMeetingAndFallbackFixturesRender() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let joinable = MeetingEvent(
            id: "joinable",
            title: "Weekly design review with a deliberately long title",
            startDate: now.addingTimeInterval(20 * 60),
            endDate: now.addingTimeInterval(80 * 60),
            isAllDay: false,
            isCancelled: false,
            meetingLink: MeetingLink(
                url: URL(string: "https://meet.google.com/abc-defg-hij")!,
                service: .googleMeet))
        let linkless = MeetingEvent(
            id: "linkless",
            title: "Focus time",
            startDate: now.addingTimeInterval(2 * 60 * 60),
            endDate: now.addingTimeInterval(3 * 60 * 60),
            isAllDay: false,
            isCancelled: false,
            meetingLink: nil)
        let tomorrow = MeetingEvent(
            id: "tomorrow",
            title: "Customer check-in",
            startDate: now.addingTimeInterval(10 * 60 * 60),
            endDate: now.addingTimeInterval(11 * 60 * 60),
            isAllDay: false,
            isCancelled: false,
            meetingLink: MeetingLink(
                url: URL(string: "https://zoom.us/j/987654321")!,
                service: .zoom))
        let active = MeetingEvent(
            id: "active",
            title: "Weekly design review",
            startDate: now.addingTimeInterval(-10 * 60),
            endDate: now.addingTimeInterval(20 * 60),
            isAllDay: false,
            isCancelled: false,
            meetingLink: joinable.meetingLink)

        try render(
            MeetingsWidgetContent(
                meeting: joinable,
                authorizationState: .granted,
                currentTime: now,
                maximumTitleLength: 24,
                onOpenSchedule: {})
                .padding(14)
                .foregroundStyle(.white)
                .background(.black),
            named: "barik-meetings-widget")

        try render(
            MeetingsWidgetContent(
                meeting: active,
                authorizationState: .granted,
                currentTime: now,
                maximumTitleLength: 24,
                onOpenSchedule: {})
                .padding(14)
                .foregroundStyle(.white)
                .background(.black),
            named: "barik-meetings-active")

        try render(
            MeetingsPopupContent(
                authorizationState: .granted,
                todaysEvents: [joinable, linkless],
                tomorrowsEvents: [tomorrow],
                onJoin: { _ in })
                .background(.black),
            named: "barik-meetings-popup")

        try render(
            MeetingsPopupContent(
                authorizationState: .denied,
                todaysEvents: [],
                tomorrowsEvents: [],
                onJoin: { _ in })
                .background(.black),
            named: "barik-meetings-permission")

        try render(
            MeetingsPopupContent(
                authorizationState: .granted,
                todaysEvents: [],
                tomorrowsEvents: [],
                onJoin: { _ in })
                .background(.black),
            named: "barik-meetings-empty")
    }

    private func render<Content: View>(
        _ content: Content,
        named name: String
    ) throws {
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.nsImage)
        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        let pngData = try XCTUnwrap(
            bitmap.representation(using: .png, properties: [:]))
        let outputURL = URL(fileURLWithPath: "/tmp/\(name).png")

        try pngData.write(to: outputURL, options: .atomic)
        XCTAssertGreaterThan(pngData.count, 1_000)
        XCTAssertGreaterThan(image.size.width, 40)
        XCTAssertGreaterThan(image.size.height, 20)
    }
}
