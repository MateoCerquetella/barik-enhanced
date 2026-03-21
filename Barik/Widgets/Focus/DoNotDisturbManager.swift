import AppKit
import Combine
import Foundation

final class DoNotDisturbManager: ObservableObject {
    @Published var isFocusActive: Bool = false
    private var timer: Timer?

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    private func startMonitoring() {
        updateStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
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
        let task = Process()
        task.launchPath = "/usr/bin/plutil"
        task.arguments = ["-p", assertionsPath]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // If there are active assertion records, Focus is on
                return output.contains("storeAssertionRecords")
                    && !output.contains("\"storeAssertionRecords\" => {\n}")
            }
        } catch {}
        return false
    }

    func toggleFocus() {
        // Open Focus settings in System Settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.Focus") {
            NSWorkspace.shared.open(url)
        }
    }
}
