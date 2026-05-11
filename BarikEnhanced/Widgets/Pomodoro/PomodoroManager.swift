import Combine
import Foundation
import UserNotifications

enum PomodoroState: String {
    case idle, working, shortBreak, longBreak
}

final class PomodoroManager: ObservableObject {
    static let shared = PomodoroManager()
    @Published var state: PomodoroState = .idle
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var completedPomodoros: Int = 0

    var workDuration: TimeInterval = 25 * 60
    var shortBreakDuration: TimeInterval = 5 * 60
    var longBreakDuration: TimeInterval = 15 * 60
    var pomodorosBeforeLongBreak: Int = 4

    private var timer: Timer?

    private init() {}

    var timeString: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        let total: TimeInterval
        switch state {
        case .idle: return 0
        case .working: total = workDuration
        case .shortBreak: total = shortBreakDuration
        case .longBreak: total = longBreakDuration
        }
        return total > 0 ? 1.0 - (timeRemaining / total) : 0
    }

    func startWork() {
        state = .working
        timeRemaining = workDuration
        startTimer()
    }

    func startBreak() {
        if completedPomodoros > 0 && completedPomodoros % pomodorosBeforeLongBreak == 0 {
            state = .longBreak
            timeRemaining = longBreakDuration
        } else {
            state = .shortBreak
            timeRemaining = shortBreakDuration
        }
        startTimer()
    }

    func stop() {
        stopTimer()
        state = .idle
        timeRemaining = workDuration
    }

    func toggle() {
        if state == .idle {
            startWork()
        } else {
            stop()
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.timerCompleted()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func timerCompleted() {
        stopTimer()
        sendNotification()

        switch state {
        case .working:
            completedPomodoros += 1
            startBreak()
        case .shortBreak, .longBreak:
            state = .idle
            timeRemaining = workDuration
        case .idle:
            break
        }
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        switch state {
        case .working:
            content.title = "Pomodoro Complete!"
            content.body = "Time for a break. You've completed \(completedPomodoros + 1) pomodoros."
        case .shortBreak, .longBreak:
            content.title = "Break Over!"
            content.body = "Ready for another focus session?"
        case .idle:
            return
        }
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    deinit {
        stopTimer()
    }
}
