import SwiftUI

struct WeatherWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject private var weatherManager = WeatherManager.shared
    @State private var rect: CGRect = .zero

    var body: some View {
        HStack(spacing: 4) {
            if let weather = weatherManager.weather {
                Image(systemName: WeatherManager.weatherIcon(for: weather.weatherCode))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.foregroundOutside)
                    .symbolRenderingMode(.monochrome)

                Text("\(Int(weather.temperature))°")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.foregroundOutside)
            } else if weatherManager.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.icon)
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { rect = geometry.frame(in: .global) }
                    .onChange(of: geometry.frame(in: .global)) { _, newState in rect = newState }
            }
        )
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "weather") {
                WeatherPopup(weatherManager: weatherManager)
            }
        }
    }

    private func weatherIconColor(code: Int) -> Color {
        switch code {
        case 0: return .yellow
        case 1, 2: return .orange
        case 3, 45, 48: return .gray
        case 51...67: return .cyan
        case 71...86: return .white
        case 95, 96, 99: return .purple
        default: return .icon
        }
    }
}
