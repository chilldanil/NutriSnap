import SwiftUI

struct MacroRingsView: View {
    let protein: Double
    let proteinTarget: Double
    let fat: Double
    let fatTarget: Double
    let carbs: Double
    let carbsTarget: Double
    let meals: [MealEntry]

    @State private var selectedMacro: MacroKind?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 20) {
                macroButton(for: .protein, current: protein, target: proteinTarget)
                macroButton(for: .fat, current: fat, target: fatTarget)
                macroButton(for: .carbs, current: carbs, target: carbsTarget)
            }

            Text("Tap a ring to see food sources")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .sheet(item: $selectedMacro) { macro in
            MacroBreakdownSheet(
                macro: macro,
                current: currentValue(for: macro),
                target: targetValue(for: macro),
                items: breakdownItems(for: macro)
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func macroButton(for macro: MacroKind, current: Double, target: Double) -> some View {
        Button {
            selectedMacro = macro
        } label: {
            MacroRing(label: macro.title, current: current, target: target, color: macro.color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(macro.title), \(Int(current)) of \(Int(target)) grams")
        .accessibilityHint("Shows foods contributing to this macro")
    }

    private func currentValue(for macro: MacroKind) -> Double {
        switch macro {
        case .protein: protein
        case .fat: fat
        case .carbs: carbs
        }
    }

    private func targetValue(for macro: MacroKind) -> Double {
        switch macro {
        case .protein: proteinTarget
        case .fat: fatTarget
        case .carbs: carbsTarget
        }
    }

    private func breakdownItems(for macro: MacroKind) -> [MacroBreakdownItem] {
        let total = currentValue(for: macro)

        return meals
            .flatMap { meal in
                meal.foods.compactMap { food -> MacroBreakdownItem? in
                    let amount = macro.amount(in: food)
                    guard amount > 0.05 else { return nil }

                    return MacroBreakdownItem(
                        foodId: food.id,
                        mealType: meal.mealType,
                        foodName: food.name,
                        grams: food.grams,
                        amount: amount,
                        share: total > 0 ? amount / total : 0,
                        calories: food.calories,
                        protein: food.protein,
                        fat: food.fat,
                        carbs: food.carbs
                    )
                }
            }
            .sorted { lhs, rhs in
                if lhs.amount == rhs.amount {
                    return lhs.foodName.localizedCaseInsensitiveCompare(rhs.foodName) == .orderedAscending
                }
                return lhs.amount > rhs.amount
            }
    }
}

// MARK: - Single ring

struct MacroRing: View {
    let label: String
    let current: Double
    let target: Double
    let color: Color

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(current))")
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
            }
            .frame(width: 72, height: 72)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text("\(Int(current))/\(Int(target))g")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.15)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                animatedProgress = progress
            }
        }
    }
}

private enum MacroKind: String, Identifiable {
    case protein
    case fat
    case carbs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .protein: "Protein"
        case .fat: "Fat"
        case .carbs: "Carbs"
        }
    }

    var color: Color {
        switch self {
        case .protein: .blue
        case .fat: .orange
        case .carbs: .pink
        }
    }

    var icon: String {
        switch self {
        case .protein: "dumbbell.fill"
        case .fat: "drop.fill"
        case .carbs: "bolt.fill"
        }
    }

    func amount(in food: FoodItem) -> Double {
        switch self {
        case .protein: food.protein
        case .fat: food.fat
        case .carbs: food.carbs
        }
    }
}

private struct MacroBreakdownItem: Identifiable {
    let foodId: UUID
    let mealType: MealType
    let foodName: String
    let grams: Double
    let amount: Double
    let share: Double
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double

    var id: String { "\(foodId.uuidString)-\(mealType.rawValue)" }
}

private struct MacroBreakdownSheet: View {
    let macro: MacroKind
    let current: Double
    let target: Double
    let items: [MacroBreakdownItem]

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard

                    if items.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 12) {
                            ForEach(items) { item in
                                breakdownCard(for: item)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(macro.title) Sources")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Label(macro.title, systemImage: macro.icon)
                    .font(.headline)
                    .foregroundStyle(macro.color)

                Spacer()

                Text("\(current.macroFormatted)/\(target.macroFormatted)g")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(macro.color)

            Text("Sorted by contribution to today's \(macro.title.lowercased()).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: macro.icon)
                .font(.title2)
                .foregroundStyle(macro.color)

            Text("No \(macro.title.lowercased()) logged yet")
                .font(.headline)

            Text("Add foods to see which items build up this macro.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func breakdownCard(for item: MacroBreakdownItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.foodName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    HStack(spacing: 10) {
                        Label(item.mealType.rawValue, systemImage: item.mealType.icon)
                        Text("\(item.grams.gramsFormatted)g")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(item.amount.macroFormatted)g")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(macro.color)

                    Text("\(item.share, format: .percent.precision(.fractionLength(0))) of total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                macroPill(label: "P", value: item.protein, color: .blue)
                macroPill(label: "F", value: item.fat, color: .orange)
                macroPill(label: "C", value: item.carbs, color: .pink)

                Spacer()

                Text("\(item.calories.macroFormatted) kcal")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func macroPill(label: String, value: Double, color: Color) -> some View {
        Text("\(label) \(value.macroFormatted)")
            .font(.caption2.monospacedDigit().weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private extension Double {
    var macroFormatted: String {
        if abs(self.rounded() - self) < 0.05 {
            return "\(Int(self.rounded()))"
        }
        return self.formatted(.number.precision(.fractionLength(1)))
    }

    var gramsFormatted: String {
        if abs(self.rounded() - self) < 0.05 {
            return "\(Int(self.rounded()))"
        }
        return self.formatted(.number.precision(.fractionLength(0...1)))
    }
}

#Preview {
    MacroRingsView(
        protein: 82, proteinTarget: 176,
        fat: 28, fatTarget: 61,
        carbs: 131, carbsTarget: 210,
        meals: []
    )
    .padding()
    .preferredColorScheme(.dark)
}
