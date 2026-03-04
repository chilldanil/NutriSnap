import AppIntents

struct NutriSnapShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickAddFoodIntent(),
            phrases: [
                "Log food in \(.applicationName)",
                "Add food in \(.applicationName)",
                "Track meal in \(.applicationName)",
            ],
            shortTitle: "Log Food",
            systemImageName: "fork.knife"
        )
    }
}
