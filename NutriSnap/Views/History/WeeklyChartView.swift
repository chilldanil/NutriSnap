import SwiftUI
import Charts

struct DayData: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let target: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let hasData: Bool
}

struct WeeklyChartView: View {
    let logs: [DailyLog]
    @State private var selectedDay: DayData?

    private var weekData: [DayData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -(6 - daysAgo), to: today)!
            let log = logs.first { calendar.isDate($0.date, inSameDayAs: date) }
            let hasMeals = log?.meals.contains(where: { !$0.foods.isEmpty }) ?? false
            return DayData(
                date: date,
                calories: log?.totalCalories ?? 0,
                target: log?.targetCalories ?? 0,
                protein: log?.totalProtein ?? 0,
                fat: log?.totalFat ?? 0,
                carbs: log?.totalCarbs ?? 0,
                hasData: hasMeals
            )
        }
    }

    private var daysLogged: Int {
        weekData.filter(\.hasData).count
    }

    private var avgCalories: Double {
        let logged = weekData.filter(\.hasData)
        guard !logged.isEmpty else { return 0 }
        return logged.reduce(0) { $0 + $1.calories } / Double(logged.count)
    }

    private var avgTarget: Double {
        let logged = weekData.filter { $0.target > 0 }
        guard !logged.isEmpty else { return 0 }
        return logged.reduce(0) { $0 + $1.target } / Double(logged.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("This Week")
                    .font(.headline)
                Spacer()
                Text("\(daysLogged)/7 days logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Bar chart
            Chart(weekData) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Calories", day.calories)
                )
                .foregroundStyle(
                    day.calories > day.target && day.target > 0
                        ? Color.orange.gradient
                        : Color.green.gradient
                )
                .cornerRadius(5)

                if avgTarget > 0 {
                    RuleMark(y: .value("Target", avgTarget))
                        .foregroundStyle(.white.opacity(0.25))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("target")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(height: 170)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            // Summary row
            HStack(spacing: 0) {
                summaryPill(title: "Avg", value: "\(Int(avgCalories))", unit: "kcal", color: .green)
                summaryPill(title: "Protein", value: "\(Int(weekData.reduce(0) { $0 + $1.protein }))", unit: "g", color: .blue)
                summaryPill(title: "Fat", value: "\(Int(weekData.reduce(0) { $0 + $1.fat }))", unit: "g", color: .orange)
                summaryPill(title: "Carbs", value: "\(Int(weekData.reduce(0) { $0 + $1.carbs }))", unit: "g", color: .pink)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func summaryPill(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(color)
            Text("\(unit)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WeeklyChartView(logs: [])
        .padding()
        .preferredColorScheme(.dark)
}
