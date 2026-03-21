import Foundation

struct WidgetDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let description: String
}

let allWidgets: [WidgetDefinition] = [
    WidgetDefinition(id: "default.spaces", name: "Spaces", icon: "square.grid.2x2", description: "Window manager spaces"),
    WidgetDefinition(id: "default.nowplaying", name: "Now Playing", icon: "music.note", description: "Current song info"),
    WidgetDefinition(id: "default.cpuram", name: "CPU & RAM", icon: "cpu", description: "System resource usage"),
    WidgetDefinition(id: "default.networkactivity", name: "Net Activity", icon: "arrow.up.arrow.down", description: "Upload/download speed"),
    WidgetDefinition(id: "default.volume", name: "Volume", icon: "speaker.wave.2.fill", description: "Audio volume control"),
    WidgetDefinition(id: "default.microphone", name: "Microphone", icon: "mic.fill", description: "Mic mute toggle"),
    WidgetDefinition(id: "default.weather", name: "Weather", icon: "cloud.sun.fill", description: "Temperature & forecast"),
    WidgetDefinition(id: "default.brightness", name: "Brightness", icon: "sun.max.fill", description: "Screen brightness"),
    WidgetDefinition(id: "default.network", name: "Network", icon: "wifi", description: "WiFi/Ethernet status"),
    WidgetDefinition(id: "default.battery", name: "Battery", icon: "battery.75percent", description: "Battery level"),
    WidgetDefinition(id: "default.time", name: "Time", icon: "clock.fill", description: "Date and time"),
    WidgetDefinition(id: "default.dnd", name: "Do Not Disturb", icon: "moon.fill", description: "Focus mode toggle"),
    WidgetDefinition(id: "default.disk", name: "Disk Usage", icon: "internaldrive.fill", description: "Storage monitor"),
    WidgetDefinition(id: "default.uptime", name: "Uptime", icon: "clock.arrow.circlepath", description: "System uptime"),
    WidgetDefinition(id: "default.pomodoro", name: "Pomodoro", icon: "timer", description: "Focus timer"),
    WidgetDefinition(id: "default.performance", name: "Performance", icon: "gauge.with.dots.needle.bottom.50percent", description: "Performance mode"),
    WidgetDefinition(id: "default.keyboardlayout", name: "Keyboard", icon: "keyboard", description: "Input source"),
    WidgetDefinition(id: "default.claude-usage", name: "Claude Usage", icon: "sparkle", description: "Claude API rate limit tracking"),
    WidgetDefinition(id: "default.codex-usage", name: "Codex Usage", icon: "terminal", description: "OpenAI Codex usage tracking"),
    WidgetDefinition(id: "default.countdown", name: "Countdown", icon: "calendar.badge.clock", description: "Days until target date"),
    WidgetDefinition(id: "spacer", name: "Spacer", icon: "arrow.left.and.right", description: "Flexible space"),
    WidgetDefinition(id: "divider", name: "Divider", icon: "line.diagonal", description: "Visual separator"),
]
