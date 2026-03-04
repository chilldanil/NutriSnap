import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID = UUID()
    var userName: String = ""
    var date: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \MealEntry.dailyLog)
    var meals: [MealEntry] = []

    // Targets (copied from UserProfile when the day is created)
    var targetCalories: Double = 2000
    var targetProtein: Double = 150
    var targetFat: Double = 65
    var targetCarbs: Double = 250

    // Water tracking
    var waterMl: Double = 0
    var waterTarget: Double = 2500

    // MARK: - Computed totals

    var totalCalories: Double { meals.reduce(0) { $0 + $1.totalCalories } }
    var totalProtein: Double  { meals.reduce(0) { $0 + $1.totalProtein } }
    var totalFat: Double      { meals.reduce(0) { $0 + $1.totalFat } }
    var totalCarbs: Double    { meals.reduce(0) { $0 + $1.totalCarbs } }

    var sortedMeals: [MealEntry] {
        meals.sorted { $0.mealType.sortOrder < $1.mealType.sortOrder }
    }

    init(
        date: Date,
        targetCalories: Double = 2000,
        targetProtein: Double = 150,
        targetFat: Double = 65,
        targetCarbs: Double = 250,
        waterTarget: Double = 2500
    ) {
        self.id = UUID()
        self.date = date
        self.targetCalories = targetCalories
        self.targetProtein = targetProtein
        self.targetFat = targetFat
        self.targetCarbs = targetCarbs
        self.waterTarget = waterTarget
    }
}
