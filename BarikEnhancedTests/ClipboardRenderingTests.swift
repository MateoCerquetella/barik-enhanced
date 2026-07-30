import AppKit
import SwiftUI
import XCTest
@testable import BarikEnhanced

@MainActor
final class ClipboardRenderingTests: XCTestCase {
    func testPopulatedAndEmptyFixturesRender() throws {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let entries = [
            ClipboardHistoryEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                text: "npm run test && npm run build",
                copiedAt: now.addingTimeInterval(-45)),
            ClipboardHistoryEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                text: "A multiline note\nwith useful project context",
                copiedAt: now.addingTimeInterval(-240)),
        ]

        try render(
            ClipboardWidgetContent(
                entry: entries[0],
                previewMaximumLength: 24,
                onOpenHistory: {})
                .padding(14)
                .foregroundStyle(.white)
                .background(.black),
            named: "barik-clipboard-widget")

        try render(
            ClipboardWidgetContent(
                entry: nil,
                previewMaximumLength: 24,
                onOpenHistory: {})
                .padding(14)
                .foregroundStyle(.white)
                .background(.black),
            named: "barik-clipboard-widget-empty")

        try render(
            ClipboardPopupContent(
                entries: entries,
                currentTime: now,
                onCopy: { _ in },
                onClear: {})
                .background(.black),
            named: "barik-clipboard-popup")

        try render(
            ClipboardPopupContent(
                entries: [],
                currentTime: now,
                onCopy: { _ in },
                onClear: {})
                .background(.black),
            named: "barik-clipboard-popup-empty")
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
