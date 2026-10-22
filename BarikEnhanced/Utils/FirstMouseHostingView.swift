import SwiftUI

/// Barik lives in non-activating panels, so the first click after focusing
/// another app used to activate the panel and never reach the widget. SwiftUI
/// gestures then needed a second click, which made every widget feel slow.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
