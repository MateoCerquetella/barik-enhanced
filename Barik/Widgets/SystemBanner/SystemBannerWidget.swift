import AppKit
import SwiftUI

struct BannerButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                configuration.isPressed ? color.opacity(0.7) : color
            )
            .clipShape(.capsule)
    }
}

struct SystemBannerWidget: View {
    let withLeftPadding: Bool
    
    @State private var showWhatsNew: Bool = false
    @StateObject private var updater = AppUpdater()
    
    init(withLeftPadding: Bool = false) {
        self.withLeftPadding = withLeftPadding
    }

    private var hasVisibleContent: Bool {
        updater.updateAvailable || showWhatsNew
    }

    var body: some View {
        Group {
            if hasVisibleContent {
                HStack(spacing: 8) {
                    UpdateBannerWidget(updater: updater)
                    if showWhatsNew {
                        ChangelogBannerWidget()
                    }
                }
                .padding(.leading, withLeftPadding ? 8 : 0)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowWhatsNewBanner"))) { _ in
            withAnimation {
                showWhatsNew = true
            }
        }.onReceive(NotificationCenter.default.publisher(for: Notification.Name("HideWhatsNewBanner"))) { _ in
            withAnimation {
                showWhatsNew = false
            }
        }
    }
}

struct SystemBannerWidget_Previews: PreviewProvider {
    static var previews: some View {
        SystemBannerWidget()
            .frame(width: 200, height: 100)
            .background(Color.black)
    }
}
