import Foundation
import SwiftData
import WidgetKit

@Observable
final class DailyLogViewModel {
    private var modelContext: ModelContext
    var todayLog: DailyLog?
    var isHealthKitEnabled: Bool = false

    // MARK: - HealthKit burned calories (read from Apple Watch / iPhone)
    var activeCaloriesBurned: Double = 0   // Exercise & movement
    var basalCaloriesBurned: Double = 0    // Resting metabolic rate (BMR)

    /// TDEE = Total Daily Energy Expenditure (active + basal)
    var totalCaloriesBurned: Double { activeCaloriesBurned + basalCaloriesBurned }

    /// Net energy balance: consumed - burned. Negative = deficit, Positive = surplus.
    var netEnergyBalance: Double {
        (todayLog?.totalCalories ?? 0) - totalCaloriesBurned
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Load / create today

    func loadToday(profile: UserProfile?, userName: String = "") {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate<DailyLog> { log in
                log.date >= startOfDay && log.date < nextDay
                    && log.userName == userName
            }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            // Sync targets from profile in case user edited them
            if let profile {
                let targetsChanged = existing.targetCalories != profile.targetCalories
                    || existing.targetProtein != profile.targetProtein
                    || existing.targetFat != profile.targetFat
                    || existing.targetCarbs != profile.targetCarbs
                    || existing.waterTarget != profile.waterTarget

                if targetsChanged {
                    existing.targetCalories = profile.targetCalories
                    existing.targetProtein  = profile.targetProtein
                    existing.targetFat      = profile.targetFat
                    existing.targetCarbs    = profile.targetCarbs
                    existing.waterTarget    = profile.waterTarget
                    try? modelContext.save()
                    // Delay push so SwiftData relationships (meals/foods) are fully loaded
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        SupabaseManager.shared.pushDailyLog(existing)
                    }
                }
            }
            todayLog = existing
            // Start or reconnect Live Activity
            LiveActivityManager.shared.startActivity(from: existing)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        // Create a fresh daily log with 4 meal slots
        let newLog = DailyLog(
            date: startOfDay,
            targetCalories: profile?.targetCalories ?? 2000,
            targetProtein:  profile?.targetProtein  ?? 150,
            targetFat:      profile?.targetFat      ?? 65,
            targetCarbs:    profile?.targetCarbs    ?? 250,
            waterTarget:    profile?.waterTarget    ?? 2500
        )
        newLog.userName = userName

        for type in MealType.allCases {
            let meal = MealEntry(mealType: type, timestamp: startOfDay)
            newLog.meals.append(meal)
        }

        modelContext.insert(newLog)
        try? modelContext.save()
        SupabaseManager.shared.pushDailyLog(newLog)
        todayLog = newLog

        // Start Live Activity for the new day
        LiveActivityManager.shared.startActivity(from: newLog)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Food CRUD

    func addFood(_ food: FoodItem, to mealType: MealType) {
        guard let log = todayLog,
              let meal = log.meals.first(where: { $0.mealType == mealType }) else { return }

        meal.foods.append(food)
        try? modelContext.save()
        SupabaseManager.shared.pushDailyLog(log)

        // Update widget & Live Activity
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityManager.shared.updateActivity(from: log)

        // Sync to HealthKit
        if isHealthKitEnabled {
            let cal = food.calories
            let pro = food.protein
            let fat = food.fat
            let carbs = food.carbs
            Task.detached {
                try? await HealthKitManager.shared.saveFoodItem(
                    calories: cal, protein: pro, fat: fat, carbs: carbs
                )
            }
        }
    }

    /// Add multiple food items at once (from AI meal description)
    func addFoods(_ foods: [FoodItem], to mealType: MealType) {
        guard let log = todayLog,
              let meal = log.meals.first(where: { $0.mealType == mealType }) else { return }

        for food in foods {
            meal.foods.append(food)
        }
        try? modelContext.save()
        SupabaseManager.shared.pushDailyLog(log)

        // Update widget & Live Activity
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityManager.shared.updateActivity(from: log)

        // Sync all to HealthKit
        if isHealthKitEnabled {
            let items = foods.map { (cal: $0.calories, pro: $0.protein, fat: $0.fat, carbs: $0.carbs) }
            Task.detached {
                for item in items {
                    try? await HealthKitManager.shared.saveFoodItem(
                        calories: item.cal, protein: item.pro, fat: item.fat, carbs: item.carbs
                    )
                }
            }
        }
    }

    func updateFood(_ food: FoodItem, grams: Double, calories: Double, protein: Double, fat: Double, carbs: Double) {
        guard let log = todayLog else { return }

        // Capture old values for HealthKit delta correction
        let oldCal = food.calories
        let oldPro = food.protein
        let oldFat = food.fat
        let oldCarbs = food.carbs

        food.grams = grams
        food.calories = calories
        food.protein = protein
        food.fat = fat
        food.carbs = carbs
        try? modelContext.save()
        SupabaseManager.shared.pushDailyLog(log)

        // Update widget & Live Activity
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityManager.shared.updateActivity(from: log)

        // Sync the difference to HealthKit (positive delta only; negatives are HealthKit limitation)
        if isHealthKitEnabled {
            let dCal = calories - oldCal
            let dPro = protein - oldPro
            let dFat = fat - oldFat
            let dCarbs = carbs - oldCarbs
            // Only write if there's a positive increase (HealthKit appends, can't subtract)
            if dCal > 0 || dPro > 0 || dFat > 0 || dCarbs > 0 {
                Task.detached {
                    try? await HealthKitManager.shared.saveFoodItem(
                        calories: max(0, dCal),
                        protein: max(0, dPro),
                        fat: max(0, dFat),
                        carbs: max(0, dCarbs)
                    )
                }
            }
        }
    }

    func removeFood(_ food: FoodItem, from mealType: MealType) {
        guard let log = todayLog,
              let meal = log.meals.first(where: { $0.mealType == mealType }) else { return }

        meal.foods.removeAll { $0.id == food.id }
        modelContext.delete(food)
        try? modelContext.save()
        SupabaseManager.shared.pushDailyLog(log)

        // Update widget & Live Activity
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityManager.shared.updateActivity(from: log)
    }

    // MARK: - Water

    func addWater(_ ml: Double) {
        guard let log = todayLog else { return }
        log.waterMl += ml
        try? modelContext.save()
        SupabaseManager.shared.pushDailyLog(log)

        // Update widget & Live Activity
        WidgetCenter.shared.reloadAllTimelines()
        LiveActivityManager.shared.updateActivity(from: log)

        if isHealthKitEnabled {
            Task.detached {
                try? await HealthKitManager.shared.saveWater(ml: ml)
            }
        }
    }

    // MARK: - HealthKit: fetch burned calories

    func fetchBurnedCalories() {
        guard isHealthKitEnabled else { return }
        Task.detached {
            do {
                let burned = try await HealthKitManager.shared.todayCaloriesBurned()
                await MainActor.run {
                    self.activeCaloriesBurned = burned.active
                    self.basalCaloriesBurned = burned.basal
                }
            } catch {
                print("[HealthKit] fetchBurnedCalories error: \(error)")
            }
        }
    }

    // MARK: - Copy My Day

    func copyDayToClipboard() -> String {
        guard let log = todayLog else { return "" }
        return Self.formatDayText(
            log: log,
            activeCalories: activeCaloriesBurned,
            basalCalories: basalCaloriesBurned
        )
    }

    /// Reusable: format any DailyLog as shareable text.
    /// Can be called from HistoryView or anywhere else.
    static func formatDayText(
        log: DailyLog,
        activeCalories: Double = 0,
        basalCalories: Double = 0
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMMM yyyy"
        let dateStr = dateFormatter.string(from: log.date)

        var lines: [String] = []
        lines.append("My Day \u{2014} \(dateStr)")
        lines.append("")
        lines.append("Targets: \(Int(log.targetCalories)) kcal | P: \(Int(log.targetProtein))g | F: \(Int(log.targetFat))g | C: \(Int(log.targetCarbs))g")
        lines.append("")

        let mealIcons: [MealType: String] = [
            .breakfast: "Breakfast",
            .lunch: "Lunch",
            .dinner: "Dinner",
            .snack: "Snack"
        ]

        for meal in log.sortedMeals {
            let header = mealIcons[meal.mealType] ?? meal.mealType.rawValue
            lines.append("\(header):")

            if meal.foods.isEmpty {
                lines.append("  (empty)")
            } else {
                for food in meal.foods {
                    let line = "  - \(food.name): \(Int(food.calories)) kcal | P: \(fmtG(food.protein)) | F: \(fmtG(food.fat)) | C: \(fmtG(food.carbs)) (\(Int(food.grams))g)"
                    lines.append(line)
                }
                lines.append("  Total: \(Int(meal.totalCalories)) kcal | P: \(fmtG(meal.totalProtein)) | F: \(fmtG(meal.totalFat)) | C: \(fmtG(meal.totalCarbs))")
            }
            lines.append("")
        }

        lines.append("Day Total: \(Int(log.totalCalories)) kcal | P: \(fmtG(log.totalProtein)) | F: \(fmtG(log.totalFat)) | C: \(fmtG(log.totalCarbs))")
        lines.append("Water: \(Int(log.waterMl)) / \(Int(log.waterTarget)) ml")

        let totalBurned = activeCalories + basalCalories
        if totalBurned > 0 {
            lines.append("")
            lines.append("Calories Burned: \(Int(totalBurned)) kcal (Active: \(Int(activeCalories)) + BMR: \(Int(basalCalories)))")
            let net = Int(log.totalCalories - totalBurned)
            let label = net < 0 ? "deficit" : net > 0 ? "surplus" : "balance"
            lines.append("Net: \(Int(log.totalCalories)) - \(Int(totalBurned)) = \(net) kcal (\(label))")
        }

        return lines.joined(separator: "\n")
    }

    private static func fmtG(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))g"
            : String(format: "%.1fg", value)
    }
}
