import SwiftUI
import SwiftData
import Charts

struct GymTrackingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUser") private var currentUser = ""
    @Query(sort: \GymSession.date, order: .reverse)
    private var allSessions: [GymSession]

    @State private var showActiveWorkout = false
    @State private var editingSession: GymSession?
    @State private var selectedExercise: GymExercise = .brustpresse
    @State private var chartPeriod: ChartPeriod = .threeMonths
    @State private var showCopiedToast = false
    @State private var copiedCount = 0
    @State private var isCopyMode = false
    @State private var selectedSessionIDs: Set<UUID> = []

    private var sessions: [GymSession] {
        allSessions.filter { $0.userName == currentUser }
    }

    private var latest: GymSession? { sessions.first }

    private var selectedSessionsForCopy: [GymSession] {
        sessions
            .filter { selectedSessionIDs.contains($0.id) }
            .sorted { $0.date < $1.date }
    }

    // Sessions this week
    private var thisWeekCount: Int {
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return sessions.filter { $0.date >= startOfWeek }.count
    }

    // Best weight for selected exercise across all sessions
    private var chartData: [(date: Date, weight: Double)] {
        let cutoff = chartPeriod.startDate
        return sessions
            .filter { $0.date >= cutoff }
            .reversed()
            .compactMap { session in
                let best = session.sets(for: selectedExercise)
                    .filter(\.isCompleted)
                    .map(\.weight)
                    .max()
                guard let w = best, w > 0 else { return nil }
                return (date: session.date, weight: w)
            }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if sessions.isEmpty {
                            emptyState
                        } else {
                            startButton
                            statsRow
                            progressChart
                            historySection
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 80)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Sport")
                .toolbar {
                    if !sessions.isEmpty {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            if isCopyMode {
                                Button("Done") {
                                    withAnimation(.spring(response: 0.3)) {
                                        isCopyMode = false
                                        selectedSessionIDs.removeAll()
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

                                Button { showActiveWorkout = true } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                }
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
                .fullScreenCover(isPresented: $showActiveWorkout) {
                    ActiveWorkoutView(previousSession: latest)
                }
                .sheet(item: $editingSession) { session in
                    SessionDetailView(session: session)
                        .presentationDetents([.large])
                }

                if isCopyMode {
                    copyBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 80)
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green.opacity(0.5))
            Text("Track Your Workouts")
                .font(.title2.bold())
            Text("Log sets, reps, and weights for each\nexercise. See your progress over time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showActiveWorkout = true
            } label: {
                Label("Start Workout", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Start button

    private var startButton: some View {
        Button {
            showActiveWorkout = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.title3)
                Text("Start Workout")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(.green.gradient)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Stats row

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                title: "This Week",
                value: "\(thisWeekCount)",
                subtitle: "workouts",
                icon: "calendar",
                color: .blue
            )
            statCard(
                title: "Total",
                value: "\(sessions.count)",
                subtitle: "sessions",
                icon: "trophy.fill",
                color: .orange
            )
            if let latest {
                statCard(
                    title: "Last",
                    value: "\(latest.exerciseCount)",
                    subtitle: "exercises",
                    icon: "dumbbell.fill",
                    color: .green
                )
            }
        }
    }

    private func statCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Progress chart

    private var progressChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress")
                    .font(.headline)
                Spacer()
                Picker("Period", selection: $chartPeriod) {
                    ForEach(ChartPeriod.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            // Exercise picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(GymExercise.allCases) { exercise in
                        Button {
                            selectedExercise = exercise
                        } label: {
                            Text(exercise.rawValue)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(selectedExercise == exercise ? Color.green : Color(.tertiarySystemGroupedBackground))
                                .foregroundStyle(selectedExercise == exercise ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if chartData.count >= 2 {
                Chart(chartData, id: \.date) { point in
                    LineMark(x: .value("Date", point.date), y: .value("kg", point.weight))
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Date", point.date), y: .value("kg", point.weight))
                        .foregroundStyle(.green.opacity(0.1))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", point.date), y: .value("kg", point.weight))
                        .foregroundStyle(.green)
                        .symbolSize(chartData.count > 20 ? 10 : 30)
                }
                .frame(height: 180)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f", v))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.caption2)
                    }
                }
                .chartYScale(domain: chartYDomain)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("2+ workouts with \(selectedExercise.rawValue)\nneeded to show trend")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 30)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var chartYDomain: ClosedRange<Double> {
        let weights = chartData.map(\.weight)
        guard let min = weights.min(), let max = weights.max() else { return 0...100 }
        let padding = Swift.max((max - min) * 0.15, 2)
        return (min - padding)...(max + padding)
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("History")
                    .font(.headline)

                Spacer()

                if isCopyMode {
                    Text("\(selectedSessionIDs.count) selected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            ForEach(sessions.prefix(30)) { session in
                sessionRow(session)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if isCopyMode {
                            toggleSessionSelection(session)
                        } else {
                            editingSession = session
                        }
                    }
                    .contextMenu {
                        Button {
                            copySessions([session])
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        Button {
                            editingSession = session
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            deleteSession(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                if session.id != sessions.prefix(30).last?.id {
                    Divider().padding(.leading, 50)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sessionRow(_ session: GymSession) -> some View {
        let isSelected = selectedSessionIDs.contains(session.id)

        return HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(session.date, format: .dateTime.day())
                    .font(.title3.bold().monospacedDigit())
                Text(session.date, format: .dateTime.month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(session.exerciseCount) exercises")
                        .font(.subheadline.weight(.medium))
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(session.completedSetCount) sets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(session.formattedDuration)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                let exerciseNames = session.exercises.map(\.rawValue)
                if !exerciseNames.isEmpty {
                    Text(exerciseNames.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()

            Image(systemName: isCopyMode ? (isSelected ? "checkmark.circle.fill" : "circle") : "chevron.right")
                .font(isCopyMode ? .title3 : .caption2.weight(.semibold))
                .foregroundStyle(isCopyMode ? (isSelected ? Color.orange : Color.gray.opacity(0.45)) : Color.secondary.opacity(0.6))
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(isCopyMode && isSelected ? Color.orange.opacity(0.12) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Copy

    private func enterCopyMode() {
        withAnimation(.spring(response: 0.3)) {
            isCopyMode = true
            selectedSessionIDs.removeAll()
            if let latest {
                selectedSessionIDs.insert(latest.id)
            }
        }
    }

    private func toggleSessionSelection(_ session: GymSession) {
        withAnimation(.spring(response: 0.2)) {
            if selectedSessionIDs.contains(session.id) {
                selectedSessionIDs.remove(session.id)
            } else {
                selectedSessionIDs.insert(session.id)
            }
        }
    }

    private var copyBar: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    selectedSessionIDs.removeAll()
                }
            } label: {
                Text("Clear")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                copySelectedSessions()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.doc.fill")
                    let count = selectedSessionIDs.count
                    Text(count == 1 ? "Copy 1 workout" : "Copy \(count) workouts")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(selectedSessionIDs.isEmpty ? Color.gray : Color.orange)
                .clipShape(Capsule())
            }
            .disabled(selectedSessionIDs.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func copySelectedSessions() {
        copySessions(selectedSessionsForCopy, exitCopyMode: true)
    }

    private func copySessions(_ sessionsToCopy: [GymSession], exitCopyMode: Bool = false) {
        guard !sessionsToCopy.isEmpty else { return }

        let combined = sessionsToCopy
            .map(\.clipboardText)
            .joined(separator: "\n\n━━━━━━━━━━━━━━━━━━━━\n\n")

        UIPasteboard.general.string = combined
        copiedCount = sessionsToCopy.count

        withAnimation(.spring(response: 0.3)) {
            showCopiedToast = true
            if exitCopyMode {
                isCopyMode = false
                selectedSessionIDs.removeAll()
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring(response: 0.3)) {
                showCopiedToast = false
            }
        }
    }

    private var copiedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(copiedCount > 1 ? "\(copiedCount) workouts copied" : "Copied to clipboard")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 8)
    }

    // MARK: - Delete

    private func deleteSession(_ session: GymSession) {
        SupabaseManager.shared.deleteGymSession(id: session.id.uuidString)
        selectedSessionIDs.remove(session.id)
        modelContext.delete(session)
        try? modelContext.save()
    }
}

#Preview {
    GymTrackingView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
