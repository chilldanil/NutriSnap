import Foundation
import SwiftData

@Model
final class BodyMeasurement {
    var id: UUID
    var userName: String
    var date: Date

    // Main
    var weight: Double?
    var bodyFat: Double?

    // Measurements (cm)
    var chest: Double?
    var waist: Double?
    var hips: Double?
    var neck: Double?
    var bicep: Double?
    var thigh: Double?

    var createdAt: Date

    init(
        userName: String,
        date: Date = Date(),
        weight: Double? = nil,
        bodyFat: Double? = nil,
        chest: Double? = nil,
        waist: Double? = nil,
        hips: Double? = nil,
        neck: Double? = nil,
        bicep: Double? = nil,
        thigh: Double? = nil
    ) {
        self.id = UUID()
        self.userName = userName
        self.date = date
        self.weight = weight
        self.bodyFat = bodyFat
        self.chest = chest
        self.waist = waist
        self.hips = hips
        self.neck = neck
        self.bicep = bicep
        self.thigh = thigh
        self.createdAt = Date()
    }

    /// All optional measurement fields as label/value pairs, for display.
    var filledMeasurements: [(label: String, value: Double, unit: String)] {
        var result: [(String, Double, String)] = []
        if let v = chest  { result.append(("Chest", v, "cm")) }
        if let v = waist  { result.append(("Waist", v, "cm")) }
        if let v = hips   { result.append(("Hips", v, "cm")) }
        if let v = neck   { result.append(("Neck", v, "cm")) }
        if let v = bicep  { result.append(("Bicep", v, "cm")) }
        if let v = thigh  { result.append(("Thigh", v, "cm")) }
        return result
    }

    var hasAnyMeasurement: Bool {
        weight != nil || bodyFat != nil || chest != nil || waist != nil ||
        hips != nil || neck != nil || bicep != nil || thigh != nil
    }
}
