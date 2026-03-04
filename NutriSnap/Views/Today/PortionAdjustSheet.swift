import SwiftUI

/// Universal sheet for adjusting portion size.
/// Used for:
/// 1. Editing grams of a food item already in a meal
/// 2. Adjusting grams before adding from Recent or My Products
struct PortionAdjustSheet: View {
    let name: String
    let baseCalories: Double
    let baseProtein: Double
    let baseFat: Double
    let baseCarbs: Double
    let baseGrams: Double
    let onSave: (_ grams: Double, _ cal: Double, _ pro: Double, _ fat: Double, _ carbs: Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var grams: Double
    @State private var gramsText: String

    init(
        name: String,
        baseCalories: Double,
        baseProtein: Double,
        baseFat: Double,
        baseCarbs: Double,
        baseGrams: Double,
        onSave: @escaping (_ grams: Double, _ cal: Double, _ pro: Double, _ fat: Double, _ carbs: Double) -> Void
    ) {
        self.name = name
        self.baseCalories = baseCalories
        self.baseProtein = baseProtein
        self.baseFat = baseFat
        self.baseCarbs = baseCarbs
        self.baseGrams = baseGrams
        self.onSave = onSave
        _grams = State(initialValue: baseGrams)
        _gramsText = State(initialValue: "\(Int(baseGrams))")
    }

    private var scale: Double {
        guard baseGrams > 0 else { return 1 }
        return grams / baseGrams
    }

    private var cal: Double  { baseCalories * scale }
    private var pro: Double  { baseProtein  * scale }
    private var fat: Double  { baseFat      * scale }
    private var carb: Double { baseCarbs    * scale }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Food name header
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .foregroundStyle(.secondary)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(name)
                                .font(.title3.bold())
                                .lineLimit(2)
                            Text("Per \(Int(baseGrams))g: \(Int(baseCalories)) kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    // Gram control
                    gramControl

                    // Nutrient cards
                    nutrientCards

                    // Save button
                    Button {
                        onSave(grams, cal, pro, fat, carb)
                        dismiss()
                    } label: {
                        Text("Save")
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

            Slider(value: $grams, in: 5...1000, step: 5)
                .tint(.green)
                .onChange(of: grams) { _, newVal in
                    gramsText = "\(Int(newVal))"
                }

            // Quick presets
            HStack(spacing: 8) {
                ForEach([25, 50, 100, 150, 200, 300], id: \.self) { preset in
                    Button("\(preset)g") {
                        withAnimation(.spring(response: 0.3)) {
                            grams = Double(preset)
                            gramsText = "\(preset)"
                        }
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
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
    PortionAdjustSheet(
        name: "Protein ON Gold Standard",
        baseCalories: 120,
        baseProtein: 24,
        baseFat: 1.5,
        baseCarbs: 3,
        baseGrams: 30
    ) { grams, cal, pro, fat, carbs in
        print("Save: \(grams)g, \(cal) kcal")
    }
    .preferredColorScheme(.dark)
}
