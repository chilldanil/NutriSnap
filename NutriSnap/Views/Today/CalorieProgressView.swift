import SwiftUI

struct CalorieProgressView: View {
    let eaten: Double
    let target: Double
    let meals: [MealEntry]

    @State private var animatedProgress: Double = 0
    @State private var showBreakdown = false

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(eaten / target, 1.5)
    }

    private var remaining: Int {
        max(0, Int(target - eaten))
    }

    var body: some View {
        VStack(spacing: 10) {
            Button {
                showBreakdown = true
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.12), lineWidth: 22)

                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(
                            AngularGradient(
                                colors: [.green.opacity(0.6), .green],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360 * animatedProgress)
                            ),
                            style: StrokeStyle(lineWidth: 22, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(Int(eaten))")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())

                        Text("/ \(Int(target)) kcal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("\(remaining) left")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 2)
                    }
                }
                .frame(width: 200, height: 200)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(Int(eaten)) of \(Int(target)) calories")
            .accessibilityHint("Shows foods contributing to calories")

            Text("Tap the ring to see food sources")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                animatedProgress = progress
            }
        }
        .sheet(isPresented: $showBreakdown) {
            CalorieBreakdownSheet(
                eaten: eaten,
                target: target,
                items: breakdownItems
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var breakdownItems: [CalorieBreakdownItem] {
        let total = eaten

        return meals
            .flatMap { meal in
                meal.foods.compactMap { food -> CalorieBreakdownItem? in
                    guard food.calories > 0.5 else { return nil }

                    return CalorieBreakdownItem(
                        foodId: food.id,
                        mealType: meal.mealType,
                        foodName: food.name,
                        grams: food.grams,
                        calories: food.calories,
                        share: total > 0 ? food.calories / total : 0,
                        protein: food.protein,
                        fat: food.fat,
                        carbs: food.carbs
                    )
                }
            }
            .sorted { lhs, rhs in
                if lhs.calories == rhs.calories {
                    return lhs.foodName.localizedCaseInsensitiveCompare(rhs.foodName) == .orderedAscending
                }
                return lhs.calories > rhs.calories
            }
    }
}

private struct CalorieBreakdownItem: Identifiable {
    let foodId: UUID
    let mealType: MealType
    let foodName: String
    let grams: Double
    let calories: Double
    let share: Double
    let protein: Double
    let fat: Double
    let carbs: Double

    var id: String { "\(foodId.uuidString)-\(mealType.rawValue)" }
}

private struct CalorieBreakdownSheet: View {
    let eaten: Double
    let target: Double
    let items: [CalorieBreakdownItem]

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(eaten / target, 1.0)
    }

    private var remainingText: String {
        let difference = target - eaten
        if difference >= 0 {
            return "\(difference.calorieFormatted) kcal left"
        }
        return "\(abs(difference).calorieFormatted) kcal over"
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
            .navigationTitle("Calorie Sources")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Label("Calories", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                Spacer()

                Text("\(eaten.calorieFormatted)/\(target.calorieFormatted) kcal")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: progress)
                .tint(.green)

            Text(remainingText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.green)

            Text("No calories logged yet")
                .font(.headline)

            Text("Add foods to see which items build up your calories.")
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

    private func breakdownCard(for item: CalorieBreakdownItem) -> some View {
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
                    Text("\(item.calories.calorieFormatted) kcal")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.green)

                    Text("\(item.share, format: .percent.precision(.fractionLength(0))) of total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                macroPill(label: "P", value: item.protein, color: .blue)
                macroPill(label: "F", value: item.fat, color: .orange)
                macroPill(label: "C", value: item.carbs, color: .pink)
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
    var calorieFormatted: String {
        if abs(self.rounded() - self) < 0.05 {
            return "\(Int(self.rounded()))"
        }
        return self.formatted(.number.precision(.fractionLength(1)))
    }

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
    VStack(spacing: 40) {
        CalorieProgressView(eaten: 1151, target: 2200, meals: [])
        CalorieProgressView(eaten: 0, target: 2200, meals: [])
        CalorieProgressView(eaten: 2200, target: 2200, meals: [])
    }
    .padding()
    .preferredColorScheme(.dark)
}
