import Foundation

// MARK: - Meal Type

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "leaf.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .breakfast: 0
        case .lunch: 1
        case .dinner: 2
        case .snack: 3
        }
    }
}

// MARK: - Goal

enum Goal: String, Codable, CaseIterable, Identifiable {
    case lose = "Lose Weight"
    case maintain = "Maintain"
    case gain = "Gain Weight"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .lose: "arrow.down.circle.fill"
        case .maintain: "equal.circle.fill"
        case .gain: "arrow.up.circle.fill"
        }
    }

    var emoji: String {
        switch self {
        case .lose: "🔥"
        case .maintain: "⚖️"
        case .gain: "💪"
        }
    }

    var subtitle: String {
        switch self {
        case .lose: "Calorie deficit for fat loss"
        case .maintain: "Keep your current weight"
        case .gain: "Calorie surplus for muscle"
        }
    }

    var calorieAdjustment: Double {
        switch self {
        case .lose: -500
        case .maintain: 0
        case .gain: 300
        }
    }

    var proteinPerKg: Double {
        switch self {
        case .lose: 2.2
        case .maintain: 1.8
        case .gain: 2.0
        }
    }
}

// MARK: - Activity Level

enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case sedentary = "Sedentary"
    case light = "Lightly Active"
    case moderate = "Moderately Active"
    case active = "Active"
    case veryActive = "Very Active"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .sedentary: "Little or no exercise"
        case .light: "Exercise 1–3 days/week"
        case .moderate: "Exercise 3–5 days/week"
        case .active: "Exercise 6–7 days/week"
        case .veryActive: "Hard exercise 2×/day"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}

// MARK: - Gender

enum Gender: String, Codable, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"

    var id: String { rawValue }
}

// MARK: - Gym Exercises

enum GymExercise: String, Codable, CaseIterable, Identifiable {
    case schulterpresse = "Schulterpresse"
    case latzug = "Latzug"
    case bizeps = "Bizeps"
    case bauchtrainer = "Bauchtrainer"
    case beinstrecker = "Beinstrecker"
    case beinbeuger = "Beinbeuger"
    case ruderzug = "Ruderzug"
    case brustpresse = "Brustpresse"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .schulterpresse: "Shoulder Press"
        case .latzug: "Lat Pulldown"
        case .bizeps: "Bicep Curl"
        case .bauchtrainer: "Ab Trainer"
        case .beinstrecker: "Leg Extension"
        case .beinbeuger: "Leg Curl"
        case .ruderzug: "Seated Row"
        case .brustpresse: "Chest Press"
        }
    }

    var icon: String {
        switch self {
        case .schulterpresse: "figure.arms.open"
        case .latzug: "figure.rowing"
        case .bizeps: "figure.strengthtraining.traditional"
        case .bauchtrainer: "figure.core.training"
        case .beinstrecker: "figure.walk"
        case .beinbeuger: "figure.step.training"
        case .ruderzug: "figure.rower"
        case .brustpresse: "figure.highintensity.intervaltraining"
        }
    }

    var muscleGroup: String {
        switch self {
        case .schulterpresse: "Shoulders"
        case .latzug, .ruderzug: "Back"
        case .bizeps: "Arms"
        case .bauchtrainer: "Core"
        case .beinstrecker, .beinbeuger: "Legs"
        case .brustpresse: "Chest"
        }
    }
}

// MARK: - App Users (hardcoded for 2 people)

enum AppUser: String, CaseIterable, Identifiable {
    case daniil = "daniil"
    case daria = "daria"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daniil: "Daniil"
        case .daria: "Daria"
        }
    }

    var emoji: String {
        switch self {
        case .daniil: "\u{1F468}\u{200D}\u{1F4BB}"
        case .daria: "\u{1F469}\u{200D}\u{1F4BB}"
        }
    }

    var defaultGender: Gender {
        switch self {
        case .daniil: .male
        case .daria: .female
        }
    }
}
