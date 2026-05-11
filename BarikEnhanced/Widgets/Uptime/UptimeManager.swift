import Foundation
import Combine

final class UptimeManager: ObservableObject {
    static let shared = UptimeManager()

    @Published var uptimeString: String = ""
    @Published var bootDate: Date = Date()

    private var timer: Timer?

    private init() {
        startMonitoring()
    }

    deinit { stopMonitoring() }

    private func startMonitoring() {
        updateUptime()
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.updateUptime()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateUptime() {
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]

        guard sysctl(&mib, 2, &boottime, &size, nil, 0) == 0 else { return }

        let boot = Date(timeIntervalSince1970: TimeInterval(boottime.tv_sec))
        let interval = Date().timeIntervalSince(boot)

        let days = Int(interval) / 86400
        let hours = (Int(interval) % 86400) / 3600
        let minutes = (Int(interval) % 3600) / 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        parts.append("\(minutes)m")

        let newString = parts.joined(separator: " ")

        DispatchQueue.main.async {
            if self.uptimeString != newString { self.uptimeString = newString }
            self.bootDate = boot
        }
    }
}
