import SwiftUI

struct PomodoroWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    var config: ConfigData { configProvider.config }

    @ObservedObject private var pomodoroManager = PomodoroManager.shared
    @State private var rect: CGRect = .zero

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: pomodoroIcon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(pomodoroColor)
                .animation(.easeInOut(duration: 0.3), value: pomodoroManager.state)

            if pomodoroManager.state != .idle {
                Text(pomodoroManager.timeString)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.foregroundOutside)
                    .transition(.blurReplace)
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { rect = geometry.frame(in: .global) }
                    .onChange(of: geometry.frame(in: .global)) { _, newState in rect = newState }
            }
        )
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "pomodoro") {
                PomodoroPopup(manager: pomodoroManager)
            }
        }
        .onAppear {
            // Apply config
            if let workMin = config["work-duration"]?.intValue {
                pomodoroManager.workDuration = Double(workMin) * 60
            }
            if let shortMin = config["short-break"]?.intValue {
                pomodoroManager.shortBreakDuration = Double(shortMin) * 60
            }
            if let longMin = config["long-break"]?.intValue {
                pomodoroManager.longBreakDuration = Double(longMin) * 60
            }
            if let count = config["pomodoros-before-long-break"]?.intValue {
                pomodoroManager.pomodorosBeforeLongBreak = count
            }
            if pomodoroManager.state == .idle {
                pomodoroManager.timeRemaining = pomodoroManager.workDuration
            }
        }
    }

    private var pomodoroIcon: String {
        switch pomodoroManager.state {
        case .idle: return "timer"
        case .working: return "flame.fill"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "figure.walk"
        }
    }

    private var pomodoroColor: Color {
        switch pomodoroManager.state {
        case .idle: return .icon
        case .working: return .orange
        case .shortBreak: return .green
        case .longBreak: return .cyan
        }
    }
}
