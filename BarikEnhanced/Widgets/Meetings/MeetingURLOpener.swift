import AppKit
import Foundation

protocol MeetingURLOpening {
    @discardableResult
    func open(_ url: URL) -> Bool
}

struct WorkspaceMeetingURLOpener: MeetingURLOpening {
    @discardableResult
    func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }
}

struct MeetingJoinCoordinator {
    private let opener: any MeetingURLOpening

    init(opener: any MeetingURLOpening = WorkspaceMeetingURLOpener()) {
        self.opener = opener
    }

    @discardableResult
    func join(_ link: MeetingLink) -> Bool {
        opener.open(link.url)
    }
}
