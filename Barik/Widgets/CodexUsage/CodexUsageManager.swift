import Foundation
import SwiftUI

private let codexUsageAccountFingerprintKey = "codex-usage-account-fingerprint"
private let codexUsageAcceptedRefreshKey = "codex-usage-accepted-auth-refresh"

// MARK: - Data Models

struct CodexUsageData {
    var primaryPercentage: Double = 0
    var primaryResetDate: Date?
    var primaryWindowMinutes: Int = 0

    var plan: String = "ChatGPT"
    var lastUpdated: Date = Date()
    var lastActivityDate: Date?
    var isAvailable: Bool = false
}

private struct CodexSessionEvent: Decodable {
    let timestamp: String
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let type: String
        let rateLimits: RateLimits?

        enum CodingKeys: String, CodingKey {
            case type
            case rateLimits = "rate_limits"
        }
    }

    struct RateLimits: Decodable {
        let primary: Bucket?
        let secondary: Bucket?
        let credits: Credits?
        let planType: String?

        enum CodingKeys: String, CodingKey {
            case primary
            case secondary
            case credits
            case planType = "plan_type"
        }
    }

    struct Bucket: Decodable {
        let usedPercent: Double
        let windowMinutes: Int
        let resetsAt: TimeInterval

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case windowMinutes = "window_minutes"
            case resetsAt = "resets_at"
        }
    }

    struct Credits: Decodable {
        let hasCredits: Bool?
        let unlimited: Bool?
        let balance: Double?

        enum CodingKeys: String, CodingKey {
            case hasCredits = "has_credits"
            case unlimited
            case balance
        }
    }
}

private enum CodexUsageLoadState {
    case disconnected
    case connectedWithoutSnapshot(data: CodexUsageData)
    case connected(data: CodexUsageData)
    case failed
}

private struct CodexAuthState {
    let plan: String
    let accountID: String?
    let userID: String?
    let lastRefreshDate: Date?
    let subscriptionActiveStart: Date?

    var fingerprint: String? {
        let parts: [String] = [accountID, userID].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "|")
    }

    var switchCutoffDate: Date? {
        [lastRefreshDate, subscriptionActiveStart].compactMap { $0 }.max()
    }
}

// MARK: - Manager

@MainActor
final class CodexUsageManager: ObservableObject {
    static let shared = CodexUsageManager()

    @Published private(set) var usageData = CodexUsageData()
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var fetchFailed: Bool = false

    private var refreshTimer: Timer?
    private var currentConfig: ConfigData = [:]

    private static let refreshInterval: TimeInterval = 30

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
    }

    func startUpdating(config: ConfigData) {
        currentConfig = config
        connectAndFetch()
    }

    func reconnectIfNeeded() {
        connectAndFetch()
    }

    func stopUpdating() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh() {
        fetchFailed = false
        connectAndFetch()
    }

    private func handleWake() {
        refreshTimer?.invalidate()
        Task {
            try? await Task.sleep(for: .seconds(2))
            connectAndFetch()
        }
    }

    private func connectAndFetch() {
        let planOverride = currentConfig["plan"]?.stringValue

        Task {
            let loadState = await Task.detached(priority: .utility) {
                Self.loadUsage(planOverride: planOverride)
            }.value

            switch loadState {
            case .disconnected:
                self.isConnected = false
                self.fetchFailed = false
                self.usageData = CodexUsageData()
                self.stopUpdating()

            case .connectedWithoutSnapshot(let data):
                self.isConnected = true
                self.fetchFailed = false
                self.usageData = data
                self.scheduleRefreshTimer()

            case .connected(let data):
                self.isConnected = true
                self.fetchFailed = false
                self.usageData = data
                self.scheduleRefreshTimer()

            case .failed:
                self.isConnected = true
                self.fetchFailed = true
                self.scheduleRefreshTimer()
            }
        }
    }

    private func scheduleRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.connectAndFetch()
            }
        }
    }

    nonisolated private static func loadUsage(planOverride: String?) -> CodexUsageLoadState {
        let codexHome = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
        let authURL = codexHome.appendingPathComponent("auth.json")
        let sessionsURL = codexHome.appendingPathComponent("sessions", isDirectory: true)

        guard let auth = readAuthState(from: authURL) else {
            return .disconnected
        }

        let plan = formatPlan(planOverride ?? auth.plan)
        let cutoffDate = accountSwitchCutoffDate(for: auth)

        let activity = latestTokenActivity(in: sessionsURL)

        guard let snapshot = latestUsageSnapshot(in: sessionsURL, after: cutoffDate) else {
            var data = CodexUsageData(plan: plan)
            data.lastActivityDate = activity
            return .connectedWithoutSnapshot(data: data)
        }

        persistAccountFingerprintIfNeeded(auth)

        let primaryPercentage = max(0, min(snapshot.bucket.usedPercent / 100, 1))
        let data = CodexUsageData(
            primaryPercentage: primaryPercentage,
            primaryResetDate: Date(timeIntervalSince1970: snapshot.bucket.resetsAt),
            primaryWindowMinutes: snapshot.bucket.windowMinutes,
            plan: formatPlan(planOverride ?? snapshot.plan ?? auth.plan),
            lastUpdated: snapshot.timestamp,
            lastActivityDate: activity,
            isAvailable: true
        )
        return .connected(data: data)
    }

    nonisolated private static func readAuthState(from authURL: URL) -> CodexAuthState? {
        guard let data = try? Data(contentsOf: authURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let authMode = json["auth_mode"] as? String
        if authMode == "apikey" || authMode == "api_key" {
            return CodexAuthState(
                plan: "API Key",
                accountID: nil,
                userID: nil,
                lastRefreshDate: parseTimestamp(json["last_refresh"] as? String ?? ""),
                subscriptionActiveStart: nil
            )
        }

        guard let tokens = json["tokens"] as? [String: Any] else {
            return nil
        }

        let accountID = tokens["account_id"] as? String
        let lastRefreshDate = parseTimestamp(json["last_refresh"] as? String ?? "")

        let candidateTokens = [
            tokens["id_token"] as? String,
            tokens["access_token"] as? String,
        ]

        for token in candidateTokens {
            guard let token,
                  let payload = decodeJWTPayload(token),
                  let auth = payload["https://api.openai.com/auth"] as? [String: Any],
                  let plan = auth["chatgpt_plan_type"] as? String,
                  !plan.isEmpty else {
                continue
            }
            return CodexAuthState(
                plan: plan,
                accountID: auth["chatgpt_account_id"] as? String ?? accountID,
                userID: auth["chatgpt_user_id"] as? String ?? auth["user_id"] as? String,
                lastRefreshDate: lastRefreshDate,
                subscriptionActiveStart: parseTimestamp(auth["chatgpt_subscription_active_start"] as? String ?? "")
            )
        }

        return nil
    }

    nonisolated private static func latestUsageSnapshot(in sessionsURL: URL, after cutoffDate: Date?) -> (bucket: CodexSessionEvent.Bucket, plan: String?, timestamp: Date)? {
        var latestSnapshot: (bucket: CodexSessionEvent.Bucket, plan: String?, timestamp: Date)?

        for fileURL in recentSessionFiles(in: sessionsURL) {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            for line in content.split(separator: "\n").reversed() {
                guard line.contains(#""type":"token_count""#),
                      line.contains(#""rate_limits":"#) else {
                    continue
                }
                guard let event = decodeEvent(from: line),
                      event.type == "event_msg",
                      event.payload.type == "token_count",
                      let rateLimits = event.payload.rateLimits,
                      let bucket = rateLimits.primary,
                      let timestamp = parseTimestamp(event.timestamp) else {
                    continue
                }

                if let cutoffDate, timestamp < cutoffDate {
                    continue
                }

                if let latestSnapshot, latestSnapshot.timestamp >= timestamp {
                    continue
                }

                latestSnapshot = (
                    bucket: bucket,
                    plan: rateLimits.planType,
                    timestamp: timestamp
                )
                break
            }
        }

        return latestSnapshot
    }

    nonisolated private static func accountSwitchCutoffDate(for auth: CodexAuthState) -> Date? {
        guard let fingerprint = auth.fingerprint else {
            return nil
        }

        let defaults = UserDefaults.standard
        guard let previousFingerprint = defaults.string(forKey: codexUsageAccountFingerprintKey) else {
            return auth.switchCutoffDate
        }

        guard previousFingerprint == fingerprint else {
            return auth.switchCutoffDate
        }

        guard defaults.object(forKey: codexUsageAcceptedRefreshKey) != nil else {
            return auth.switchCutoffDate
        }

        return nil
    }

    nonisolated private static func persistAccountFingerprintIfNeeded(_ auth: CodexAuthState) {
        guard let fingerprint = auth.fingerprint else {
            return
        }

        UserDefaults.standard.set(fingerprint, forKey: codexUsageAccountFingerprintKey)
        if let refreshDate = auth.switchCutoffDate {
            UserDefaults.standard.set(refreshDate.timeIntervalSince1970, forKey: codexUsageAcceptedRefreshKey)
        }
    }

    nonisolated private static func latestTokenActivity(in sessionsURL: URL) -> Date? {
        var latestActivity: Date?

        for fileURL in recentSessionFiles(in: sessionsURL) {
            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            for line in content.split(separator: "\n").reversed() {
                guard line.contains(#""type":"token_count""#) else { continue }
                guard let event = decodeEvent(from: line),
                      event.type == "event_msg",
                      event.payload.type == "token_count",
                      let timestamp = parseTimestamp(event.timestamp) else {
                    continue
                }

                if let latestActivity, latestActivity >= timestamp {
                    break
                }

                latestActivity = timestamp
                break
            }
        }

        return latestActivity
    }

    nonisolated private static func recentSessionFiles(in sessionsURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: sessionsURL,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return enumerator
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "jsonl" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                if lhsDate == rhsDate {
                    return lhs.path > rhs.path
                }
                return lhsDate > rhsDate
            }
            .prefix(100)
            .map { $0 }
    }

    nonisolated private static func decodeEvent(from line: Substring) -> CodexSessionEvent? {
        guard let data = String(line).data(using: .utf8) else {
            return nil
        }

        return try? JSONDecoder().decode(CodexSessionEvent.self, from: data)
    }

    nonisolated private static func parseTimestamp(_ rawValue: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: rawValue)
    }

    nonisolated private static func decodeJWTPayload(_ token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count >= 2 else { return nil }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let padding = 4 - (payload.count % 4)
        if padding < 4 {
            payload += String(repeating: "=", count: padding)
        }

        guard let data = Data(base64Encoded: payload),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json
    }

    nonisolated private static func formatPlan(_ rawValue: String) -> String {
        switch rawValue.lowercased() {
        case "free":
            "Free"
        case "plus":
            "Plus"
        case "pro":
            "Pro"
        case "team":
            "Team"
        case "business":
            "Business"
        case "enterprise":
            "Enterprise"
        case "api key":
            "API Key"
        default:
            rawValue
                .replacingOccurrences(of: "-", with: " ")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }
}
