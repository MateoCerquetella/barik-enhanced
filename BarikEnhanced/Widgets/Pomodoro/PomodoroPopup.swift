import SwiftUI

struct PomodoroPopup: View {
    @ObservedObject var manager: PomodoroManager

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: stateIcon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(stateColor)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pomodoro")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(stateText)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()

                Text("\(manager.completedPomodoros)")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
            }

            // Timer display
            Text(manager.timeString)
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(.white)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(stateColor)
                        .frame(width: geometry.size.width * CGFloat(manager.progress))
                        .animation(.linear(duration: 1), value: manager.progress)
                }
            }
            .frame(height: 6)

            // Controls
            HStack(spacing: 16) {
                Button(action: { manager.stop() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 14))
                        Text("Reset")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.2)))
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: {
                    if manager.state == .idle {
                        manager.startWork()
                    } else {
                        manager.stop()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: manager.state == .idle ? "play.fill" : "pause.fill")
                            .font(.system(size: 14))
                        Text(manager.state == .idle ? "Start" : "Stop")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(stateColor.opacity(0.5)))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(25)
        .frame(width: 280)
        .foregroundStyle(.white)
    }

    private var stateIcon: String {
        switch manager.state {
        case .idle: return "timer"
        case .working: return "flame.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "figure.walk"
        }
    }

    private var stateColor: Color {
        switch manager.state {
        case .idle: return .white
        case .working: return .orange
        case .shortBreak: return .green
        case .longBreak: return .cyan
        }
    }

    private var stateText: String {
        switch manager.state {
        case .idle: return "Ready to focus"
        case .working: return "Focus time"
        case .shortBreak: return "Short break"
        case .longBreak: return "Long break"
        }
    }
}
