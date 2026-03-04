import Foundation
import UIKit

/// Claude AI food-photo recognition + meal description parsing service.
actor AIService {
    static let shared = AIService()

    private let apiKey  = Config.claudeAPIKey
    private let baseURL = Config.claudeBaseURL
    private let model   = Config.claudeModel

    struct FoodRecognition: Sendable {
        let foodName: String
        let estimatedGrams: Double
        let description: String
    }

    struct ParsedFoodItem: Sendable, Identifiable, Codable {
        var id: UUID = UUID()
        let name: String
        let calories: Double
        let protein: Double
        let fat: Double
        let carbs: Double
        let grams: Double

        enum CodingKeys: String, CodingKey {
            case name, calories, protein, fat, carbs, grams
        }

        init(name: String, calories: Double, protein: Double, fat: Double, carbs: Double, grams: Double) {
            self.id = UUID()
            self.name = name
            self.calories = calories
            self.protein = protein
            self.fat = fat
            self.carbs = carbs
            self.grams = grams
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.name = try c.decode(String.self, forKey: .name)
            self.calories = try c.decode(Double.self, forKey: .calories)
            self.protein = try c.decode(Double.self, forKey: .protein)
            self.fat = try c.decode(Double.self, forKey: .fat)
            self.carbs = try c.decode(Double.self, forKey: .carbs)
            self.grams = try c.decode(Double.self, forKey: .grams)
        }
    }

    enum AIError: LocalizedError {
        case badURL
        case badResponse
        case noParsableJSON

        var errorDescription: String? {
            switch self {
            case .badURL:         return "Invalid API URL"
            case .badResponse:    return "Unexpected API response"
            case .noParsableJSON: return "Could not parse food data"
            }
        }
    }

    // MARK: - Photo recognition

    func recognizeFood(image: UIImage) async throws -> FoodRecognition {
        guard let jpegData = image.jpegData(compressionQuality: 0.6) else {
            throw AIError.badResponse
        }

        let base64 = jpegData.base64EncodedString()

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 512,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64
                            ]
                        ],
                        [
                            "type": "text",
                            "text": """
                            Identify the food in this image.
                            Return ONLY a JSON object (no markdown, no explanation):
                            {"foodName": "name in English", "estimatedGrams": number, "description": "brief description"}
                            foodName must be a simple food name suitable for database search (e.g. "chicken breast" not "grilled herb-crusted chicken").
                            estimatedGrams should be your best estimate of the total portion weight.
                            """
                        ]
                    ]
                ]
            ]
        ]

        let data = try await callClaude(body: body)

        struct ClaudeResponse: Codable {
            struct Content: Codable { let text: String? }
            let content: [Content]
        }
        struct FoodJSON: Codable {
            let foodName: String
            let estimatedGrams: Double
            let description: String
        }

        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = response.content.first?.text else {
            throw AIError.badResponse
        }

        let jsonString = extractJSON(from: text)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIError.noParsableJSON
        }

        let parsed = try JSONDecoder().decode(FoodJSON.self, from: jsonData)
        return FoodRecognition(
            foodName: parsed.foodName,
            estimatedGrams: parsed.estimatedGrams,
            description: parsed.description
        )
    }

    // MARK: - Meal description parsing

    /// Parse a free-text meal description into individual food items with nutrition.
    /// e.g. "3 eggs, 2 tomatoes, splash of olive oil" -> [egg x 3, tomato x 2, olive oil]
    func parseMealDescription(text: String) async throws -> [ParsedFoodItem] {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": """
                    Parse this meal description into individual food items with estimated nutrition.
                    Description: "\(text)"

                    Return ONLY a JSON array (no markdown, no explanation). Each item:
                    {"name": "food name", "grams": estimated_weight, "calories": kcal, "protein": grams, "fat": grams, "carbs": grams}

                    Rules:
                    - Split into individual ingredients/items
                    - Use common serving sizes when amounts are vague ("a splash" = ~5ml, "a cup" = ~240ml)
                    - Nutrition values are for the TOTAL amount of that item (not per 100g)
                    - Be accurate with common foods (egg ~78 kcal, banana ~105 kcal, protein shake ~120 kcal per scoop)
                    - Name should be simple and clear (e.g. "Egg, boiled" not "large organic free-range egg")
                    """
                ]
            ]
        ]

        let data = try await callClaude(body: body)

        struct ClaudeResponse: Codable {
            struct Content: Codable { let text: String? }
            let content: [Content]
        }

        let response = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = response.content.first?.text else {
            throw AIError.badResponse
        }

        let jsonString = extractJSONArray(from: text)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw AIError.noParsableJSON
        }

        return try JSONDecoder().decode([ParsedFoodItem].self, from: jsonData)
    }

    // MARK: - Network

    private func callClaude(body: [String: Any]) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/messages") else {
            throw AIError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    // MARK: - JSON extraction

    private func extractJSON(from text: String) -> String {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return text
        }
        return String(text[start...end])
    }

    private func extractJSONArray(from text: String) -> String {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]") else {
            return text
        }
        return String(text[start...end])
    }
}
