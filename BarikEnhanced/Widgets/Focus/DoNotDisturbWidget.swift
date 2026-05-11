import SwiftUI

struct DoNotDisturbWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject private var dndManager = DoNotDisturbManager.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: dndManager.isFocusActive ? "moon.fill" : "moon")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(dndManager.isFocusActive ? .purple : .icon)
                .animation(.easeInOut(duration: 0.3), value: dndManager.isFocusActive)
        }
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .onTapGesture {
            dndManager.toggleFocus()
        }
    }
}

struct DoNotDisturbWidget_Previews: PreviewProvider {
    static var previews: some View {
        DoNotDisturbWidget()
            .background(.black)
            .environmentObject(ConfigProvider(config: [:]))
            .previewLayout(.sizeThatFits)
    }
}
