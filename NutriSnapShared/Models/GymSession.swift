import Foundation
import SwiftData

@Model
final class GymSession {
    var id: UUID
    var userName: String
    var date: Date
    var durationSeconds: Int
    var notes: String
    @Relationship(deleteRule: .cascade) var sets: [GymSet]
    var createdAt: Date

    init(
        userName: String,
        date: Date = Date(),
        durationSeconds: Int = 0,
        notes: String = ""
    ) {
        self.id = UUID()
        self.userName = userName
        self.date = date
        self.durationSeconds = durationSeconds
        self.notes = notes
        self.sets = []
        self.createdAt = Date()
    }

    var exerciseCount: Int {
        Set(sets.map(\.exerciseRaw)).count
    }

    var totalVolume: Double {
        sets.filter(\.isCompleted).reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var completedSetCount: Int {
        sets.filter(\.isCompleted).count
    }

    var exercises: [GymExercise] {
        let rawValues = sets.map(\.exerciseRaw)
        var seen = Set<String>()
        var result: [GymExercise] = []
        for raw in rawValues {
            if !seen.contains(raw), let ex = GymExercise(rawValue: raw) {
                seen.insert(raw)
                result.append(ex)
            }
        }
        return result
    }

    func sets(for exercise: GymExercise) -> [GymSet] {
        sets.filter { $0.exerciseRaw == exercise.rawValue }
            .sorted { $0.setNumber < $1.setNumber }
    }

    var formattedDuration: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var clipboardText: String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateStyle = .full

        var lines: [String] = []
        lines.append("Workout - \(formatter.string(from: date))")

        var summaryParts = [
            "\(exerciseCount) exercises",
            "\(completedSetCount) sets"
        ]
        if durationSeconds > 0 {
            summaryParts.append(formattedDuration)
        }
        if totalVolume > 0 {
            summaryParts.append("\(totalVolume.workoutNumberFormatted) kg volume")
        }
        lines.append(summaryParts.joined(separator: " · "))

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty {
            lines.append("")
            lines.append("Notes: \(trimmedNotes)")
        }

        for exercise in exercises {
            let completedSets = sets(for: exercise).filter(\.isCompleted)
            guard !completedSets.isEmpty else { continue }

            lines.append("")
            lines.append(exercise.rawValue)

            for gymSet in completedSets {
                lines.append("\(gymSet.setNumber). \(gymSet.weight.workoutNumberFormatted) kg x \(gymSet.reps)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

private extension Double {
    var workoutNumberFormatted: String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }
}
