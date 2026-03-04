import AppIntents

struct QuickAddFoodIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Food"
    static var description: IntentDescription = "Open NutriSnap to quickly log a food item"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NavigationState.shared.shouldOpenAddFood = true
        return .result()
    }
}
