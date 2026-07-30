import XCTest
@testable import BarikEnhanced

final class ClipboardManagerTests: XCTestCase {
    func testMonitoringUsesOneTimerUntilLastClientDeactivates() {
        let pasteboard = RecordingClipboardPasteboard()
        let manager = ClipboardManager(
            pasteboard: pasteboard,
            pollingInterval: 60)
        let firstClient = UUID()
        let secondClient = UUID()

        manager.activate(clientID: firstClient, maximumItems: 5)
        XCTAssertTrue(manager.isMonitoring)
        XCTAssertEqual(manager.activeClientCount, 1)

        manager.activate(clientID: secondClient, maximumItems: 10)
        XCTAssertTrue(manager.isMonitoring)
        XCTAssertEqual(manager.activeClientCount, 2)

        manager.deactivate(clientID: firstClient)
        XCTAssertTrue(manager.isMonitoring)

        manager.deactivate(clientID: secondClient)
        XCTAssertFalse(manager.isMonitoring)
        XCTAssertEqual(manager.activeClientCount, 0)
    }

    func testCaptureIgnoresUnusableValuesDeduplicatesAndDropsOldest() {
        let pasteboard = RecordingClipboardPasteboard()
        let manager = ClipboardManager(
            pasteboard: pasteboard,
            pollingInterval: 60)
        let clientID = UUID()
        manager.activate(clientID: clientID, maximumItems: 2)
        defer { manager.deactivate(clientID: clientID) }

        pasteboard.replacePlainText("first")
        manager.checkForChanges()
        pasteboard.replacePlainText("first")
        manager.checkForChanges()
        pasteboard.replacePlainText("  \n\t  ")
        manager.checkForChanges()
        pasteboard.replacePlainText(nil)
        manager.checkForChanges()

        XCTAssertEqual(manager.entries.map(\.text), ["first"])

        pasteboard.replacePlainText("second")
        manager.checkForChanges()
        pasteboard.replacePlainText("third")
        manager.checkForChanges()

        XCTAssertEqual(manager.entries.map(\.text), ["third", "second"])
    }

    func testLargestActiveLimitIsRetainedAndThenTrimmed() {
        let pasteboard = RecordingClipboardPasteboard()
        let manager = ClipboardManager(
            pasteboard: pasteboard,
            pollingInterval: 60)
        let smallClient = UUID()
        let largeClient = UUID()
        manager.activate(clientID: smallClient, maximumItems: 1)
        manager.activate(clientID: largeClient, maximumItems: 3)
        defer { manager.deactivate(clientID: smallClient) }

        for value in ["first", "second", "third"] {
            pasteboard.replacePlainText(value)
            manager.checkForChanges()
        }
        XCTAssertEqual(manager.entries.count, 3)

        manager.deactivate(clientID: largeClient)
        XCTAssertEqual(manager.entries.map(\.text), ["third"])
    }

    func testCopyWritesExactTextAndClearDoesNotErasePasteboard() throws {
        let pasteboard = RecordingClipboardPasteboard()
        let manager = ClipboardManager(
            pasteboard: pasteboard,
            pollingInterval: 60)
        let clientID = UUID()
        manager.activate(clientID: clientID, maximumItems: 5)
        defer { manager.deactivate(clientID: clientID) }

        let exactText = "  original line\nsecond line  "
        pasteboard.replacePlainText(exactText)
        manager.checkForChanges()
        let entry = try XCTUnwrap(manager.entries.first)

        manager.copy(entry)

        XCTAssertEqual(pasteboard.writes, [exactText])
        XCTAssertEqual(pasteboard.plainText, exactText)

        manager.clearHistory()

        XCTAssertTrue(manager.entries.isEmpty)
        XCTAssertEqual(pasteboard.plainText, exactText)
        XCTAssertEqual(pasteboard.writes, [exactText])
    }
}

private final class RecordingClipboardPasteboard: ClipboardPasteboard {
    private(set) var changeCount = 0
    private(set) var storedPlainText: String?
    private(set) var writes: [String] = []

    var plainText: String? {
        storedPlainText
    }

    func replacePlainText(_ text: String?) {
        storedPlainText = text
        changeCount += 1
    }

    func write(_ text: String) {
        writes.append(text)
        storedPlainText = text
        changeCount += 1
    }
}
