import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var session: GymSession

    @State private var showExercisePicker = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    summaryHeader
                    ForEach(session.exercises, id: \.self) { exercise in
                        exerciseSection(exercise)
                    }
                    addExerciseButton
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Workout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Workout")
                    }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .confirmationDialog("Delete this workout?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteSession() }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet(
                    alreadyAdded: session.exercises,
                    previousBests: [:]
                ) { exercise in
                    addExercise(exercise)
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Summary header

    private var summaryHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.date, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "dumbbell.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("\(session.exerciseCount) exercises")
                            .font(.subheadline.weight(.medium))
                    }
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(session.completedSetCount) sets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if session.durationSeconds > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(session.formattedDuration)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Exercise section

    private func exerciseSection(_ exercise: GymExercise) -> some View {
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
                editableSetRow(gymSet)
            }

            // Add set
            Button {
                addSet(for: exercise)
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
                removeExercise(exercise)
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

    // MARK: - Editable set row

    private func editableSetRow(_ gymSet: GymSet) -> some View {
        HStack(spacing: 0) {
            Text("\(gymSet.setNumber)")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 36)

            // Weight stepper
            HStack(spacing: 4) {
                Button { gymSet.weight = max(0, gymSet.weight - 2.5) } label: {
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
                Button { gymSet.weight += 2.5 } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }
            .frame(maxWidth: .infinity)

            // Reps stepper
            HStack(spacing: 4) {
                Button { gymSet.reps = max(1, gymSet.reps - 1) } label: {
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
                Button { gymSet.reps += 1 } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }
            .frame(maxWidth: .infinity)

            // Delete set
            Button {
                deleteSet(gymSet)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.6))
            }
            .frame(width: 44)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
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

    private func addExercise(_ exercise: GymExercise) {
        for i in 1...3 {
            let set = GymSet(exercise: exercise, weight: 0, reps: 12, setNumber: i, isCompleted: true)
            session.sets.append(set)
        }
    }

    private func addSet(for exercise: GymExercise) {
        let existing = session.sets(for: exercise)
        let last = existing.last
        let set = GymSet(
            exercise: exercise,
            weight: last?.weight ?? 0,
            reps: last?.reps ?? 12,
            setNumber: existing.count + 1,
            isCompleted: true
        )
        session.sets.append(set)
    }

    private func deleteSet(_ gymSet: GymSet) {
        guard let exercise = gymSet.exercise else { return }
        session.sets.removeAll { $0.id == gymSet.id }
        modelContext.delete(gymSet)
        // Renumber remaining sets
        let remaining = session.sets(for: exercise)
        for (i, s) in remaining.enumerated() {
            s.setNumber = i + 1
        }
    }

    private func removeExercise(_ exercise: GymExercise) {
        let toRemove = session.sets(for: exercise)
        for set in toRemove {
            session.sets.removeAll { $0.id == set.id }
            modelContext.delete(set)
        }
    }

    private func save() {
        // Remove exercises with no sets
        if session.sets.isEmpty {
            modelContext.delete(session)
        } else {
            SupabaseManager.shared.pushGymSession(session)
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteSession() {
        SupabaseManager.shared.deleteGymSession(id: session.id.uuidString)
        modelContext.delete(session)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GymSession.self, GymSet.self, configurations: config)
    let session = GymSession(userName: "daniil", date: Date(), durationSeconds: 1800)
    container.mainContext.insert(session)
    let s1 = GymSet(exercise: .brustpresse, weight: 50, reps: 12, setNumber: 1, isCompleted: true)
    let s2 = GymSet(exercise: .brustpresse, weight: 50, reps: 10, setNumber: 2, isCompleted: true)
    let s3 = GymSet(exercise: .latzug, weight: 40, reps: 12, setNumber: 1, isCompleted: true)
    session.sets.append(contentsOf: [s1, s2, s3])

    return SessionDetailView(session: session)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
