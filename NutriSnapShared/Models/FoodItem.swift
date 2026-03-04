import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID = UUID()
    var name: String = ""
    var calories: Double = 0
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0
    var grams: Double = 0
    var edamamFoodId: String?

    // Inverse side of MealEntry.foods
    var mealEntry: MealEntry?

    init(
        name: String,
        calories: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        grams: Double,
        edamamFoodId: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.grams = grams
        self.edamamFoodId = edamamFoodId
    }
}
