import Foundation
import SQLite3
import SwiftUI

struct OpenCodeUsageData {
    var rollingCost: Double = 0
    var rollingLimit: Double = 12
    var rollingPercentage: Double = 0
    var rollingResetDate: Date?

    var weeklyCost: Double = 0
    var weeklyLimit: Double = 30
    var weeklyPercentage: Double = 0
    var weeklyResetDate: Date?

    var monthlyCost: Double = 0
    var monthlyLimit: Double = 60
    var monthlyPercentage: Double = 0
    var monthlyResetDate: Date?

    var plan: String = "Go"
    var lastUpdated: Date = Date()
    var isAvailable: Bool = false
}

@MainActor
final class OpenCodeUsageManager: ObservableObject {
    static let shared = OpenCodeUsageManager()

    @Published private(set) var usageData = OpenCodeUsageData()
    @Published private(set) var isConnected: Bool = false

    private var refreshTimer: Timer?
    private var recoveryTask: Task<Void, Never>?
    private var currentConfig: ConfigData = [:]

    private static let refreshInterval: TimeInterval = 60

    private var authPath: String {
        NSHomeDirectory() + "/.local/share/opencode/auth.json"
    }

    private var dbPath: String {
        NSHomeDirectory() + "/.local/share/opencode/opencode.db"
    }

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleWake() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleWake() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleWake() }
        }
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ManualReloadTriggered"), object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func startUpdating(config: ConfigData) {
        currentConfig = config
        connectAndFetch()
    }

    func reconnectIfNeeded() { connectAndFetch() }
    func stopUpdating() {
        refreshTimer?.invalidate(); refreshTimer = nil
        recoveryTask?.cancel(); recoveryTask = nil
    }
    func refresh() { connectAndFetch() }

    private func handleWake() {
        refreshTimer?.invalidate()
        recoveryTask?.cancel()
        recoveryTask = Task { @MainActor [weak self] in
            self?.connectAndFetch()
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.connectAndFetch()
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.connectAndFetch()
        }
    }

    private func connectAndFetch() {
        let auth = authPath
        let db = dbPath
        let planOverride = currentConfig["plan"]?.stringValue

        Task {
            let data = await Task.detached(priority: .utility) {
                Self.loadUsage(authPath: auth, dbPath: db, planOverride: planOverride)
            }.value

            self.isConnected = data.isAvailable
            self.usageData = data

            if data.isAvailable {
                self.scheduleRefreshTimer()
            } else {
                self.stopUpdating()
            }
        }
    }

    private func scheduleRefreshTimer() {
        refreshTimer?.invalidate()
        let timer = Timer(timeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.connectAndFetch() }
        }
        timer.tolerance = 2
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    nonisolated private static func loadUsage(authPath: String, dbPath: String, planOverride: String?) -> OpenCodeUsageData {
        guard FileManager.default.fileExists(atPath: authPath) else {
            return OpenCodeUsageData(isAvailable: false)
        }

        let plan = planOverride ?? "Go"

        guard FileManager.default.fileExists(atPath: dbPath),
              let db = openDB(dbPath) else {
            var data = OpenCodeUsageData(plan: plan)
            data.isAvailable = true
            return data
        }
        defer { sqlite3_close(db) }

        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let sevenDaysAgo = now.addingTimeInterval(-7 * 86400)
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 86400)
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: now)
        let daysUntilMonday = (9 - weekday) % 7
        let nextMonday = cal.startOfDay(for: cal.date(byAdding: .day, value: daysUntilMonday == 0 ? 7 : daysUntilMonday, to: now)!)
        let nextMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: cal.date(byAdding: .month, value: 1, to: now)!))!

        let rollingCost = queryCost(db: db, since: fiveHoursAgo, provider: "opencode-go")
        let rollingFirst = queryEarliestTimestamp(db: db, since: fiveHoursAgo, provider: "opencode-go")
        let rollingPct = min(rollingCost / 12.0, 1.0)

        let weeklyCost = queryCost(db: db, since: sevenDaysAgo, provider: "opencode-go")
        let weeklyPct = min(weeklyCost / 30.0, 1.0)

        let monthlyCost = queryCost(db: db, since: thirtyDaysAgo, provider: "opencode-go")
        let monthlyPct = min(monthlyCost / 60.0, 1.0)

        return OpenCodeUsageData(
            rollingCost: rollingCost,
            rollingLimit: 12.0,
            rollingPercentage: rollingPct,
            rollingResetDate: rollingFirst.flatMap { Date(timeIntervalSince1970: $0 + 5 * 3600) },
            weeklyCost: weeklyCost,
            weeklyLimit: 30.0,
            weeklyPercentage: weeklyPct,
            weeklyResetDate: nextMonday,
            monthlyCost: monthlyCost,
            monthlyLimit: 60.0,
            monthlyPercentage: monthlyPct,
            monthlyResetDate: nextMonthStart,
            plan: plan,
            lastUpdated: now,
            isAvailable: true
        )
    }

    nonisolated private static func openDB(_ path: String) -> OpaquePointer? {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else { return nil }
        return db
    }

    nonisolated private static func queryCost(db: OpaquePointer, since: Date, provider: String) -> Double {
        let ts = Int64(since.timeIntervalSince1970 * 1000)
        let sql = """
            SELECT SUM(CAST(json_extract(data, '$.cost') AS REAL))
            FROM message
            WHERE time_created >= ?
              AND json_extract(data, '$.cost') IS NOT NULL
              AND json_extract(data, '$.providerID') = ?
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, ts)
        sqlite3_bind_text(stmt, 2, provider, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return sqlite3_column_double(stmt, 0)
    }

    nonisolated private static func queryEarliestTimestamp(db: OpaquePointer, since: Date, provider: String) -> TimeInterval? {
        let ts = Int64(since.timeIntervalSince1970 * 1000)
        let sql = """
            SELECT time_created
            FROM message
            WHERE time_created >= ?
              AND json_extract(data, '$.providerID') = ?
            ORDER BY time_created ASC LIMIT 1
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, ts)
        sqlite3_bind_text(stmt, 2, provider, -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let ms = sqlite3_column_int64(stmt, 0)
        return TimeInterval(ms) / 1000.0
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
