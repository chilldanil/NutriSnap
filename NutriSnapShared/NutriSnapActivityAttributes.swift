import ActivityKit
import Foundation

struct NutriSnapActivityAttributes: ActivityAttributes {
    /// Dynamic data that updates throughout the day
    struct ContentState: Codable, Hashable {
        var calories: Double
        var targetCalories: Double
        var protein: Double
        var targetProtein: Double
        var fat: Double
        var targetFat: Double
        var carbs: Double
        var targetCarbs: Double
        var waterMl: Double
        var waterTarget: Double
    }

    /// Fixed context — set once when the activity starts
    var startDate: Date
}
