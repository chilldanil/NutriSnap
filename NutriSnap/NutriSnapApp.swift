import SwiftUI
import SwiftData
import ActivityKit

@main
struct NutriSnapApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        do {
            return try SharedModelContainer.create()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                scheduleMidnightEnd()
            }
        }
    }

    private func scheduleMidnightEnd() {
        let calendar = Calendar.current
        guard let midnight = calendar.date(
            byAdding: .day, value: 1,
            to: calendar.startOfDay(for: Date())
        ) else { return }

        let interval = midnight.timeIntervalSinceNow
        guard interval > 0 else { return }

        Task {
            try? await Task.sleep(for: .seconds(interval))
            await LiveActivityManager.shared.endAllActivities()
        }
    }
}
