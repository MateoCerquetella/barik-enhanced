import AppKit
import SwiftUI
import XCTest
@testable import BarikEnhanced

@MainActor
final class SystemMonitorRenderingTests: XCTestCase {
    func testProcessSamplerReturnsSaneRows() {
        let processes = ProcessSampler.sample()

        XCTAssertFalse(processes.isEmpty)
        XCTAssertTrue(processes.contains { $0.memoryBytes > 0 })
        XCTAssertTrue(processes.allSatisfy { $0.id > 1 && !$0.name.isEmpty })
    }

    func testTopProcessSectionRendersBothMetrics() throws {
        let processes = [
            TopProcess(
                id: 501,
                name: "Google Chrome Helper",
                cpuPercent: 42.5,
                memoryBytes: 1_610_612_736),
            TopProcess(
                id: 733,
                name: "WindowServer",
                cpuPercent: 12.0,
                memoryBytes: 402_653_184),
            TopProcess(
                id: 918,
                name: "opencode",
                cpuPercent: 3.4,
                memoryBytes: 998_244_352),
        ]

        try render(
            TopProcessSection(
                cpuProcesses: processes,
                ramProcesses: processes,
                onKill: { _ in })
                .padding(12)
                .frame(width: 320)
                .background(.black),
            named: "barik-top-processes")
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
