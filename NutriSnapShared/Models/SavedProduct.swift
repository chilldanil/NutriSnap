import Foundation
import SwiftData

@Model
final class SavedProduct {
    var id: UUID = UUID()
    var userName: String = ""
    var name: String = ""
    var calories: Double = 0      // per defaultGrams
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0
    var defaultGrams: Double = 100
    var createdAt: Date = Date()

    init(
        name: String,
        calories: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        defaultGrams: Double = 100
    ) {
        self.id = UUID()
        self.name = name
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.defaultGrams = defaultGrams
        self.createdAt = Date()
    }

    /// Create a FoodItem from this saved product template
    func toFoodItem() -> FoodItem {
        FoodItem(
            name: name,
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs,
            grams: defaultGrams
        )
    }
}
