import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    let userName: String

    @State private var step = 0
    @State private var gender: Gender
    @State private var ageText = "25"
    @State private var weightText = "70"
    @State private var heightText = "175"
    @State private var goal: Goal = .maintain
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var targets: NutritionCalculator.Targets?

    private let totalSteps = 5

    init(userName: String) {
        self.userName = userName
        let defaultGender = AppUser(rawValue: userName)?.defaultGender ?? .male
        _gender = State(initialValue: defaultGender)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar (hidden on welcome)
            if step > 0 {
                ProgressView(value: Double(step), total: Double(totalSteps - 1))
                    .tint(.green)
                    .padding(.horizontal, 32)
                    .padding(.top, 12)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            // Content
            Group {
                switch step {
                case 0:  welcomeStep
                case 1:  personalInfoStep
                case 2:  goalStep
                case 3:  activityStep
                default: summaryStep
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            Spacer(minLength: 0)

            // Navigation
            if step > 0 && step < 4 {
                bottomButtons(showBack: step > 1)
            }
        }
        .padding(.bottom, 32)
        .background(Color(.systemGroupedBackground))
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .repeating.speed(0.3))

            Text("NutriSnap")
                .font(.system(size: 40, weight: .bold, design: .rounded))

            Text("Track your nutrition effortlessly")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                withAnimation { step = 1 }
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 32)
        }
    }

    private var personalInfoStep: some View {
        VStack(spacing: 28) {
            stepHeader(title: "About You", subtitle: "We'll use this to calculate your targets")

            // Gender
            Picker("Gender", selection: $gender) {
                ForEach(Gender.allCases) { g in
                    Text(g.rawValue).tag(g)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 32)

            // Fields
            VStack(spacing: 16) {
                onboardingField(title: "Age", text: $ageText, unit: "years")
                onboardingField(title: "Weight", text: $weightText, unit: "kg")
                onboardingField(title: "Height", text: $heightText, unit: "cm")
            }
            .padding(.horizontal, 32)
        }
    }

    private var goalStep: some View {
        VStack(spacing: 28) {
            stepHeader(title: "Your Goal", subtitle: "What do you want to achieve?")

            VStack(spacing: 12) {
                ForEach(Goal.allCases) { g in
                    Button {
                        withAnimation(.spring(response: 0.3)) { goal = g }
                    } label: {
                        HStack(spacing: 16) {
                            Text(g.emoji)
                                .font(.title)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(g.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if goal == g {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.title3)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(goal == g
                                    ? Color.green.opacity(0.1)
                                    : Color(.tertiarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(goal == g ? .green : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
        }
    }

    private var activityStep: some View {
        VStack(spacing: 28) {
            stepHeader(title: "Activity Level", subtitle: "How active are you on average?")

            VStack(spacing: 8) {
                ForEach(ActivityLevel.allCases) { level in
                    Button {
                        withAnimation(.spring(response: 0.3)) { activityLevel = level }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(level.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if activityLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(activityLevel == level
                                    ? Color.green.opacity(0.1)
                                    : Color(.tertiarySystemGroupedBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 32)
        }
    }

    private var summaryStep: some View {
        VStack(spacing: 24) {
            stepHeader(title: "Your Plan", subtitle: "Based on your data, here are your daily targets")

            if let t = targets {
                // Calories
                VStack(spacing: 4) {
                    Text("\(Int(t.calories))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    Text("calories / day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)

                // Macros
                HStack(spacing: 24) {
                    macroSummaryItem(label: "Protein", grams: t.protein, color: .blue)
                    macroSummaryItem(label: "Fat", grams: t.fat, color: .orange)
                    macroSummaryItem(label: "Carbs", grams: t.carbs, color: .pink)
                }
            }

            Spacer()

            Button {
                saveProfile()
            } label: {
                Text("Let's Go!")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Reusable pieces

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private func onboardingField(title: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            TextField("", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
        }
    }

    private func macroSummaryItem(label: String, grams: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(Int(grams))g")
                .font(.title2.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func bottomButtons(showBack: Bool) -> some View {
        HStack(spacing: 16) {
            if showBack {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .padding(14)
                        .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                }
            }

            Button {
                advance()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Logic

    private func advance() {
        if step == 3 {
            // Calculate before showing summary
            targets = NutritionCalculator.calculate(
                gender: gender,
                weight: Double(weightText) ?? 70,
                height: Double(heightText) ?? 175,
                age: Int(ageText) ?? 25,
                goal: goal,
                activityLevel: activityLevel
            )
        }
        withAnimation { step += 1 }
    }

    private func saveProfile() {
        let profile = UserProfile(
            gender: gender,
            weight: Double(weightText) ?? 70,
            height: Double(heightText) ?? 175,
            age: Int(ageText) ?? 25,
            goal: goal,
            activityLevel: activityLevel
        )
        profile.userName = userName
        profile.recalculateTargets()
        profile.isOnboarded = true

        modelContext.insert(profile)
        try? modelContext.save()
        SupabaseManager.shared.pushProfile(profile)
    }
}

#Preview {
    OnboardingView(userName: "daniil")
        .modelContainer(PreviewContainer.shared)
}
