import Foundation
import SwiftData

@Model
final class MealEntry {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var mealType: MealType = MealType.snack
    var photoData: Data?

    @Relationship(deleteRule: .cascade, inverse: \FoodItem.mealEntry)
    var foods: [FoodItem] = []

    // Inverse side of DailyLog.meals
    var dailyLog: DailyLog?

    // MARK: - Computed totals

    var totalCalories: Double { foods.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double  { foods.reduce(0) { $0 + $1.protein } }
    var totalFat: Double      { foods.reduce(0) { $0 + $1.fat } }
    var totalCarbs: Double    { foods.reduce(0) { $0 + $1.carbs } }

    init(mealType: MealType, timestamp: Date = Date()) {
        self.id = UUID()
        self.mealType = mealType
        self.timestamp = timestamp
    }
}
