import Foundation
import SwiftData
import Supabase

// MARK: - Codable row types for Supabase tables

struct ProfileRow: Codable {
    let userName: String
    let gender: String
    let weight: Double
    let height: Double
    let age: Int
    let goal: String
    let activityLevel: String
    let targetCalories: Double
    let targetProtein: Double
    let targetFat: Double
    let targetCarbs: Double
    let isOnboarded: Bool
    let isHealthKitEnabled: Bool
    let useCustomTargets: Bool
    let waterTarget: Double

    enum CodingKeys: String, CodingKey {
        case userName = "user_name"
        case gender, weight, height, age, goal
        case activityLevel = "activity_level"
        case targetCalories = "target_calories"
        case targetProtein = "target_protein"
        case targetFat = "target_fat"
        case targetCarbs = "target_carbs"
        case isOnboarded = "is_onboarded"
        case isHealthKitEnabled = "is_health_kit_enabled"
        case useCustomTargets = "use_custom_targets"
        case waterTarget = "water_target"
    }
}

struct MealFoodRow: Codable {
    let name: String
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let grams: Double
    let edamamFoodId: String?
}

struct MealRow: Codable {
    let mealType: String
    let foods: [MealFoodRow]
}

struct DailyLogRow: Codable {
    let id: String
    let userName: String
    let date: String               // "yyyy-MM-dd"
    let targetCalories: Double
    let targetProtein: Double
    let targetFat: Double
    let targetCarbs: Double
    let waterMl: Double
    let waterTarget: Double
    let meals: [MealRow]

    enum CodingKeys: String, CodingKey {
        case id
        case userName = "user_name"
        case date
        case targetCalories = "target_calories"
        case targetProtein = "target_protein"
        case targetFat = "target_fat"
        case targetCarbs = "target_carbs"
        case waterMl = "water_ml"
        case waterTarget = "water_target"
        case meals
    }
}

struct SavedProductRow: Codable {
    let id: String
    let userName: String
    let name: String
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let defaultGrams: Double

    enum CodingKeys: String, CodingKey {
        case id, name, calories, protein, fat, carbs
        case userName = "user_name"
        case defaultGrams = "default_grams"
    }
}

// MARK: - Supabase Manager

final class SupabaseManager {
    static let shared = SupabaseManager()

    private let client: SupabaseClient

    private let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    private init() {
        // ⚠️ REPLACE with your Supabase project URL and anon key
        client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
    }

    // MARK: - Push Profile

    func pushProfile(_ profile: UserProfile) {
        let row = ProfileRow(
            userName: profile.userName,
            gender: profile.gender.rawValue,
            weight: profile.weight,
            height: profile.height,
            age: profile.age,
            goal: profile.goal.rawValue,
            activityLevel: profile.activityLevel.rawValue,
            targetCalories: profile.targetCalories,
            targetProtein: profile.targetProtein,
            targetFat: profile.targetFat,
            targetCarbs: profile.targetCarbs,
            isOnboarded: profile.isOnboarded,
            isHealthKitEnabled: profile.isHealthKitEnabled,
            useCustomTargets: profile.useCustomTargets,
            waterTarget: profile.waterTarget
        )

        Task.detached {
            do {
                try await self.client.from("profiles").upsert(row).execute()
            } catch {
                print("[Supabase] pushProfile error: \(error)")
            }
        }
    }

    // MARK: - Push DailyLog

    func pushDailyLog(_ log: DailyLog) {
        guard !log.userName.isEmpty else { return }

        let dateStr = dayFormatter.string(from: log.date)
        let docId = "\(log.userName)_\(dateStr)"

        let mealsData: [MealRow] = log.sortedMeals.map { meal in
            let foods = meal.foods.map { food in
                MealFoodRow(
                    name: food.name,
                    calories: food.calories,
                    protein: food.protein,
                    fat: food.fat,
                    carbs: food.carbs,
                    grams: food.grams,
                    edamamFoodId: food.edamamFoodId
                )
            }
            return MealRow(mealType: meal.mealType.rawValue, foods: foods)
        }

        let row = DailyLogRow(
            id: docId,
            userName: log.userName,
            date: dateStr,
            targetCalories: log.targetCalories,
            targetProtein: log.targetProtein,
            targetFat: log.targetFat,
            targetCarbs: log.targetCarbs,
            waterMl: log.waterMl,
            waterTarget: log.waterTarget,
            meals: mealsData
        )

        Task.detached {
            do {
                try await self.client.from("daily_logs").upsert(row).execute()
            } catch {
                print("[Supabase] pushDailyLog error: \(error)")
            }
        }
    }

    // MARK: - Fetch Profile

    func fetchProfile(userName: String) async -> ProfileRow? {
        do {
            let rows: [ProfileRow] = try await client
                .from("profiles")
                .select()
                .eq("user_name", value: userName)
                .execute()
                .value
            return rows.first
        } catch {
            print("[Supabase] fetchProfile error: \(error)")
            return nil
        }
    }

    // MARK: - Fetch All DailyLogs

    func fetchDailyLogs(userName: String) async -> [DailyLogRow] {
        do {
            let rows: [DailyLogRow] = try await client
                .from("daily_logs")
                .select()
                .eq("user_name", value: userName)
                .execute()
                .value
            return rows
        } catch {
            print("[Supabase] fetchDailyLogs error: \(error)")
            return []
        }
    }

    // MARK: - Restore into SwiftData

    func restoreProfile(from row: ProfileRow, into context: ModelContext) -> UserProfile? {
        let profile = UserProfile(
            gender: Gender(rawValue: row.gender) ?? .male,
            weight: row.weight,
            height: row.height,
            age: row.age,
            goal: Goal(rawValue: row.goal) ?? .maintain,
            activityLevel: ActivityLevel(rawValue: row.activityLevel) ?? .moderate
        )
        profile.userName = row.userName
        profile.targetCalories = row.targetCalories
        profile.targetProtein = row.targetProtein
        profile.targetFat = row.targetFat
        profile.targetCarbs = row.targetCarbs
        profile.isOnboarded = row.isOnboarded
        profile.isHealthKitEnabled = row.isHealthKitEnabled
        profile.useCustomTargets = row.useCustomTargets
        profile.waterTarget = row.waterTarget

        context.insert(profile)
        return profile
    }

    func restoreDailyLogs(from rows: [DailyLogRow], into context: ModelContext) {
        for row in rows {
            guard let date = dayFormatter.date(from: row.date) else { continue }

            let log = DailyLog(
                date: date,
                targetCalories: row.targetCalories,
                targetProtein: row.targetProtein,
                targetFat: row.targetFat,
                targetCarbs: row.targetCarbs,
                waterTarget: row.waterTarget
            )
            log.userName = row.userName
            log.waterMl = row.waterMl

            context.insert(log)

            // Restore meals
            for mealRow in row.meals {
                guard let mealType = MealType(rawValue: mealRow.mealType) else { continue }

                let meal = MealEntry(mealType: mealType, timestamp: date)
                log.meals.append(meal)

                for foodRow in mealRow.foods {
                    let food = FoodItem(
                        name: foodRow.name,
                        calories: foodRow.calories,
                        protein: foodRow.protein,
                        fat: foodRow.fat,
                        carbs: foodRow.carbs,
                        grams: foodRow.grams,
                        edamamFoodId: foodRow.edamamFoodId
                    )
                    meal.foods.append(food)
                }
            }

            // Ensure all 4 meal types exist
            let existingTypes = Set(log.meals.map(\.mealType))
            for type in MealType.allCases where !existingTypes.contains(type) {
                let emptyMeal = MealEntry(mealType: type, timestamp: date)
                log.meals.append(emptyMeal)
            }
        }
    }

    // MARK: - Push SavedProduct

    func pushSavedProduct(_ product: SavedProduct) {
        guard !product.userName.isEmpty else { return }

        let row = SavedProductRow(
            id: product.id.uuidString,
            userName: product.userName,
            name: product.name,
            calories: product.calories,
            protein: product.protein,
            fat: product.fat,
            carbs: product.carbs,
            defaultGrams: product.defaultGrams
        )

        Task.detached {
            do {
                try await self.client.from("saved_products").upsert(row).execute()
            } catch {
                print("[Supabase] pushSavedProduct error: \(error)")
            }
        }
    }

    // MARK: - Delete SavedProduct

    func deleteSavedProduct(id: String) {
        Task.detached {
            do {
                try await self.client.from("saved_products")
                    .delete()
                    .eq("id", value: id)
                    .execute()
            } catch {
                print("[Supabase] deleteSavedProduct error: \(error)")
            }
        }
    }

    // MARK: - Fetch SavedProducts

    func fetchSavedProducts(userName: String) async -> [SavedProductRow] {
        do {
            let rows: [SavedProductRow] = try await client
                .from("saved_products")
                .select()
                .eq("user_name", value: userName)
                .execute()
                .value
            return rows
        } catch {
            print("[Supabase] fetchSavedProducts error: \(error)")
            return []
        }
    }

    // MARK: - Restore SavedProducts

    func restoreSavedProducts(from rows: [SavedProductRow], into context: ModelContext) {
        for row in rows {
            let product = SavedProduct(
                name: row.name,
                calories: row.calories,
                protein: row.protein,
                fat: row.fat,
                carbs: row.carbs,
                defaultGrams: row.defaultGrams
            )
            if let uuid = UUID(uuidString: row.id) {
                product.id = uuid
            }
            product.userName = row.userName
            context.insert(product)
        }
    }
}
