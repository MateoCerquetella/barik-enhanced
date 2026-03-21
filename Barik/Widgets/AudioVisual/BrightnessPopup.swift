import SwiftUI

struct BrightnessPopup: View {
    @StateObject private var brightnessManager = BrightnessManager()

    var body: some View {
        VStack(spacing: 20) {
            // Header with icon and title
            HStack(spacing: 12) {
                Image(systemName: brightnessIcon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Brightness")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("\(Int(brightnessManager.brightness * 100))%")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()
            }

            // Brightness control section
            VStack(spacing: 12) {
                // Brightness slider
                HStack(spacing: 12) {
                    Image(systemName: "sun.min")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))

                    Slider(
                        value: Binding(
                            get: { brightnessManager.brightness },
                            set: { brightnessManager.setBrightness($0) }
                        ),
                        in: 0...1
                    )
                    .accentColor(.white)

                    Image(systemName: "sun.max")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(25)
        .frame(width: 280)
        .foregroundStyle(.white)
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

struct BrightnessPopup_Previews: PreviewProvider {
    static var previews: some View {
        BrightnessPopup()
            .background(Color.black)
            .previewLayout(.sizeThatFits)
    }
}
