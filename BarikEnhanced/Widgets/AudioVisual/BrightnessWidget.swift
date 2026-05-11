import SwiftUI

struct BrightnessWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    var config: ConfigData { configProvider.config }
    var showPercentage: Bool { config["show-percentage"]?.boolValue ?? false }

    @ObservedObject private var brightnessManager = BrightnessManager.shared
    @State private var rect: CGRect = .zero

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: brightnessIcon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.icon)

            if showPercentage {
                Text("\(Int(brightnessManager.brightness * 100))%")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.foregroundOutside)
                    .transition(.blurReplace)
            }
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
            MenuBarPopup.show(rect: rect, id: "brightness") {
                BrightnessPopup()
            }
        }
    }

    private var brightnessIcon: String {
        if brightnessManager.brightness < 0.33 {
            return "sun.min.fill"
        } else if brightnessManager.brightness < 0.66 {
            return "sun.max.fill"
        } else {
            return "sun.max.fill"
        }
    }
}

struct BrightnessWidget_Previews: PreviewProvider {
    static var previews: some View {
        BrightnessWidget()
            .background(.black)
            .environmentObject(ConfigProvider(config: [:]))
            .previewLayout(.sizeThatFits)
    }
}
