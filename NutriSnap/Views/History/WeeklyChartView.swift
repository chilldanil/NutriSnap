import SwiftUI
import Charts

struct DayData: Identifiable {
    let id = UUID()
    let date: Date
    let calories: Double
    let target: Double
    let burned: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let hasData: Bool
}

/// One bar segment for the chart (consumed vs burned)
struct ChartBarEntry: Identifiable {
    let id = UUID()
    let date: Date
    let category: String   // "Consumed" or "Burned"
    let value: Double
}

struct WeeklyChartView: View {
    let logs: [DailyLog]
    var isHealthKitEnabled: Bool = false
    @State private var selectedDay: DayData?
    @State private var weekBurned: [Date: Double] = [:]

    private var weekData: [DayData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -(6 - daysAgo), to: today)!
            let log = logs.first { calendar.isDate($0.date, inSameDayAs: date) }
            let hasMeals = log?.meals.contains(where: { !$0.foods.isEmpty }) ?? false
            let burned = weekBurned[calendar.startOfDay(for: date)] ?? 0
            return DayData(
                date: date,
                calories: log?.totalCalories ?? 0,
                target: log?.targetCalories ?? 0,
                burned: burned,
                protein: log?.totalProtein ?? 0,
                fat: log?.totalFat ?? 0,
                carbs: log?.totalCarbs ?? 0,
                hasData: hasMeals || burned > 0
            )
        }
    }

    /// Flat array for a grouped bar chart
    private var chartEntries: [ChartBarEntry] {
        weekData.flatMap { day in
            var entries = [ChartBarEntry(date: day.date, category: "Consumed", value: day.calories)]
            if isHealthKitEnabled && day.burned > 0 {
                entries.append(ChartBarEntry(date: day.date, category: "Burned", value: day.burned))
            }
            return entries
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
            Chart(chartEntries) { entry in
                BarMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Calories", entry.value)
                )
                .foregroundStyle(entry.category == "Consumed" ? Color.green.gradient : Color.red.gradient)
                .cornerRadius(5)
                .position(by: .value("Type", entry.category))

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
            .chartForegroundStyleScale([
                "Consumed": Color.green,
                "Burned": Color.red
            ])
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

            // Legend
            if isHealthKitEnabled {
                HStack(spacing: 16) {
                    legendDot(color: .green, label: "Consumed")
                    legendDot(color: .red, label: "Burned")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            // Summary row
            HStack(spacing: 0) {
                summaryPill(title: "Avg", value: "\(Int(avgCalories))", unit: "kcal", color: .green)
                if isHealthKitEnabled {
                    summaryPill(title: "Burned", value: "\(Int(avgBurned))", unit: "kcal", color: .red)
                }
                summaryPill(title: "Protein", value: "\(Int(weekData.reduce(0) { $0 + $1.protein }))", unit: "g", color: .blue)
                summaryPill(title: "Fat", value: "\(Int(weekData.reduce(0) { $0 + $1.fat }))", unit: "g", color: .orange)
                summaryPill(title: "Carbs", value: "\(Int(weekData.reduce(0) { $0 + $1.carbs }))", unit: "g", color: .pink)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            fetchWeekBurned()
        }
    }

    // MARK: - Averages

    private var avgBurned: Double {
        let withData = weekData.filter { $0.burned > 0 }
        guard !withData.isEmpty else { return 0 }
        return withData.reduce(0) { $0 + $1.burned } / Double(withData.count)
    }

    // MARK: - Fetch burned for whole week

    private func fetchWeekBurned() {
        guard isHealthKitEnabled else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        Task {
            var result: [Date: Double] = [:]
            for daysAgo in 0..<7 {
                let date = calendar.date(byAdding: .day, value: -(6 - daysAgo), to: today)!
                do {
                    let burned = try await HealthKitManager.shared.caloriesBurned(for: date)
                    result[calendar.startOfDay(for: date)] = burned.active + burned.basal
                } catch {
                    result[calendar.startOfDay(for: date)] = 0
                }
            }
            await MainActor.run {
                weekBurned = result
            }
        }
    }

    // MARK: - Helpers

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
        }
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
