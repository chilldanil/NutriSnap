import Foundation

// MARK: - Search result (per 100g, not persisted)

struct EdamamFoodResult: Identifiable, Sendable {
    let id: String          // foodId
    let label: String
    let caloriesPer100g: Double
    let proteinPer100g: Double
    let fatPer100g: Double
    let carbsPer100g: Double
    let imageURL: String?

    func toFoodItem(grams: Double) -> FoodItem {
        let s = grams / 100.0
        return FoodItem(
            name: label,
            calories: (caloriesPer100g * s * 10).rounded() / 10,
            protein:  (proteinPer100g  * s * 10).rounded() / 10,
            fat:      (fatPer100g      * s * 10).rounded() / 10,
            carbs:    (carbsPer100g    * s * 10).rounded() / 10,
            grams: grams,
            edamamFoodId: id
        )
    }
}

// MARK: - Service

actor EdamamService {
    static let shared = EdamamService()

    private let baseURL = Config.edamamBaseURL
    private let apiKey  = Config.edamamRapidAPIKey
    private let apiHost = Config.edamamRapidAPIHost

    // MARK: - Codable response types

    private struct SearchResponse: Codable {
        let text: String?
        let parsed: [ParsedItem]?
        let hints: [Hint]?
    }

    private struct ParsedItem: Codable {
        let food: EdamamFood
    }

    private struct Hint: Codable {
        let food: EdamamFood
    }

    private struct EdamamFood: Codable {
        let foodId: String
        let label: String
        let nutrients: Nutrients
        let image: String?
    }

    private struct Nutrients: Codable {
        let ENERC_KCAL: Double?
        let PROCNT: Double?
        let FAT: Double?
        let CHOCDF: Double?
    }

    // MARK: - API

    func searchFood(query: String) async throws -> [EdamamFoodResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/api/food-database/v2/parser?ingr=\(encoded)") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue(apiHost, forHTTPHeaderField: "X-RapidAPI-Host")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)

        // Deduplicate by label (Edamam often returns duplicates)
        var seen = Set<String>()
        var results: [EdamamFoodResult] = []

        for hint in (decoded.hints ?? []) {
            let key = hint.food.label.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let n = hint.food.nutrients
            results.append(EdamamFoodResult(
                id: hint.food.foodId,
                label: hint.food.label,
                caloriesPer100g: n.ENERC_KCAL ?? 0,
                proteinPer100g: n.PROCNT ?? 0,
                fatPer100g: n.FAT ?? 0,
                carbsPer100g: n.CHOCDF ?? 0,
                imageURL: hint.food.image
            ))
        }

        return results
    }
}
