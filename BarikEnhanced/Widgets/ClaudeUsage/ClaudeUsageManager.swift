import Foundation
import LocalAuthentication
import Security
import SwiftUI

// MARK: - Data Models

struct ClaudeUsageData {
    var fiveHourPercentage: Double = 0
    var fiveHourResetDate: Date?

    var weeklyPercentage: Double = 0
    var weeklyResetDate: Date?

    var plan: String = "Pro"
    var lastUpdated: Date = Date()
    var isAvailable: Bool = false
}

private struct UsageResponse: Codable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?
    let sevenDaySonnet: UsageBucket?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
    }

    struct UsageBucket: Codable {
        let utilization: Double
        let resetsAt: String?

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }
}

// MARK: - Manager

@MainActor
final class ClaudeUsageManager: ObservableObject {
    static let shared = ClaudeUsageManager()

    @Published private(set) var usageData = ClaudeUsageData()
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var fetchFailed: Bool = false
    @Published private(set) var errorMessage: String?

    private var refreshTimer: Timer?
    private var recoveryTask: Task<Void, Never>?
    private var cachedCredentials: (accessToken: String, plan: String)?
    private var currentConfig: ConfigData = [:]

    private static let connectedKey = "claude-usage-connected"
    private static let refreshInterval: TimeInterval = 60

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWake()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWake()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWake()
            }
        }
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ManualReloadTriggered"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func startUpdating(config: ConfigData) {
        currentConfig = config
        connectAndFetch(allowUserPrompt: false)
    }

    func reconnectIfNeeded() {
        if cachedCredentials != nil {
            isConnected = true
            fetchData()
            scheduleRefreshTimer()
        } else if !isConnected && UserDefaults.standard.bool(forKey: Self.connectedKey) {
            connectAndFetch(allowUserPrompt: false)
        }
    }

    func stopUpdating() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        recoveryTask?.cancel()
        recoveryTask = nil
    }

    func refresh() {
        fetchFailed = false
        errorMessage = nil
        connectAndFetch(allowUserPrompt: false)
    }

    func requestAccess() {
        connectAndFetch(allowUserPrompt: true)
    }

    private func handleWake() {
        refreshTimer?.invalidate()
        recoveryTask?.cancel()
        recoveryTask = Task { @MainActor [weak self] in
            self?.connectAndFetch(allowUserPrompt: false)
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.connectAndFetch(allowUserPrompt: false)
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.connectAndFetch(allowUserPrompt: false)
        }
    }

    private func connectAndFetch(allowUserPrompt: Bool) {
        let credentials = readKeychainCredentials(allowUserPrompt: allowUserPrompt)

        if let credentials {
            cachedCredentials = credentials
            isConnected = true
            UserDefaults.standard.set(true, forKey: Self.connectedKey)
            fetchData()
            scheduleRefreshTimer()
            return
        }

        if cachedCredentials != nil {
            isConnected = true
            fetchData()
            scheduleRefreshTimer()
            return
        }

        isConnected = false
        errorMessage = nil
        UserDefaults.standard.set(false, forKey: Self.connectedKey)
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func scheduleRefreshTimer() {
        refreshTimer?.invalidate()
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.connectAndFetch(allowUserPrompt: false)
            }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    // MARK: - Data Fetching

    private func fetchData() {
        guard let creds = cachedCredentials else { return }

        let plan = currentConfig["plan"]?.stringValue ?? creds.plan

        Task {
            let result = await fetchUsageWithRetry(token: creds.accessToken)

            switch result {
            case .success(let response):
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

                var data = ClaudeUsageData()
                data.fiveHourPercentage = (response.fiveHour?.utilization ?? 0) / 100
                data.fiveHourResetDate = response.fiveHour.flatMap { bucket in
                    bucket.resetsAt.flatMap { isoFormatter.date(from: $0) }
                }
                data.weeklyPercentage = (response.sevenDay?.utilization ?? 0) / 100
                data.weeklyResetDate = response.sevenDay.flatMap { bucket in
                    bucket.resetsAt.flatMap { isoFormatter.date(from: $0) }
                }
                data.plan = plan.capitalized
                data.lastUpdated = Date()
                data.isAvailable = true

                self.fetchFailed = false
                self.errorMessage = nil
                self.usageData = data

            case .rateLimited:
                self.fetchFailed = true
                self.errorMessage = "Claude is rate limiting usage checks right now. Try again later."

            case .failed:
                self.fetchFailed = true
                self.errorMessage = "The request failed. Your token may have expired."
            }
        }
    }

    // MARK: - API

    private func fetchUsageWithRetry(token: String) async -> FetchResult {
        for attempt in 0..<2 {
            let result = await fetchUsageFromAPI(token: token)
            switch result {
            case .success:
                return result
            case .rateLimited(let retryAfter):
                guard attempt == 0, retryAfter > 0, retryAfter <= 180 else { return .rateLimited(retryAfter: retryAfter) }
                try? await Task.sleep(for: .seconds(retryAfter))
                continue
            case .failed:
                return .failed
            }
        }
        return .failed
    }

    private enum FetchResult {
        case success(UsageResponse)
        case rateLimited(retryAfter: Int)
        case failed
    }

    private func fetchUsageFromAPI(token: String) async -> FetchResult {
        guard let url = URL(string: "https://api.anthropic.com/api/oauth/usage") else { return .failed }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-code/2.1.69", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed }

            if http.statusCode == 429 {
                let retryAfter = http.value(forHTTPHeaderField: "retry-after")
                    .flatMap(Int.init) ?? 0
                return .rateLimited(retryAfter: retryAfter)
            }
            guard http.statusCode == 200 else { return .failed }

            if let decoded = try? JSONDecoder().decode(UsageResponse.self, from: data) {
                return .success(decoded)
            }
            return .failed
        } catch {
            return .failed
        }
    }

    // MARK: - Keychain

    private func readKeychainCredentials(allowUserPrompt: Bool) -> (accessToken: String, plan: String)? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
        ]
        if !allowUserPrompt {
            let context = LAContext()
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            return nil
        }
        let plan = oauth["subscriptionType"] as? String ?? "pro"
        return (token, plan)
    }
}
