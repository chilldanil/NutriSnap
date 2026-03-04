import SwiftUI

struct FoodDetailSheet: View {
    let result: EdamamFoodResult
    let defaultGrams: Double
    let onSave: (FoodItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double
    @State private var gramsText: String

    init(result: EdamamFoodResult, defaultGrams: Double = 100, onSave: @escaping (FoodItem) -> Void) {
        self.result = result
        self.defaultGrams = defaultGrams
        self.onSave = onSave
        _grams = State(initialValue: defaultGrams)
        _gramsText = State(initialValue: "\(Int(defaultGrams))")
    }

    // Scaled values
    private var scale: Double { grams / 100.0 }
    private var cal: Double  { (result.caloriesPer100g * scale) }
    private var pro: Double  { (result.proteinPer100g  * scale) }
    private var fat: Double  { (result.fatPer100g      * scale) }
    private var carb: Double { (result.carbsPer100g    * scale) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Food image + name
                    header

                    // Gram control
                    gramControl

                    // Nutrients
                    nutrientCards

                    // Save
                    Button {
                        let food = result.toFoodItem(grams: grams)
                        onSave(food)
                        dismiss()
                    } label: {
                        Text("Add \(result.label)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Adjust Portion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            if let urlStr = result.imageURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        foodPlaceholder
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                foodPlaceholder
                    .frame(width: 72, height: 72)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(result.label)
                    .font(.title3.bold())
                    .lineLimit(2)
                Text("Per 100g: \(Int(result.caloriesPer100g)) kcal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var foodPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.tertiarySystemGroupedBackground))
            .overlay(
                Image(systemName: "fork.knife")
                    .foregroundStyle(.secondary)
            )
    }

    // MARK: - Gram control

    private var gramControl: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Portion size")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    TextField("", text: $gramsText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.title3.bold().monospacedDigit())
                        .frame(width: 60)
                        .onChange(of: gramsText) { _, newVal in
                            if let v = Double(newVal), v > 0 {
                                grams = min(v, 2000)
                            }
                        }
                    Text("g")
                        .foregroundStyle(.secondary)
                }
            }

            Slider(value: $grams, in: 10...1000, step: 5)
                .tint(.green)
                .onChange(of: grams) { _, newVal in
                    gramsText = "\(Int(newVal))"
                }

            // Quick presets
            HStack(spacing: 8) {
                ForEach([50, 100, 150, 200, 300], id: \.self) { preset in
                    Button("\(preset)g") {
                        withAnimation(.spring(response: 0.3)) {
                            grams = Double(preset)
                            gramsText = "\(preset)"
                        }
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        grams == Double(preset)
                            ? Color.green.opacity(0.2)
                            : Color(.tertiarySystemGroupedBackground)
                    )
                    .foregroundStyle(grams == Double(preset) ? .green : .secondary)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Nutrient cards

    private var nutrientCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            nutrientCard(label: "Calories", value: cal, unit: "kcal", color: .green)
            nutrientCard(label: "Protein", value: pro, unit: "g", color: .blue)
            nutrientCard(label: "Fat", value: fat, unit: "g", color: .orange)
            nutrientCard(label: "Carbs", value: carb, unit: "g", color: .pink)
        }
    }

    private func nutrientCard(label: String, value: Double, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value < 10 ? String(format: "%.1f", value) : "\(Int(value))")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.spring(response: 0.3), value: grams)
    }
}

#Preview {
    FoodDetailSheet(
        result: EdamamFoodResult(
            id: "food_123",
            label: "Chicken Breast",
            caloriesPer100g: 165,
            proteinPer100g: 31,
            fatPer100g: 3.6,
            carbsPer100g: 0,
            imageURL: nil
        ),
        defaultGrams: 200
    ) { _ in }
    .preferredColorScheme(.dark)
}
