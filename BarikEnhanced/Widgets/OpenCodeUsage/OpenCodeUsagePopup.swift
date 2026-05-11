import SwiftUI

struct OpenCodeUsagePopup: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject private var usageManager = OpenCodeUsageManager.shared
    @State private var showSettings = false

    private var thresholdConfiguration: UsageThresholdConfiguration {
        UsageThresholdConfiguration(config: configProvider.config)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBar
            Divider().background(Color.white.opacity(0.2))

            if showSettings {
                UsageThresholdSettingsView(
                    title: "OpenCode",
                    widgetConfigKey: "default.opencode-usage",
                    accentColor: openCodeGreen,
                    initialConfiguration: thresholdConfiguration
                )
            } else if !usageManager.isConnected {
                connectView
            } else if usageManager.usageData.isAvailable {
                rateLimitSection(
                    icon: "clock",
                    title: "Rolling Usage",
                    percentage: usageManager.usageData.rollingPercentage,
                    resetDate: usageManager.usageData.rollingResetDate,
                    resetPrefix: "Resets in",
                    subtitle: formatCost(usageManager.usageData.rollingCost, limit: usageManager.usageData.rollingLimit)
                )
                Divider().background(Color.white.opacity(0.2))
                rateLimitSection(
                    icon: "calendar",
                    title: "Weekly Usage",
                    percentage: usageManager.usageData.weeklyPercentage,
                    resetDate: usageManager.usageData.weeklyResetDate,
                    resetPrefix: "Resets in",
                    subtitle: formatCost(usageManager.usageData.weeklyCost, limit: usageManager.usageData.weeklyLimit)
                )
                Divider().background(Color.white.opacity(0.2))
                rateLimitSection(
                    icon: "chart.bar",
                    title: "Monthly Usage",
                    percentage: usageManager.usageData.monthlyPercentage,
                    resetDate: usageManager.usageData.monthlyResetDate,
                    resetPrefix: "Resets in",
                    subtitle: formatCost(usageManager.usageData.monthlyCost, limit: usageManager.usageData.monthlyLimit)
                )
                Divider().background(Color.white.opacity(0.2))
                footerSection
            } else {
                emptyView
            }
        }
        .frame(width: 280)
        .background(Color.black)
        .onAppear {
            usageManager.reconnectIfNeeded()
        }
    }

    // MARK: - Title Bar

    private var titleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 14))
                .foregroundStyle(openCodeGreen)
                .frame(width: 18, height: 18)
            Text("OpenCode Usage")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            if usageManager.usageData.isAvailable && !showSettings {
                Text(usageManager.usageData.plan)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(openCodeGreen.opacity(0.3))
                    .foregroundColor(openCodeGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: showSettings ? "chart.bar.fill" : "slider.horizontal.3")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Rate Limit Section

    private func rateLimitSection(
        icon: String,
        title: String,
        percentage: Double,
        resetDate: Date?,
        resetPrefix: String,
        subtitle: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .opacity(0.6)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(Int(min(percentage, 1.0) * 100))%")
                    .font(.system(size: 24, weight: .semibold))
            }

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .opacity(0.45)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(progressColor(for: percentage))
                        .frame(
                            width: geometry.size.width * min(percentage, 1.0),
                            height: 6
                        )
                        .animation(.easeOut(duration: 0.3), value: percentage)
                }
            }
            .frame(height: 6)

            if let resetDate {
                Text("\(resetPrefix) \(resetTimeString(resetDate))")
                    .font(.system(size: 11))
                    .opacity(0.5)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func progressColor(for percentage: Double) -> Color {
        thresholdConfiguration.color(for: percentage)
    }

    private func resetTimeString(_ date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        if interval <= 0 { return "soon" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            let formatter = DateFormatter()
            formatter.dateFormat = "E h:mm a"
            return formatter.string(from: date)
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Updated \(timeAgoString(usageManager.usageData.lastUpdated)) · local DB")
                    .font(.system(size: 11))
                    .opacity(0.4)

                Spacer()

                Button(action: {
                    if let url = URL(string: "https://opencode.ai/auth") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 12))
                        .opacity(0.6)
                }
                .buttonStyle(.plain)
                .help("Open opencode.ai dashboard for authoritative usage")
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }

                Button(action: {
                    usageManager.refresh()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .opacity(0.6)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Connect / Not Installed

    private var connectView: some View {
        VStack(spacing: 14) {
            Image(systemName: "terminal")
                .font(.system(size: 28))
                .opacity(0.4)

            Text("Sign in to OpenCode Go to view your rate-limit usage directly in the menu bar.")
                .font(.system(size: 11))
                .opacity(0.5)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                usageManager.refresh()
            }) {
                Text("Check Again")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(openCodeGreen)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            Text("Reads `~/.local/share/opencode/auth.json` and the message database.")
                .font(.system(size: 10))
                .opacity(0.3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .padding(.vertical, 30)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.pie")
                .font(.system(size: 24))
                .opacity(0.5)

            Text("Use OpenCode Go first. The widget tracks costs from your local message database.")
                .font(.system(size: 11))
                .opacity(0.5)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: {
                usageManager.refresh()
            }) {
                Text("Refresh")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(openCodeGreen)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .padding(.vertical, 30)
    }

    private func timeAgoString(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds) sec ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        return "\(minutes / 60)h ago"
    }

    private func formatCost(_ cost: Double, limit: Double) -> String {
        String(format: "$%.2f / $%.0f", cost, limit)
    }

    private var openCodeGreen: Color {
        Color(red: 0.2, green: 0.8, blue: 0.5)
    }
}
