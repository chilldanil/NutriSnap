import HealthKit
import Foundation

actor HealthKitManager {
    static let shared = HealthKitManager()

    private let store = HKHealthStore()

    private let dietaryTypes: Set<HKSampleType> = [
        HKQuantityType(.dietaryEnergyConsumed),
        HKQuantityType(.dietaryProtein),
        HKQuantityType(.dietaryFatTotal),
        HKQuantityType(.dietaryCarbohydrates),
        HKQuantityType(.dietaryWater),
    ]

    /// Types we only read (energy burned from Apple Watch / iPhone motion)
    private let readOnlyTypes: Set<HKSampleType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.basalEnergyBurned),
    ]

    nonisolated var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: - Authorization

    func requestAuthorization() async throws {
        guard isAvailable else { return }
        // Write: dietary samples. Read: dietary + energy burned.
        let allReadTypes: Set<HKObjectType> = Set(dietaryTypes.map { $0 as HKObjectType })
            .union(readOnlyTypes.map { $0 as HKObjectType })
        try await store.requestAuthorization(toShare: dietaryTypes, read: allReadTypes)
    }

    // MARK: - Write dietary samples

    /// Save one food item as four HK samples (cal, protein, fat, carbs)
    func saveFoodItem(
        calories: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        date: Date = Date()
    ) async throws {
        guard isAvailable else { return }

        let samples = buildSamples(
            calories: calories,
            protein: protein,
            fat: fat,
            carbs: carbs,
            date: date
        )
        guard !samples.isEmpty else { return }
        try await store.save(samples)
    }

    // MARK: - Write water

    func saveWater(ml: Double, date: Date = Date()) async throws {
        guard isAvailable, ml > 0 else { return }
        let sample = HKQuantitySample(
            type: HKQuantityType(.dietaryWater),
            quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml),
            start: date, end: date
        )
        try await store.save(sample)
    }

    // MARK: - Read today's totals (for verification)

    func todayTotals() async throws -> (cal: Double, pro: Double, fat: Double, carbs: Double) {
        guard isAvailable else { return (0, 0, 0, 0) }

        let start = Calendar.current.startOfDay(for: Date())
        let end = Date()

        async let cal  = sumQuantity(.dietaryEnergyConsumed, unit: .kilocalorie(), start: start, end: end)
        async let pro  = sumQuantity(.dietaryProtein, unit: .gram(), start: start, end: end)
        async let fat  = sumQuantity(.dietaryFatTotal, unit: .gram(), start: start, end: end)
        async let carb = sumQuantity(.dietaryCarbohydrates, unit: .gram(), start: start, end: end)

        return try await (cal, pro, fat, carb)
    }

    // MARK: - Read today's calories burned

    /// Returns today's energy expenditure from HealthKit.
    /// - `active`: Exercise/movement calories (activeEnergyBurned).
    ///   Tracked by Apple Watch accelerometer + heart rate, or iPhone motion coprocessor.
    /// - `basal`: Resting metabolic rate calories (basalEnergyBurned).
    ///   Apple Watch estimates this from user profile (age, weight, height, sex).
    ///   If no Apple Watch, this will be 0.
    /// - TDEE (Total Daily Energy Expenditure) = active + basal
    func todayCaloriesBurned() async throws -> (active: Double, basal: Double) {
        guard isAvailable else { return (0, 0) }

        let start = Calendar.current.startOfDay(for: Date())
        let end = Date()

        async let active = sumQuantity(.activeEnergyBurned, unit: .kilocalorie(), start: start, end: end)
        async let basal  = sumQuantity(.basalEnergyBurned, unit: .kilocalorie(), start: start, end: end)

        return try await (active, basal)
    }

    // MARK: - Helpers

    private func buildSamples(
        calories: Double,
        protein: Double,
        fat: Double,
        carbs: Double,
        date: Date
    ) -> [HKQuantitySample] {
        var samples: [HKQuantitySample] = []

        if calories > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.dietaryEnergyConsumed),
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                start: date, end: date
            ))
        }
        if protein > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.dietaryProtein),
                quantity: HKQuantity(unit: .gram(), doubleValue: protein),
                start: date, end: date
            ))
        }
        if fat > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.dietaryFatTotal),
                quantity: HKQuantity(unit: .gram(), doubleValue: fat),
                start: date, end: date
            ))
        }
        if carbs > 0 {
            samples.append(HKQuantitySample(
                type: HKQuantityType(.dietaryCarbohydrates),
                quantity: HKQuantity(unit: .gram(), doubleValue: carbs),
                start: date, end: date
            ))
        }

        return samples
    }

    private func sumQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double {
        let type = HKQuantityType(identifier)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum
        )
        let result = try await descriptor.result(for: store)
        return result?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }
}
