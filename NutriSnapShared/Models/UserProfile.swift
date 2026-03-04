import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID = UUID()
    var userName: String = ""
    var gender: Gender = Gender.male
    var weight: Double = 70        // kg
    var height: Double = 175       // cm
    var age: Int = 25
    var goal: Goal = Goal.maintain
    var activityLevel: ActivityLevel = ActivityLevel.moderate

    // Calculated targets
    var targetCalories: Double = 2000
    var targetProtein: Double = 150
    var targetFat: Double = 65
    var targetCarbs: Double = 250

    var isOnboarded: Bool = false
    var isHealthKitEnabled: Bool = false
    var useCustomTargets: Bool = false
    var waterTarget: Double = 2500  // ml

    init(
        gender: Gender = .male,
        weight: Double = 70,
        height: Double = 175,
        age: Int = 25,
        goal: Goal = .maintain,
        activityLevel: ActivityLevel = .moderate
    ) {
        self.id = UUID()
        self.gender = gender
        self.weight = weight
        self.height = height
        self.age = age
        self.goal = goal
        self.activityLevel = activityLevel
    }

    /// Recalculate targets from current profile values
    func recalculateTargets() {
        let targets = NutritionCalculator.calculate(
            gender: gender,
            weight: weight,
            height: height,
            age: age,
            goal: goal,
            activityLevel: activityLevel
        )
        targetCalories = targets.calories
        targetProtein  = targets.protein
        targetFat      = targets.fat
        targetCarbs    = targets.carbs
    }
}
