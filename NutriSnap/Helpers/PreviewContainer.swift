import SwiftData
import Foundation

@MainActor
struct PreviewContainer {

    static let shared: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: FoodItem.self, MealEntry.self, DailyLog.self, UserProfile.self,
            configurations: config
        )
        addSampleData(to: container.mainContext)
        return container
    }()

    // MARK: - Sample data for previews & development

    static func addSampleData(to context: ModelContext) {
        // Profile
        let profile = UserProfile(
            gender: .male, weight: 80, height: 180, age: 28,
            goal: .lose, activityLevel: .moderate
        )
        profile.recalculateTargets()
        profile.isOnboarded = true
        context.insert(profile)

        // Today's log
        let today = Calendar.current.startOfDay(for: Date())
        let log = DailyLog(
            date: today,
            targetCalories: profile.targetCalories,
            targetProtein: profile.targetProtein,
            targetFat: profile.targetFat,
            targetCarbs: profile.targetCarbs
        )
        context.insert(log)

        // Breakfast
        let breakfast = MealEntry(mealType: .breakfast, timestamp: today)
        log.meals.append(breakfast)
        let oatmeal = FoodItem(name: "Oatmeal", calories: 307, protein: 11, fat: 5, carbs: 55, grams: 250)
        let banana = FoodItem(name: "Banana", calories: 89, protein: 1.1, fat: 0.3, carbs: 23, grams: 120)
        breakfast.foods.append(contentsOf: [oatmeal, banana])

        // Lunch
        let lunch = MealEntry(mealType: .lunch, timestamp: today)
        log.meals.append(lunch)
        let chicken = FoodItem(name: "Chicken Breast", calories: 330, protein: 62, fat: 7, carbs: 0, grams: 200)
        let rice = FoodItem(name: "Brown Rice", calories: 216, protein: 5, fat: 1.8, carbs: 45, grams: 200)
        let salad = FoodItem(name: "Mixed Salad", calories: 45, protein: 2, fat: 0.5, carbs: 8, grams: 150)
        lunch.foods.append(contentsOf: [chicken, rice, salad])

        // Dinner (empty)
        let dinner = MealEntry(mealType: .dinner, timestamp: today)
        log.meals.append(dinner)

        // Snack
        let snack = MealEntry(mealType: .snack, timestamp: today)
        log.meals.append(snack)
        let almonds = FoodItem(name: "Almonds", calories: 164, protein: 6, fat: 14, carbs: 6, grams: 28)
        snack.foods.append(almonds)

        try? context.save()
    }
}
