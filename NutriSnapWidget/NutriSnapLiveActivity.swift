import ActivityKit
import WidgetKit
import SwiftUI

struct NutriSnapLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NutriSnapActivityAttributes.self) { context in
            // Lock Screen / StandBy banner
            LockScreenLiveActivityView(state: context.state)
                .activityBackgroundTint(.black)
                .activitySystemActionForegroundColor(.green)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded regions

                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 3) {
                            Circle().fill(.blue).frame(width: 6, height: 6)
                            Text("Protein")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Text("\(Int(context.state.protein))/\(Int(context.state.targetProtein))g")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 3) {
                            Text("Carbs")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Circle().fill(.pink).frame(width: 6, height: 6)
                        }
                        Text("\(Int(context.state.carbs))/\(Int(context.state.targetCarbs))g")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("\(Int(context.state.calories))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("/ \(Int(context.state.targetCalories)) kcal")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Circle().fill(.orange).frame(width: 6, height: 6)
                            Text("Fat \(Int(context.state.fat))/\(Int(context.state.targetFat))g")
                                .font(.system(size: 11, design: .rounded))
                                .monospacedDigit()
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.cyan)
                            Text("\(Int(context.state.waterMl))/\(Int(context.state.waterTarget))ml")
                                .font(.system(size: 11, design: .rounded))
                                .monospacedDigit()
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(.green)
                    .font(.system(size: 14))
            } compactTrailing: {
                Text("\(Int(context.state.calories))/\(Int(context.state.targetCalories))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.green)
            } minimal: {
                Text("\(Int(context.state.calories))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Lock Screen Banner View

struct LockScreenLiveActivityView: View {
    let state: NutriSnapActivityAttributes.ContentState

    private var calorieProgress: Double {
        guard state.targetCalories > 0 else { return 0 }
        return min(state.calories / state.targetCalories, 1.0)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Calorie ring
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: calorieProgress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(state.calories))")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("kcal")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)

            // Macros + Water
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    macroLabel("P", value: state.protein, target: state.targetProtein, color: .blue)
                    macroLabel("F", value: state.fat, target: state.targetFat, color: .orange)
                    macroLabel("C", value: state.carbs, target: state.targetCarbs, color: .pink)
                }

                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.cyan)
                    Text("\(Int(state.waterMl)) / \(Int(state.waterTarget)) ml")
                        .font(.system(size: 11, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
    }

    private func macroLabel(_ letter: String, value: Double, target: Double, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(Int(value))/\(Int(target))g")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .monospacedDigit()
        }
    }
}
