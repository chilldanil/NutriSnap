import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currentUser") private var currentUser = ""

    let previousSession: GymSession?

    @State private var session: GymSession?
    @State private var elapsedSeconds = 0
    @State private var timer: Timer?
    @State private var showExercisePicker = false
    @State private var showFinishConfirmation = false
    @State private var showDiscardConfirmation = false

    // Previous best weights for each exercise (from last session)
    private var previousBests: [GymExercise: (weight: Double, reps: Int)] {
        guard let prev = previousSession else { return [:] }
        var result: [GymExercise: (Double, Int)] = [:]
        for exercise in GymExercise.allCases {
            if let best = prev.sets(for: exercise)
                .filter(\.isCompleted)
                .max(by: { $0.weight < $1.weight }) {
                result[exercise] = (best.weight, best.reps)
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    timerHeader
                    if let session {
                        ForEach(session.exercises, id: \.self) { exercise in
                            exerciseSection(exercise, session: session)
                        }
                    }
                    addExerciseButton
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        if session?.sets.isEmpty == true {
                            discardWorkout()
                        } else {
                            showDiscardConfirmation = true
                        }
                    }
                    .foregroundStyle(.red)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") {
                        showFinishConfirmation = true
                    }
                    .fontWeight(.semibold)
                    .disabled(session?.completedSetCount == 0)
                }
            }
            .confirmationDialog("Finish workout?", isPresented: $showFinishConfirmation, titleVisibility: .visible) {
                Button("Finish Workout") { finishWorkout() }
            } message: {
                if let s = session {
                    Text("\(s.completedSetCount) sets completed · \(s.exerciseCount) exercises")
                }
            }
            .confirmationDialog("Discard workout?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { discardWorkout() }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet(
                    alreadyAdded: session?.exercises ?? [],
                    previousBests: previousBests
                ) { exercise in
                    addExercise(exercise)
                }
                .presentationDetents([.medium])
            }
            .onAppear { startWorkout() }
            .onDisappear { timer?.invalidate() }
        }
    }

    // MARK: - Timer header

    private var timerHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                Text(formatTime(elapsedSeconds))
                    .font(.system(.title3, design: .monospaced).bold())
                    .monospacedDigit()
            }
            Spacer()
            if let session {
                Text("\(session.completedSetCount) sets done")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Exercise section

    private func exerciseSection(_ exercise: GymExercise, session: GymSession) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: exercise.icon)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(exercise.rawValue)
                        .font(.subheadline.bold())
                    Text(exercise.subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                // Show previous best
                if let prev = previousBests[exercise] {
                    Text("prev: \(String(format: "%.0f", prev.weight))kg x \(prev.reps)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Column headers
            HStack(spacing: 0) {
                Text("SET")
                    .frame(width: 36)
                Text("KG")
                    .frame(maxWidth: .infinity)
                Text("REPS")
                    .frame(maxWidth: .infinity)
                Text("")
                    .frame(width: 44)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)

            // Set rows
            let exerciseSets = session.sets(for: exercise)
            ForEach(exerciseSets) { gymSet in
                setRow(gymSet)
            }

            // Add set button
            Button {
                addSet(for: exercise, session: session)
            } label: {
                HStack {
                    Image(systemName: "plus")
                        .font(.caption2.bold())
                    Text("Add Set")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }

            // Remove exercise
            Button {
                removeExercise(exercise, from: session)
            } label: {
                Text("Remove Exercise")
                    .font(.caption2)
                    .foregroundStyle(.red.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Set row

    private func setRow(_ gymSet: GymSet) -> some View {
        HStack(spacing: 0) {
            // Set number
            Text("\(gymSet.setNumber)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36)

            // Weight stepper
            weightStepper(for: gymSet)
                .frame(maxWidth: .infinity)

            // Reps stepper
            repsStepper(for: gymSet)
                .frame(maxWidth: .infinity)

            // Completion checkbox
            Button {
                withAnimation(.spring(response: 0.3)) {
                    gymSet.isCompleted.toggle()
                    if gymSet.isCompleted {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    }
                }
            } label: {
                Image(systemName: gymSet.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(gymSet.isCompleted ? Color.green : Color.gray.opacity(0.3))
            }
            .frame(width: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(gymSet.isCompleted ? Color.green.opacity(0.05) : .clear)
    }

    // MARK: - Weight stepper

    private func weightStepper(for gymSet: GymSet) -> some View {
        HStack(spacing: 4) {
            Button {
                gymSet.weight = max(0, gymSet.weight - 2.5)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Circle())
            }

            Text(String(format: gymSet.weight.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", gymSet.weight))
                .font(.subheadline.bold().monospacedDigit())
                .frame(width: 40)
                .contentTransition(.numericText())

            Button {
                gymSet.weight += 2.5
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Reps stepper

    private func repsStepper(for gymSet: GymSet) -> some View {
        HStack(spacing: 4) {
            Button {
                gymSet.reps = max(1, gymSet.reps - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Circle())
            }

            Text("\(gymSet.reps)")
                .font(.subheadline.bold().monospacedDigit())
                .frame(width: 28)
                .contentTransition(.numericText())

            Button {
                gymSet.reps += 1
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Add exercise button

    private var addExerciseButton: some View {
        Button {
            showExercisePicker = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Exercise")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Actions

    private func startWorkout() {
        let s = GymSession(userName: currentUser, date: Date())
        modelContext.insert(s)
        session = s
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func addExercise(_ exercise: GymExercise) {
        guard let session else { return }
        let prev = previousBests[exercise]
        // Add 3 default sets, pre-filled from previous
        for i in 1...3 {
            let set = GymSet(
                exercise: exercise,
                weight: prev?.weight ?? 0,
                reps: prev?.reps ?? 12,
                setNumber: i
            )
            session.sets.append(set)
        }
    }

    private func addSet(for exercise: GymExercise, session: GymSession) {
        let existingSets = session.sets(for: exercise)
        let lastSet = existingSets.last
        let newSet = GymSet(
            exercise: exercise,
            weight: lastSet?.weight ?? 0,
            reps: lastSet?.reps ?? 12,
            setNumber: existingSets.count + 1
        )
        session.sets.append(newSet)
    }

    private func removeExercise(_ exercise: GymExercise, from session: GymSession) {
        let toRemove = session.sets(for: exercise)
        for set in toRemove {
            session.sets.removeAll { $0.id == set.id }
            modelContext.delete(set)
        }
    }

    private func finishWorkout() {
        guard let session else { return }
        timer?.invalidate()
        session.durationSeconds = elapsedSeconds

        // Remove uncompleted sets
        let incomplete = session.sets.filter { !$0.isCompleted }
        for set in incomplete {
            session.sets.removeAll { $0.id == set.id }
            modelContext.delete(set)
        }

        // If no sets left, delete the session
        if session.sets.isEmpty {
            modelContext.delete(session)
        } else {
            session.date = Calendar.current.startOfDay(for: Date())
            SupabaseManager.shared.pushGymSession(session)
        }

        try? modelContext.save()
        dismiss()
    }

    private func discardWorkout() {
        timer?.invalidate()
        if let session {
            modelContext.delete(session)
            try? modelContext.save()
        }
        dismiss()
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Exercise Picker

struct ExercisePickerSheet: View {
    let alreadyAdded: [GymExercise]
    let previousBests: [GymExercise: (weight: Double, reps: Int)]
    let onSelect: (GymExercise) -> Void

    @Environment(\.dismiss) private var dismiss

    private var available: [GymExercise] {
        GymExercise.allCases.filter { !alreadyAdded.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                if available.isEmpty {
                    ContentUnavailableView(
                        "All Added",
                        systemImage: "checkmark.circle",
                        description: Text("All exercises are in your workout")
                    )
                } else {
                    ForEach(available) { exercise in
                        Button {
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: exercise.icon)
                                    .font(.title3)
                                    .foregroundStyle(.green)
                                    .frame(width: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.rawValue)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text(exercise.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let prev = previousBests[exercise] {
                                    Text("\(String(format: "%.0f", prev.weight))kg x \(prev.reps)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ActiveWorkoutView(previousSession: nil)
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
