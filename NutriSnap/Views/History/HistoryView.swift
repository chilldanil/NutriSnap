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
    @State private var showCopiedToast = false
    @State private var copiedCount = 0

    // Multi-day copy mode
    @State private var isCopyMode = false
    @State private var selectedDatesForCopy: Set<DateComponents> = []

    private var logs: [DailyLog] {
        allLogs.filter { $0.userName == currentUser }
    }

    private var selectedLog: DailyLog? {
        logs.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var isHealthKitEnabled: Bool {
        profiles.first(where: { $0.userName == currentUser })?.isHealthKitEnabled ?? false
    }

    /// Logs matching the multi-select dates, sorted chronologically
    private var selectedLogsForCopy: [DailyLog] {
        let calendar = Calendar.current
        return logs
            .filter { log in
                let dc = calendar.dateComponents([.year, .month, .day], from: log.date)
                return selectedDatesForCopy.contains(dc)
            }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
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
                                    .foregroundStyle(isCopyMode ? .orange : .green)
                                Text(selectedDate, format: .dateTime.day().month(.wide).year())
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                if isCopyMode {
                                    Text("\(selectedDatesForCopy.count) selected")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.orange)
                                }
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
                                .tint(isCopyMode ? .orange : .green)
                                .padding(8)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        // Selected days pills (copy mode)
                        if isCopyMode && !selectedDatesForCopy.isEmpty {
                            selectedDatesPills
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
                    .padding(.bottom, isCopyMode ? 80 : 0)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("History")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if isCopyMode {
                            Button("Done") {
                                withAnimation(.spring(response: 0.3)) {
                                    isCopyMode = false
                                    selectedDatesForCopy.removeAll()
                                }
                            }
                            .foregroundStyle(.orange)
                            .fontWeight(.semibold)
                        } else {
                            Button {
                                enterCopyMode()
                            } label: {
                                Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(showCopiedToast ? .green : .primary)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                        }
                    }
                }
                .overlay(alignment: .top) {
                    if showCopiedToast {
                        copiedToast
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .onAppear {
                    fetchBurnedCalories(for: selectedDate)
                }
                .onChange(of: selectedDate) { _, newDate in
                    fetchBurnedCalories(for: newDate)
                    if isCopyMode {
                        toggleDateForCopy(newDate)
                    }
                }

                // Bottom copy bar (copy mode)
                if isCopyMode {
                    copyBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Copy mode

    private func enterCopyMode() {
        withAnimation(.spring(response: 0.3)) {
            isCopyMode = true
            showCalendar = true
            selectedDatesForCopy.removeAll()
            // Pre-select current day if it has data
            if selectedLog != nil {
                let dc = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
                selectedDatesForCopy.insert(dc)
            }
        }
    }

    private func toggleDateForCopy(_ date: Date) {
        let dc = Calendar.current.dateComponents([.year, .month, .day], from: date)
        withAnimation(.spring(response: 0.2)) {
            if selectedDatesForCopy.contains(dc) {
                selectedDatesForCopy.remove(dc)
            } else {
                // Only add if that day has logged data
                let hasLog = logs.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
                if hasLog {
                    selectedDatesForCopy.insert(dc)
                }
            }
        }
    }

    // MARK: - Selected dates pills

    private var selectedDatesPills: some View {
        let sorted = selectedDatesForCopy.compactMap { Calendar.current.date(from: $0) }.sorted()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sorted, id: \.self) { date in
                    HStack(spacing: 4) {
                        Text(date, format: .dateTime.day().month(.abbreviated))
                            .font(.caption.weight(.medium))
                        Button {
                            let dc = Calendar.current.dateComponents([.year, .month, .day], from: date)
                            withAnimation(.spring(response: 0.2)) {
                                selectedDatesForCopy.remove(dc)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Bottom copy bar

    private var copyBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedDatesForCopy.removeAll()
                }
            } label: {
                Text("Clear")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                copyMultipleDays()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc.fill")
                    let count = selectedDatesForCopy.count
                    Text(count == 1 ? "Copy 1 day" : "Copy \(count) days")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(selectedDatesForCopy.isEmpty ? Color.gray : Color.orange)
                .clipShape(Capsule())
            }
            .disabled(selectedDatesForCopy.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - Copy logic

    private func copyMultipleDays() {
        let logsToExport = selectedLogsForCopy
        guard !logsToExport.isEmpty else { return }
        let count = logsToExport.count

        Task {
            var sections: [String] = []

            for log in logsToExport {
                var active: Double = 0
                var basal: Double = 0
                if isHealthKitEnabled {
                    do {
                        let burned = try await HealthKitManager.shared.caloriesBurned(for: log.date)
                        active = burned.active
                        basal = burned.basal
                    } catch { }
                }
                let text = DailyLogViewModel.formatDayText(
                    log: log,
                    activeCalories: active,
                    basalCalories: basal
                )
                sections.append(text)
            }

            let combined = sections.joined(separator: "\n\n━━━━━━━━━━━━━━━━━━━━\n\n")

            await MainActor.run {
                UIPasteboard.general.string = combined
                copiedCount = count

                withAnimation(.spring(response: 0.3)) {
                    showCopiedToast = true
                    isCopyMode = false
                    selectedDatesForCopy.removeAll()
                }
            }

            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.spring(response: 0.3)) {
                    showCopiedToast = false
                }
            }
        }
    }

    // MARK: - Copied toast

    private var copiedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(copiedCount > 1
                 ? "\(copiedCount) days copied"
                 : "Copied to clipboard")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 8)
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
