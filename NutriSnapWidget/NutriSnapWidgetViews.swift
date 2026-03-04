import SwiftUI
import WidgetKit

struct NutriSnapWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: NutriSnapEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget: Circular calorie ring

struct SmallWidgetView: View {
    let entry: NutriSnapEntry

    private var progress: Double {
        guard entry.targetCalories > 0 else { return 0 }
        return min(entry.calories / entry.targetCalories, 1.0)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.green.opacity(0.15), lineWidth: 12)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(Int(entry.calories))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("/ \(Int(entry.targetCalories))")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)

                Text("kcal")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
    }
}

// MARK: - Medium Widget: Calorie ring + macro bars

struct MediumWidgetView: View {
    let entry: NutriSnapEntry

    private var calorieProgress: Double {
        guard entry.targetCalories > 0 else { return 0 }
        return min(entry.calories / entry.targetCalories, 1.0)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Calorie ring
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.15), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: calorieProgress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 1) {
                    Text("\(Int(entry.calories))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("kcal")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 90, height: 90)

            // Macro bars
            VStack(alignment: .leading, spacing: 8) {
                MacroBarWidget(
                    label: "Protein",
                    current: entry.protein,
                    target: entry.targetProtein,
                    color: .blue
                )
                MacroBarWidget(
                    label: "Fat",
                    current: entry.fat,
                    target: entry.targetFat,
                    color: .orange
                )
                MacroBarWidget(
                    label: "Carbs",
                    current: entry.carbs,
                    target: entry.targetCarbs,
                    color: .pink
                )
            }
        }
        .padding(12)
    }
}

// MARK: - Macro bar component

struct MacroBarWidget: View {
    let label: String
    let current: Double
    let target: Double
    let color: Color

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(current))/\(Int(target))g")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }
}
