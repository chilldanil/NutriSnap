import Foundation

struct NutritionCalculator {

    struct Targets {
        let calories: Double
        let protein: Double
        let fat: Double
        let carbs: Double
    }

    /// Mifflin-St Jeor equation → TDEE → macro split
    static func calculate(
        gender: Gender,
        weight: Double,   // kg
        height: Double,   // cm
        age: Int,
        goal: Goal,
        activityLevel: ActivityLevel
    ) -> Targets {
        // 1. Basal Metabolic Rate (Mifflin-St Jeor)
        let bmr: Double
        switch gender {
        case .male:
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) + 5
        case .female:
            bmr = 10 * weight + 6.25 * height - 5 * Double(age) - 161
        }

        // 2. Total Daily Energy Expenditure
        let tdee = bmr * activityLevel.multiplier

        // 3. Calorie target (adjusted for goal, floor at 1200)
        let targetCalories = max(1200, tdee + goal.calorieAdjustment)

        // 4. Macros
        //    Protein: goal-dependent g/kg
        //    Fat:     25 % of calories
        //    Carbs:   remainder
        let proteinGrams    = weight * goal.proteinPerKg
        let proteinCalories = proteinGrams * 4

        let fatCalories = targetCalories * 0.25
        let fatGrams    = fatCalories / 9

        let carbCalories = targetCalories - proteinCalories - fatCalories
        let carbGrams    = max(0, carbCalories / 4)

        return Targets(
            calories: targetCalories.rounded(),
            protein:  proteinGrams.rounded(),
            fat:      fatGrams.rounded(),
            carbs:    carbGrams.rounded()
        )
    }
}
