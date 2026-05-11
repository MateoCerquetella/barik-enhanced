import SwiftUI

struct OpenCodeUsageWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject private var usageManager = OpenCodeUsageManager.shared

    @State private var widgetFrame: CGRect = .zero

    private var rollingPct: Double {
        min(usageManager.usageData.rollingPercentage, 1.0)
    }

    private var weeklyPct: Double {
        min(usageManager.usageData.weeklyPercentage, 1.0)
    }

    private var monthlyRemaining: Double {
        max(0, min(1, 1 - usageManager.usageData.monthlyPercentage))
    }

    private var thresholdConfiguration: UsageThresholdConfiguration {
        UsageThresholdConfiguration(config: configProvider.config)
    }

    private var rollingColor: Color {
        thresholdConfiguration.color(for: rollingPct)
    }

    private var weeklyColor: Color {
        thresholdConfiguration.color(for: weeklyPct)
    }

    var body: some View {
        ZStack {
            if usageManager.usageData.isAvailable {
                Circle()
                    .trim(from: 0.5 - rollingPct / 2, to: 0.5 + rollingPct / 2)
                    .stroke(rollingColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 28, height: 28)
                    .animation(.easeOut(duration: 0.3), value: rollingPct)

                Circle()
                    .trim(from: 0.5 - weeklyPct / 2, to: 0.5 + weeklyPct / 2)
                    .stroke(weeklyColor.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .rotationEffect(.degrees(90))
                    .frame(width: 22, height: 22)
                    .animation(.easeOut(duration: 0.3), value: weeklyPct)
            }

            drainableIcon
        }
        .frame(width: 28, height: 28)
        .foregroundStyle(.foregroundOutside)
        .shadow(color: .foregroundShadowOutside, radius: 3)
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.001))
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        widgetFrame = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                        widgetFrame = newFrame
                    }
            }
        )
        .onTapGesture {
            MenuBarPopup.show(rect: widgetFrame, id: "opencode-usage") {
                OpenCodeUsagePopup()
                    .environmentObject(configProvider)
            }
        }
        .onAppear {
            usageManager.startUpdating(config: configProvider.config)
        }
    }

    private var drainableIcon: some View {
        let iconSize: CGFloat = 12

        return ZStack {
            Image(systemName: "terminal")
                .font(.system(size: 8, weight: .medium))
                .opacity(0.28)
                .frame(width: iconSize, height: iconSize)

            Rectangle()
                .fill(.white)
                .frame(width: iconSize, height: iconSize * monthlyRemaining)
                .frame(width: iconSize, height: iconSize, alignment: .bottom)
                .animation(.easeOut(duration: 0.8), value: monthlyRemaining)
                .mask(
                    Image(systemName: "terminal")
                        .font(.system(size: 8, weight: .medium))
                        .frame(width: iconSize, height: iconSize)
                )
        }
    }
}
