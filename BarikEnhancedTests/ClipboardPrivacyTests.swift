import Foundation
import XCTest

final class ClipboardPrivacyTests: XCTestCase {
    func testProductionClipboardSourcesContainNoPersistenceNetworkOrLogging()
        throws
    {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceDirectory = repositoryRoot
            .appendingPathComponent("BarikEnhanced/Widgets/Clipboard")
        let sources = try FileManager.default.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        let forbiddenAPIs = [
            "URLSession",
            "UserDefaults",
            "FileHandle",
            "FileManager",
            "NSUbiquitousKeyValueStore",
            "NWConnection",
            "dataTask(",
            "write(to:",
            "print(",
            "Logger(",
        ]

        XCTAssertFalse(sources.isEmpty)
        for source in sources {
            let contents = try String(contentsOf: source, encoding: .utf8)
            for forbiddenAPI in forbiddenAPIs {
                XCTAssertFalse(
                    contents.contains(forbiddenAPI),
                    "\(source.lastPathComponent) unexpectedly uses \(forbiddenAPI)")
            }
        }
    }
}
