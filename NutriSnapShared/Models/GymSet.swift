import Foundation
import SwiftData

@Model
final class GymSet {
    var id: UUID
    var exerciseRaw: String
    var weight: Double
    var reps: Int
    var setNumber: Int
    var isCompleted: Bool
    var session: GymSession?

    init(
        exercise: GymExercise,
        weight: Double = 0,
        reps: Int = 12,
        setNumber: Int = 1,
        isCompleted: Bool = false
    ) {
        self.id = UUID()
        self.exerciseRaw = exercise.rawValue
        self.weight = weight
        self.reps = reps
        self.setNumber = setNumber
        self.isCompleted = isCompleted
    }

    var exercise: GymExercise? {
        GymExercise(rawValue: exerciseRaw)
    }
}
