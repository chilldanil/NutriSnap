import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry

struct NutriSnapEntry: TimelineEntry {
    let date: Date
    let calories: Double
    let targetCalories: Double
    let protein: Double
    let targetProtein: Double
    let fat: Double
    let targetFat: Double
    let carbs: Double
    let targetCarbs: Double
    let waterMl: Double
    let waterTarget: Double

    static var placeholder: NutriSnapEntry {
        NutriSnapEntry(
            date: Date(),
            calories: 1200, targetCalories: 2000,
            protein: 80, targetProtein: 150,
            fat: 40, targetFat: 65,
            carbs: 130, targetCarbs: 250,
            waterMl: 1500, waterTarget: 2500
        )
    }
}

// MARK: - Timeline Provider

struct NutriSnapTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> NutriSnapEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (NutriSnapEntry) -> Void) {
        completion(fetchEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NutriSnapEntry>) -> Void) {
        let entry = fetchEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    @MainActor
    private func fetchEntry() -> NutriSnapEntry {
        guard let container = try? SharedModelContainer.create() else {
            return .placeholder
        }

        let context = container.mainContext
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let currentUser = UserDefaults(suiteName: "group.com.daniil.NutriSnap")?.string(forKey: "currentUser") ?? ""

        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate<DailyLog> { log in
                log.date >= startOfDay && log.date < nextDay
                    && log.userName == currentUser
            }
        )

        if let log = try? context.fetch(descriptor).first {
            return NutriSnapEntry(
                date: Date(),
                calories: log.totalCalories,
                targetCalories: log.targetCalories,
                protein: log.totalProtein,
                targetProtein: log.targetProtein,
                fat: log.totalFat,
                targetFat: log.targetFat,
                carbs: log.totalCarbs,
                targetCarbs: log.targetCarbs,
                waterMl: log.waterMl,
                waterTarget: log.waterTarget
            )
        }

        return .placeholder
    }
}

// MARK: - Widget Configuration

struct NutriSnapWidget: Widget {
    let kind: String = "NutriSnapWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NutriSnapTimelineProvider()) { entry in
            NutriSnapWidgetEntryView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("NutriSnap")
        .description("Track your daily nutrition at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
