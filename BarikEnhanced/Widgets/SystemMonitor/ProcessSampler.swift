import Foundation

/// One process row for the System Monitor popup.
struct TopProcess: Identifiable, Equatable {
    let id: Int32
    let name: String
    let cpuPercent: Double
    let memoryBytes: Int64

    var memoryText: String {
        Self.formatter.string(fromByteCount: max(0, memoryBytes))
    }

    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .memory
        return formatter
    }()
}

/// Samples running processes with `/bin/ps`. Only called while the System
/// Monitor popup is open, so it never runs on the idle menu bar path.
enum ProcessSampler {
    static func sample() -> [TopProcess] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-Aceo", "pid=,pcpu=,rss=,comm="]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        let ownPID = ProcessInfo.processInfo.processIdentifier
        return output.split(separator: "\n").compactMap { line in
            let parts = line.split(
                separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
            guard parts.count == 4,
                  let pid = Int32(parts[0]),
                  pid > 1,
                  pid != ownPID,
                  let cpu = Double(parts[1]),
                  let rssKB = Int64(parts[2])
            else {
                return nil
            }
            let command = String(parts[3])
            let name = command.hasPrefix("/")
                ? (command as NSString).lastPathComponent
                : command
            return TopProcess(
                id: pid,
                name: name,
                cpuPercent: cpu,
                memoryBytes: rssKB * 1024)
        }
    }
}
