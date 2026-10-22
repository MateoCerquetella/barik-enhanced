import SwiftUI

/// Top CPU/RAM consumers with a two-step kill control.
struct TopProcessSection: View {
    enum Metric: String, CaseIterable {
        case cpu = "CPU"
        case ram = "RAM"
    }

    let cpuProcesses: [TopProcess]
    let ramProcesses: [TopProcess]
    let onKill: (TopProcess) -> Void

    @State private var metric: Metric = .cpu
    @State private var killCandidate: Int32?

    private var displayedProcesses: [TopProcess] {
        metric == .cpu ? cpuProcesses : ramProcesses
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("TOP CONSUMERS")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                Picker("", selection: $metric) {
                    ForEach(Metric.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 96)
            }

            if displayedProcesses.isEmpty {
                Text("Sampling processes...")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(displayedProcesses) { process in
                        processRow(process)
                        if process.id != displayedProcesses.last?.id {
                            Divider().overlay(.white.opacity(0.06))
                        }
                    }
                }
                .background(.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text("Press ✕ twice to send SIGTERM. Unsaved work in that app may be lost.")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func processRow(_ process: TopProcess) -> some View {
        HStack(spacing: 7) {
            Text(String(process.id))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 34, alignment: .trailing)

            Text(process.name)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 4)

            Text(metric == .cpu
                 ? String(format: "%.1f%%", process.cpuPercent)
                 : process.memoryText)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(metric == .cpu ? .green : .cyan)
                .frame(width: 62, alignment: .trailing)

            Button {
                confirmKill(process)
            } label: {
                Text(killCandidate == process.id ? "KILL?" : "✕")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .frame(width: 36, height: 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(killCandidate == process.id ? .red : .gray)
            .help("Send SIGTERM to \(process.name) (\(process.id))")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func confirmKill(_ process: TopProcess) {
        if killCandidate == process.id {
            onKill(process)
            killCandidate = nil
        } else {
            killCandidate = process.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if killCandidate == process.id {
                    killCandidate = nil
                }
            }
        }
    }
}
