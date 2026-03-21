import SwiftUI

struct MicrophoneWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider

    @ObservedObject private var micManager = MicrophoneManager.shared
    @State private var rect: CGRect = .zero

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: micIcon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(micColor)
                .animation(.easeInOut(duration: 0.3), value: micManager.isMuted)
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        rect = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) { _, newState in
                        rect = newState
                    }
            }
        )
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .onTapGesture {
            micManager.toggleMute()
        }
    }

    private var micIcon: String {
        if micManager.isMuted {
            return "mic.slash.fill"
        }
        return "mic.fill"
    }

    private var micColor: Color {
        if micManager.isMuted {
            return .red.opacity(0.8)
        }
        return .icon
    }
}

struct MicrophoneWidget_Previews: PreviewProvider {
    static var previews: some View {
        MicrophoneWidget()
            .background(.black)
            .environmentObject(ConfigProvider(config: [:]))
            .previewLayout(.sizeThatFits)
    }
}
