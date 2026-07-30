import SwiftUI

struct ClipboardPopup: View {
    @ObservedObject var manager: ClipboardManager
    let maximumItems: Int

    var body: some View {
        ClipboardPopupContent(
            entries: Array(manager.entries.prefix(maximumItems)),
            currentTime: Date(),
            onCopy: manager.copy,
            onClear: manager.clearHistory)
    }
}

struct ClipboardPopupContent: View {
    let entries: [ClipboardHistoryEntry]
    let currentTime: Date
    let onCopy: (ClipboardHistoryEntry) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            content
        }
        .frame(width: 360)
        .padding(22)
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(ClipboardPalette.accent.opacity(0.16))
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ClipboardPalette.accent)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("Clipboard")
                    .font(.headline)
                Text("Memory-only history")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if !entries.isEmpty {
                Button(action: onClear) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Clear clipboard history")
                .help("Clear in-memory clipboard history")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if entries.isEmpty {
            emptyState
        } else if entries.count <= 5 {
            historyRows
        } else {
            ScrollView {
                historyRows
            }
            .scrollIndicators(.hidden)
            .frame(height: 340)
        }
    }

    private var historyRows: some View {
        VStack(spacing: 8) {
            ForEach(entries.indices, id: \.self) { index in
                ClipboardHistoryRow(
                    position: index + 1,
                    entry: entries[index],
                    currentTime: currentTime,
                    onCopy: { onCopy(entries[index]) })
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(systemName: "clipboard")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(ClipboardPalette.accent.opacity(0.8))
            Text("Clipboard history is empty")
                .font(.headline)
            Text("Copy text while this widget is visible to keep it here temporarily.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 26)
        .padding(.vertical, 28)
    }
}

private struct ClipboardHistoryRow: View {
    let position: Int
    let entry: ClipboardHistoryEntry
    let currentTime: Date
    let onCopy: () -> Void

    private var previewText: String {
        ClipboardTextPresentation.preview(entry.text, maximumLength: 160)
    }

    var body: some View {
        Button(action: onCopy) {
            HStack(alignment: .top, spacing: 11) {
                Text("\(position)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(ClipboardPalette.accent)
                    .frame(width: 20, height: 20)
                    .background(ClipboardPalette.accent.opacity(0.13))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 4) {
                    Text(previewText)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(relativeTime)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 8)

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.065))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Copy \(previewText)")
        .help("Copy this entry")
    }

    private var relativeTime: String {
        Self.relativeFormatter.localizedString(
            for: entry.copiedAt,
            relativeTo: currentTime)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .short
        return formatter
    }()
}

struct ClipboardPopupContent_Previews: PreviewProvider {
    static var previews: some View {
        let now = Date()

        return Group {
            ClipboardPopupContent(
                entries: [
                    ClipboardHistoryEntry(
                        text: "npm run test && npm run build",
                        copiedAt: now.addingTimeInterval(-45)),
                    ClipboardHistoryEntry(
                        text: "A multiline note\nwith useful context",
                        copiedAt: now.addingTimeInterval(-240)),
                ],
                currentTime: now,
                onCopy: { _ in },
                onClear: {})
                .previewDisplayName("Recent history")

            ClipboardPopupContent(
                entries: [],
                currentTime: now,
                onCopy: { _ in },
                onClear: {})
                .previewDisplayName("Empty")
        }
        .background(.black)
        .previewLayout(.sizeThatFits)
    }
}
