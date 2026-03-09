import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUser") private var currentUser = ""
    @Query private var profiles: [UserProfile]
    @Query(sort: \DailyLog.date, order: .reverse) private var allLogs: [DailyLog]

    @State private var viewModel: DailyLogViewModel?
    @State private var showAddFood = false
    @State private var selectedMealType: MealType = .breakfast
    @State private var showCopiedToast = false
    @State private var foodToEdit: FoodItem?

    private var navigationState = NavigationState.shared
    private var log: DailyLog? { viewModel?.todayLog }

    private var currentProfile: UserProfile? {
        profiles.first(where: { $0.userName == currentUser })
    }

    private var userLogs: [DailyLog] {
        allLogs.filter { $0.userName == currentUser }
    }

    /// Consecutive days (including today) with at least one food logged
    private var streak: Int {
        let calendar = Calendar.current
        var count = 0
        var checkDate = calendar.startOfDay(for: Date())

        for _ in 0..<365 {
            let hasLog = userLogs.contains { log in
                calendar.isDate(log.date, inSameDayAs: checkDate)
                    && log.meals.contains(where: { !$0.foods.isEmpty })
            }
            guard hasLog else { break }
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 24) {
                        // Date + streak
                        dateHeader

                        // Calories
                        CalorieProgressView(
                            eaten: log?.totalCalories ?? 0,
                            target: log?.targetCalories ?? 2000,
                            meals: log?.sortedMeals ?? []
                        )

                        // Macros
                        MacroRingsView(
                            protein: log?.totalProtein ?? 0,
                            proteinTarget: log?.targetProtein ?? 150,
                            fat: log?.totalFat ?? 0,
                            fatTarget: log?.targetFat ?? 65,
                            carbs: log?.totalCarbs ?? 0,
                            carbsTarget: log?.targetCarbs ?? 250,
                            meals: log?.sortedMeals ?? []
                        )

                        // Energy Balance (HealthKit burned calories)
                        if currentProfile?.isHealthKitEnabled == true {
                            EnergyBalanceView(
                                consumed: log?.totalCalories ?? 0,
                                active: viewModel?.activeCaloriesBurned ?? 0,
                                basal: viewModel?.basalCaloriesBurned ?? 0
                            )
                        }

                        // Water
                        WaterTrackingView(
                            currentMl: log?.waterMl ?? 0,
                            targetMl: log?.waterTarget ?? 2500,
                            onAdd: { ml in
                                viewModel?.addWater(ml)
                            }
                        )

                        // Meals
                        VStack(spacing: 10) {
                            ForEach(log?.sortedMeals ?? [], id: \.id) { meal in
                                MealSectionView(
                                    meal: meal,
                                    onAddFood: {
                                        selectedMealType = meal.mealType
                                        showAddFood = true
                                    },
                                    onDeleteFood: { food in
                                        viewModel?.removeFood(food, from: meal.mealType)
                                    },
                                    onTapFood: { food in
                                        foodToEdit = food
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 80)
                }

                // FAB
                fab
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        copyMyDay()
                    } label: {
                        Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                            .font(.body.weight(.medium))
                            .foregroundStyle(showCopiedToast ? .green : .primary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .overlay(alignment: .top) {
                if showCopiedToast {
                    copiedToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showAddFood) {
                AddFoodView(mealType: selectedMealType) { foods in
                    if foods.count == 1, let food = foods.first {
                        viewModel?.addFood(food, to: selectedMealType)
                    } else {
                        viewModel?.addFoods(foods, to: selectedMealType)
                    }
                }
                .presentationDetents([.large])
            }
            .sheet(item: $foodToEdit) { food in
                PortionAdjustSheet(
                    name: food.name,
                    baseCalories: food.calories,
                    baseProtein: food.protein,
                    baseFat: food.fat,
                    baseCarbs: food.carbs,
                    baseGrams: food.grams
                ) { grams, cal, pro, fat, carbs in
                    viewModel?.updateFood(food, grams: grams, calories: cal, protein: pro, fat: fat, carbs: carbs)
                }
                .presentationDetents([.large])
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = DailyLogViewModel(modelContext: modelContext)
            }
            viewModel?.loadToday(profile: currentProfile, userName: currentUser)
            viewModel?.isHealthKitEnabled = currentProfile?.isHealthKitEnabled ?? false
            viewModel?.fetchBurnedCalories()
        }
        .onChange(of: currentProfile?.targetCalories) { _, _ in
            viewModel?.loadToday(profile: currentProfile, userName: currentUser)
        }
        .onChange(of: currentProfile?.targetProtein) { _, _ in
            viewModel?.loadToday(profile: currentProfile, userName: currentUser)
        }
        .onChange(of: currentProfile?.targetFat) { _, _ in
            viewModel?.loadToday(profile: currentProfile, userName: currentUser)
        }
        .onChange(of: currentProfile?.targetCarbs) { _, _ in
            viewModel?.loadToday(profile: currentProfile, userName: currentUser)
        }
        .onChange(of: currentProfile?.waterTarget) { _, _ in
            viewModel?.loadToday(profile: currentProfile, userName: currentUser)
        }
        .onChange(of: navigationState.shouldOpenAddFood) { _, shouldOpen in
            if shouldOpen {
                selectedMealType = currentMealType()
                showAddFood = true
                navigationState.shouldOpenAddFood = false
            }
        }
    }

    // MARK: - Copy My Day

    private func copyMyDay() {
        guard let vm = viewModel else { return }
        let text = vm.copyDayToClipboard()
        guard !text.isEmpty else { return }

        UIPasteboard.general.string = text

        withAnimation(.spring(response: 0.3)) {
            showCopiedToast = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.spring(response: 0.3)) {
                showCopiedToast = false
            }
        }
    }

    private var copiedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Copied to clipboard")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 8)
    }

    // MARK: - Components

    private var dateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Date.now, format: .dateTime.day().month(.wide))
                    .font(.title3.bold())
            }
            Spacer()

            if streak > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(streak)")
                        .font(.subheadline.bold().monospacedDigit())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
            }
        }
        .padding(.top, 4)
    }

    private var fab: some View {
        Button {
            selectedMealType = currentMealType()
            showAddFood = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.green, in: Circle())
                .shadow(color: .green.opacity(0.35), radius: 10, y: 5)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    /// Guess the current meal based on time of day
    private func currentMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return .breakfast
        case 11..<15: return .lunch
        case 15..<20: return .dinner
        default:      return .snack
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
