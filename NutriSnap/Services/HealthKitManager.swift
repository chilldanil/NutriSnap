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

    private let bodyTypes: Set<HKSampleType> = [
        HKQuantityType(.bodyMass),
        HKQuantityType(.bodyFatPercentage),
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
        let writeTypes = dietaryTypes.union(bodyTypes)
        let allReadTypes: Set<HKObjectType> = Set(dietaryTypes.map { $0 as HKObjectType })
            .union(readOnlyTypes.map { $0 as HKObjectType })
            .union(bodyTypes.map { $0 as HKObjectType })
        try await store.requestAuthorization(toShare: writeTypes, read: allReadTypes)
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

    // MARK: - Write body measurements

    func saveWeight(kg: Double, date: Date = Date()) async throws {
        guard isAvailable, kg > 0 else { return }
        let sample = HKQuantitySample(
            type: HKQuantityType(.bodyMass),
            quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
            start: date, end: date
        )
        try await store.save(sample)
    }

    func saveBodyFat(percent: Double, date: Date = Date()) async throws {
        guard isAvailable, percent > 0 else { return }
        let sample = HKQuantitySample(
            type: HKQuantityType(.bodyFatPercentage),
            quantity: HKQuantity(unit: .percent(), doubleValue: percent / 100),
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

    /// Returns energy expenditure for a specific date from HealthKit.
    func caloriesBurned(for date: Date) async throws -> (active: Double, basal: Double) {
        guard isAvailable else { return (0, 0) }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end: Date
        if calendar.isDateInToday(date) {
            end = Date()
        } else {
            end = calendar.date(byAdding: .day, value: 1, to: start)!
        }

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
