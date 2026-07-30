import AppKit

protocol ClipboardPasteboard: AnyObject {
    var changeCount: Int { get }
    var plainText: String? { get }

    func write(_ text: String)
}

final class SystemClipboardPasteboard: ClipboardPasteboard {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    var changeCount: Int {
        pasteboard.changeCount
    }

    var plainText: String? {
        pasteboard.string(forType: .string)
    }

    func write(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
