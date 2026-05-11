import SwiftUI

struct WeatherPopup: View {
    @ObservedObject var weatherManager: WeatherManager

    var body: some View {
        VStack(spacing: 20) {
            if let weather = weatherManager.weather {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: WeatherManager.weatherIcon(for: weather.weatherCode))
                        .font(.system(size: 28, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(weather.locationName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text(WeatherManager.weatherDescription(for: weather.weatherCode))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Text("\(Int(weather.temperature))°")
                        .font(.system(size: 36, weight: .light, design: .rounded))
                }

                // Details grid
                HStack(spacing: 20) {
                    weatherDetail(icon: "humidity.fill", label: "Humidity", value: "\(weather.humidity)%")
                    weatherDetail(icon: "wind", label: "Wind", value: String(format: "%.0f km/h", weather.windSpeed))
                    weatherDetail(icon: "umbrella.fill", label: "Precip", value: "\(weather.precipitationProbability)%")
                }

                // Hourly forecast
                if !weather.hourlyTemps.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next Hours")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))

                        HStack(spacing: 0) {
                            ForEach(0..<min(6, weather.hourlyTemps.count), id: \.self) { i in
                                VStack(spacing: 6) {
                                    Text(formatHour(weather.hourlyTimes[safe: i] ?? ""))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white.opacity(0.5))

                                    Image(systemName: WeatherManager.weatherIcon(for: weather.hourlyWeatherCodes[safe: i] ?? 0))
                                        .font(.system(size: 14))
                                        .symbolRenderingMode(.hierarchical)

                                    Text("\(Int(weather.hourlyTemps[i]))°")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            } else if let error = weatherManager.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 24))
                    Text(error)
                        .font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.5))
            } else {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Loading weather...")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(25)
        .frame(width: 300)
        .foregroundStyle(.white)
    }

    private func weatherDetail(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.6))
            Text(value)
                .font(.system(size: 13, weight: .medium))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func formatHour(_ isoString: String) -> String {
        // Input: "2026-03-21T14:00" -> "2PM"
        let parts = isoString.components(separatedBy: "T")
        guard parts.count == 2 else { return "" }
        let timeParts = parts[1].components(separatedBy: ":")
        guard let hour = Int(timeParts[0]) else { return "" }
        if hour == 0 { return "12AM" }
        if hour < 12 { return "\(hour)AM" }
        if hour == 12 { return "12PM" }
        return "\(hour - 12)PM"
    }
}

// Safe array subscript
extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
