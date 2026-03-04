import SwiftUI
import SwiftData

struct MealSectionView: View {
    let meal: MealEntry
    let onAddFood: () -> Void
    var onDeleteFood: ((FoodItem) -> Void)?
    var onTapFood: ((FoodItem) -> Void)?

    @State private var isExpanded = true
    @State private var foodToDelete: FoodItem?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: meal.mealType.icon)
                        .font(.title3)
                        .foregroundStyle(.green)
                        .frame(width: 32)

                    Text(meal.mealType.rawValue)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    if meal.totalCalories > 0 {
                        Text("\(Int(meal.totalCalories)) kcal")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                    .padding(.leading, 60)

                if meal.foods.isEmpty {
                    // Empty state — tap to add
                    Button(action: onAddFood) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.dashed")
                            Text("Add food")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 14)
                        .padding(.leading, 60)
                        .padding(.trailing, 16)
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(meal.foods, id: \.id) { food in
                            FoodRowView(food: food)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onTapFood?(food)
                                }
                                .contextMenu {
                                    Button {
                                        onTapFood?(food)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        foodToDelete = food
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            if food.id != meal.foods.last?.id {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }

                    // Add more
                    Divider().padding(.leading, 60)
                    Button(action: onAddFood) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.caption)
                            Text("Add more")
                                .font(.caption)
                        }
                        .foregroundStyle(.green)
                        .padding(.vertical, 10)
                        .padding(.leading, 60)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .alert("Delete food?", isPresented: .init(
            get: { foodToDelete != nil },
            set: { if !$0 { foodToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let food = foodToDelete {
                    withAnimation {
                        onDeleteFood?(food)
                    }
                }
                foodToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                foodToDelete = nil
            }
        } message: {
            if let food = foodToDelete {
                Text("Remove \(food.name) (\(Int(food.calories)) kcal)?")
            }
        }
    }
}

// MARK: - Food row

struct FoodRowView: View {
    let food: FoodItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(.subheadline)
                HStack(spacing: 8) {
                    Text("\(Int(food.grams))g")
                    Text("P \(Int(food.protein))")
                    Text("F \(Int(food.fat))")
                    Text("C \(Int(food.carbs))")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(.leading, 60)

            Spacer()

            Text("\(Int(food.calories))")
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
            Text("kcal")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.trailing, 16)
    }
}

#Preview {
    let container = PreviewContainer.shared
    ScrollView {
        VStack(spacing: 12) {
            MealSectionView(
                meal: MealEntry(mealType: .breakfast),
                onAddFood: {}
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
    .modelContainer(container)
}
