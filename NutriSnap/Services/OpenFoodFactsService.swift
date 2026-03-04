import Foundation

/// Queries the OpenFoodFacts database by barcode.
/// Great coverage for European / German products (3M+ entries).
actor OpenFoodFactsService {
    static let shared = OpenFoodFactsService()

    struct ProductResult: Sendable {
        let barcode: String
        let name: String
        let brand: String?
        let caloriesPer100g: Double
        let proteinPer100g: Double
        let fatPer100g: Double
        let carbsPer100g: Double
        let servingGrams: Double?
        let imageURL: String?
    }

    enum OFFError: LocalizedError {
        case notFound
        case networkError(String)
        case missingNutrition

        var errorDescription: String? {
            switch self {
            case .notFound:            return "Product not found in database"
            case .networkError(let m): return m
            case .missingNutrition:    return "No nutrition data for this product"
            }
        }
    }

    func lookupBarcode(_ barcode: String) async throws -> ProductResult {
        let cleaned = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            throw OFFError.networkError("Empty barcode")
        }

        var components = URLComponents(string: "https://world.openfoodfacts.net/api/v2/product/\(cleaned).json")
        components?.queryItems = [
            URLQueryItem(name: "fields", value: "product_name,product_name_de,brands,nutriments,serving_size,serving_quantity,image_front_small_url")
        ]

        guard let url = components?.url else {
            throw OFFError.networkError("Invalid barcode: \(cleaned)")
        }

        var request = URLRequest(url: url)
        request.setValue("NutriSnap iOS App - github.com/nutrisnap", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw OFFError.networkError("Network error: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw OFFError.networkError("Invalid response")
        }
        guard http.statusCode == 200 else {
            throw OFFError.networkError("Server returned \(http.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OFFError.networkError("Invalid JSON response")
        }

        let status = (json["status"] as? Int)
            ?? (json["status"] as? NSNumber)?.intValue
        guard status == 1 else {
            throw OFFError.notFound
        }

        guard let product = json["product"] as? [String: Any] else {
            throw OFFError.notFound
        }

        let nameDe = product["product_name_de"] as? String
        let nameGeneric = product["product_name"] as? String
        let name = [nameDe, nameGeneric]
            .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .first(where: { !$0.isEmpty }) ?? "Unknown Product"

        let brand = (product["brands"] as? String)?
            .trimmingCharacters(in: .whitespaces)

        guard let nutriments = product["nutriments"] as? [String: Any] else {
            throw OFFError.missingNutrition
        }

        let protein = nutrimentDouble(nutriments, key: "proteins_100g")
        let fat     = nutrimentDouble(nutriments, key: "fat_100g")
        let carbs   = nutrimentDouble(nutriments, key: "carbohydrates_100g")

        var calories = nutrimentDouble(nutriments, key: "energy-kcal_100g")
        if calories == 0 {
            let kj = nutrimentDouble(nutriments, key: "energy_100g")
            if kj > 0 { calories = kj / 4.184 }
        }

        if calories == 0 && protein == 0 && fat == 0 && carbs == 0 {
            throw OFFError.missingNutrition
        }

        let servingGrams = product["serving_quantity"] as? Double
        let imageURL = product["image_front_small_url"] as? String

        return ProductResult(
            barcode: cleaned,
            name: name,
            brand: brand.flatMap { $0.isEmpty ? nil : $0 },
            caloriesPer100g: calories,
            proteinPer100g: protein,
            fatPer100g: fat,
            carbsPer100g: carbs,
            servingGrams: servingGrams,
            imageURL: imageURL
        )
    }

    /// Nutriment values can arrive as Double, String, Int, or NSNumber.
    private func nutrimentDouble(_ dict: [String: Any], key: String) -> Double {
        if let d = dict[key] as? Double { return d }
        if let n = dict[key] as? NSNumber { return n.doubleValue }
        if let s = dict[key] as? String, let d = Double(s) { return d }
        return 0
    }
}
