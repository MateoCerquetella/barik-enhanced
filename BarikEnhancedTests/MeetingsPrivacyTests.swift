import Foundation
import XCTest

final class MeetingsPrivacyTests: XCTestCase {
    func testProductionMeetingsSourcesContainNoNetworkOrPersistenceClient()
        throws
    {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceDirectory = repositoryRoot
            .appendingPathComponent("BarikEnhanced/Widgets/Meetings")
        let sources = try FileManager.default.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        let forbiddenAPIs = [
            "URLSession",
            "UserDefaults",
            "FileHandle",
            "NSUbiquitousKeyValueStore",
            "dataTask(",
            "write(to:",
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
