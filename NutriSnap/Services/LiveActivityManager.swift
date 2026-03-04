import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<NutriSnapActivityAttributes>?

    private init() {
        // Reconnect to any existing activity from a previous launch
        currentActivity = Activity<NutriSnapActivityAttributes>.activities.first
    }

    // MARK: - Start

    func startActivity(from log: DailyLog) {
        // If one is already running, just update it
        guard currentActivity == nil else {
            updateActivity(from: log)
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = NutriSnapActivityAttributes(startDate: Date())
        let state = contentState(from: log)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }

    // MARK: - Update

    func updateActivity(from log: DailyLog) {
        guard let activity = currentActivity else {
            startActivity(from: log)
            return
        }

        let state = contentState(from: log)

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    // MARK: - End

    func endActivity() {
        guard let activity = currentActivity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            self.currentActivity = nil
        }
    }

    // MARK: - End all (cleanup at midnight)

    func endAllActivities() {
        Task {
            for activity in Activity<NutriSnapActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            currentActivity = nil
        }
    }

    // MARK: - Helpers

    private func contentState(from log: DailyLog) -> NutriSnapActivityAttributes.ContentState {
        .init(
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
}
