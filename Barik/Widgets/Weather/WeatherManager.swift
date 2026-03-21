import Combine
import CoreLocation
import Foundation

struct WeatherData {
    let temperature: Double
    let weatherCode: Int
    let humidity: Int
    let windSpeed: Double
    let hourlyTemps: [Double]
    let hourlyWeatherCodes: [Int]
    let hourlyTimes: [String]
    let precipitationProbability: Int
    let locationName: String
}

final class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var weather: WeatherData?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var timer: Timer?
    private var geocoder = CLGeocoder()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        startMonitoring()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    private func startMonitoring() {
        // Initial fetch after a short delay to allow location
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.fetchWeather()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Only refetch if moved >1km
        if let last = lastLocation, location.distance(from: last) < 1000 {
            return
        }
        lastLocation = location
        fetchWeather()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Location unavailable"
        }
    }

    private func fetchWeather() {
        guard let location = lastLocation else { return }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,weather_code,relative_humidity_2m,wind_speed_10m,precipitation_probability&hourly=temperature_2m,weather_code&timezone=auto&forecast_hours=6"

        guard let url = URL(string: urlString) else { return }

        DispatchQueue.main.async {
            self.isLoading = true
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.isLoading = false
                    self?.errorMessage = "Fetch failed"
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let current = json["current"] as? [String: Any] {

                    let temp = current["temperature_2m"] as? Double ?? 0
                    let code = current["weather_code"] as? Int ?? 0
                    let humidity = current["relative_humidity_2m"] as? Int ?? 0
                    let wind = current["wind_speed_10m"] as? Double ?? 0
                    let precip = current["precipitation_probability"] as? Int ?? 0

                    var hourlyTemps: [Double] = []
                    var hourlyCodes: [Int] = []
                    var hourlyTimes: [String] = []

                    if let hourly = json["hourly"] as? [String: Any] {
                        hourlyTemps = (hourly["temperature_2m"] as? [Double]) ?? []
                        hourlyCodes = (hourly["weather_code"] as? [Int]) ?? []
                        hourlyTimes = (hourly["time"] as? [String]) ?? []
                    }

                    // Reverse geocode for location name
                    self.geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                        let name = placemarks?.first?.locality ?? "Unknown"

                        let weatherData = WeatherData(
                            temperature: temp,
                            weatherCode: code,
                            humidity: humidity,
                            windSpeed: wind,
                            hourlyTemps: hourlyTemps,
                            hourlyWeatherCodes: hourlyCodes,
                            hourlyTimes: hourlyTimes,
                            precipitationProbability: precip,
                            locationName: name
                        )

                        DispatchQueue.main.async {
                            self.weather = weatherData
                            self.isLoading = false
                            self.errorMessage = nil
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Parse error"
                }
            }
        }.resume()
    }

    static func weatherIcon(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77: return "snowflake"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm w/ hail"
        default: return "Unknown"
        }
    }
}
