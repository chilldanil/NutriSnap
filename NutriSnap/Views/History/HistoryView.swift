import SwiftUI
import SwiftData

struct HistoryView: View {
    @AppStorage("currentUser") private var currentUser = ""
    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]
    @Query private var profiles: [UserProfile]
    @State private var selectedDate = Date()
    @State private var showCalendar = true
    @State private var activeCalories: Double = 0
    @State private var basalCalories: Double = 0

    private var logs: [DailyLog] {
        allLogs.filter { $0.userName == currentUser }
    }

    private var selectedLog: DailyLog? {
        logs.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var isHealthKitEnabled: Bool {
        profiles.first(where: { $0.userName == currentUser })?.isHealthKitEnabled ?? false
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Weekly chart
                    WeeklyChartView(logs: logs, isHealthKitEnabled: isHealthKitEnabled)

                    // Calendar toggle
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showCalendar.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(.green)
                            Text(selectedDate, format: .dateTime.day().month(.wide).year())
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(showCalendar ? 90 : 0))
                        }
                        .padding(14)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    if showCalendar {
                        DatePicker("", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(.green)
                            .padding(8)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // Day detail
                    if let log = selectedLog {
                        // Energy Balance (burned calories)
                        if isHealthKitEnabled {
                            EnergyBalanceView(
                                consumed: log.totalCalories,
                                active: activeCalories,
                                basal: basalCalories
                            )
                        }

                        daySummary(log)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("No meals logged")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("History")
            .onAppear {
                fetchBurnedCalories(for: selectedDate)
            }
            .onChange(of: selectedDate) { _, newDate in
                fetchBurnedCalories(for: newDate)
            }
        }
    }

    // MARK: - Day summary

    private func fetchBurnedCalories(for date: Date) {
        guard isHealthKitEnabled else {
            activeCalories = 0
            basalCalories = 0
            return
        }
        Task {
            do {
                let burned = try await HealthKitManager.shared.caloriesBurned(for: date)
                await MainActor.run {
                    activeCalories = burned.active
                    basalCalories = burned.basal
                }
            } catch {
                print("[HealthKit] fetchBurnedCalories error: \(error)")
                await MainActor.run {
                    activeCalories = 0
                    basalCalories = 0
                }
            }
        }
    }

    private func daySummary(_ log: DailyLog) -> some View {
        VStack(spacing: 12) {
            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                StatCard(title: "Calories", value: "\(Int(log.totalCalories))", target: "\(Int(log.targetCalories))", unit: "kcal", color: .green)
                StatCard(title: "Protein", value: "\(Int(log.totalProtein))", target: "\(Int(log.targetProtein))", unit: "g", color: .blue)
                StatCard(title: "Fat", value: "\(Int(log.totalFat))", target: "\(Int(log.targetFat))", unit: "g", color: .orange)
                StatCard(title: "Carbs", value: "\(Int(log.totalCarbs))", target: "\(Int(log.targetCarbs))", unit: "g", color: .pink)
            }

            // Meals list
            ForEach(log.sortedMeals, id: \.id) { meal in
                if !meal.foods.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: meal.mealType.icon)
                                .foregroundStyle(.green)
                            Text(meal.mealType.rawValue)
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(Int(meal.totalCalories)) kcal")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        ForEach(meal.foods, id: \.id) { food in
                            HStack {
                                Text(food.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(food.grams))g · \(Int(food.calories)) kcal")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.leading, 28)
                        }
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

// MARK: - Stat card

struct StatCard: View {
    let title: String
    let value: String
    let target: String
    let unit: String
    let color: Color

    private var progress: Double {
        guard let v = Double(value), let t = Double(target), t > 0 else { return 0 }
        return min(v / t, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(color)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.12))
                        .frame(height: 4)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)

            Text("/ \(target) \(unit)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    HistoryView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
