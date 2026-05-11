import Foundation
import Combine

final class DiskUsageManager: ObservableObject {
    static let shared = DiskUsageManager()

    @Published var usedGB: Double = 0.0
    @Published var totalGB: Double = 0.0
    @Published var usagePercent: Double = 0.0

    private var timer: Timer?

    private init() {
        startMonitoring()
    }

    deinit { stopMonitoring() }

    private func startMonitoring() {
        updateDiskUsage()
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateDiskUsage()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateDiskUsage() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            do {
                let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
                let totalBytes = (attrs[.systemSize] as? Int64) ?? 0
                let freeBytes = (attrs[.systemFreeSize] as? Int64) ?? 0
                let usedBytes = totalBytes - freeBytes

                let newTotal = Double(totalBytes) / (1024 * 1024 * 1024)
                let newUsed = Double(usedBytes) / (1024 * 1024 * 1024)
                let newPercent = newTotal > 0 ? (newUsed / newTotal) * 100.0 : 0.0

                DispatchQueue.main.async {
                    if self.totalGB != newTotal { self.totalGB = newTotal }
                    if self.usedGB != newUsed { self.usedGB = newUsed }
                    if self.usagePercent != newPercent { self.usagePercent = newPercent }
                }
            } catch {}
        }
    }
}
