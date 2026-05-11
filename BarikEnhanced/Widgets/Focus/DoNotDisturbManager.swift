import AppKit
import Combine
import Foundation

final class DoNotDisturbManager: ObservableObject {
    static let shared = DoNotDisturbManager()

    @Published var isFocusActive: Bool = false
    private var timer: Timer?

    private init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        updateStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateStatus() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }

            let isFocused = self.checkFocusState()

            DispatchQueue.main.async {
                if self.isFocusActive != isFocused {
                    self.isFocusActive = isFocused
                }
            }
        }
    }

    private func checkFocusState() -> Bool {
        let assertionsPath = NSHomeDirectory() + "/Library/DoNotDisturb/DB/Assertions.json"
        guard let data = FileManager.default.contents(atPath: assertionsPath),
              let content = String(data: data, encoding: .utf8) else {
            return false
        }
        // If there are active assertion records, Focus is on
        return content.contains("storeAssertionRecords") && content.count > 100
    }

    func toggleFocus() {
        // Open Focus settings in System Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.Focus") {
            NSWorkspace.shared.open(url)
        }
    }
}
