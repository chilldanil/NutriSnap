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
}
