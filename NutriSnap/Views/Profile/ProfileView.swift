import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUser") private var currentUser = ""
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? {
        profiles.first(where: { $0.userName == currentUser })
    }

    @State private var showEditSheet = false

    var body: some View {
        NavigationStack {
            List {
                if let p = profile {
                    // Personal info
                    Section {
                        profileRow(icon: "person.fill", title: "Gender", value: p.gender.rawValue)
                        profileRow(icon: "calendar", title: "Age", value: "\(p.age) years")
                        profileRow(icon: "scalemass.fill", title: "Weight", value: String(format: "%.1f kg", p.weight))
                        profileRow(icon: "ruler.fill", title: "Height", value: String(format: "%.0f cm", p.height))
                    } header: {
                        Text("Personal")
                    }

                    // Goals
                    Section {
                        profileRow(icon: "target", title: "Goal", value: p.goal.rawValue)
                        profileRow(icon: "figure.walk", title: "Activity", value: p.activityLevel.rawValue)
                    } header: {
                        Text("Goals")
                    }

                    // Targets
                    Section {
                        targetRow(title: "Calories", value: Int(p.targetCalories), unit: "kcal", color: .green)
                        targetRow(title: "Protein", value: Int(p.targetProtein), unit: "g", color: .blue)
                        targetRow(title: "Fat", value: Int(p.targetFat), unit: "g", color: .orange)
                        targetRow(title: "Carbs", value: Int(p.targetCarbs), unit: "g", color: .pink)
                        targetRow(title: "Water", value: Int(p.waterTarget), unit: "ml", color: .cyan)
                    } header: {
                        Text("Daily Targets")
                    } footer: {
                        Text(p.useCustomTargets ? "Custom targets" : "Calculated using the Mifflin-St Jeor equation")
                    }

                    // Health integration
                    Section {
                        Toggle(isOn: Binding(
                            get: { p.isHealthKitEnabled },
                            set: { newValue in
                                if newValue {
                                    Task {
                                        do {
                                            try await HealthKitManager.shared.requestAuthorization()
                                            p.isHealthKitEnabled = true
                                            try? modelContext.save()
                                            SupabaseManager.shared.pushProfile(p)
                                        } catch {
                                            p.isHealthKitEnabled = false
                                        }
                                    }
                                } else {
                                    p.isHealthKitEnabled = false
                                    try? modelContext.save()
                                    SupabaseManager.shared.pushProfile(p)
                                }
                            }
                        )) {
                            Label("Apple Health", systemImage: "heart.fill")
                        }
                        .tint(.green)

                        if p.isHealthKitEnabled {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Syncing calories, macros & water")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Health Integration")
                    } footer: {
                        Text("When enabled, food and water logged in NutriSnap is saved to the Health app")
                    }

                    // Edit
                    Section {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit Profile", systemImage: "pencil")
                        }
                    }

                    // Switch user
                    Section {
                        Button {
                            withAnimation {
                                currentUser = ""
                                if let ud = UserDefaults(suiteName: "group.com.daniil.NutriSnap") {
                                    ud.set("", forKey: "currentUser")
                                }
                            }
                        } label: {
                            Label("Switch User", systemImage: "arrow.left.arrow.right")
                                .foregroundStyle(.orange)
                        }
                    }
                } else {
                    ContentUnavailableView("No Profile", systemImage: "person.crop.circle.badge.exclamationmark")
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showEditSheet) {
                if let p = profile {
                    EditProfileSheet(profile: p)
                }
            }
        }
    }

    // MARK: - Row builders

    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func targetRow(title: String, value: Int, unit: String, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(title)
            Spacer()
            Text("\(value) \(unit)")
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

// MARK: - Edit sheet

struct EditProfileSheet: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var gender: Gender
    @State private var ageText: String
    @State private var weightText: String
    @State private var heightText: String
    @State private var goal: Goal
    @State private var activityLevel: ActivityLevel
    @State private var useCustomTargets: Bool
    @State private var customCalories: String
    @State private var customProtein: String
    @State private var customFat: String
    @State private var customCarbs: String
    @State private var waterTargetText: String

    init(profile: UserProfile) {
        self.profile = profile
        _gender = State(initialValue: profile.gender)
        _ageText = State(initialValue: "\(profile.age)")
        _weightText = State(initialValue: String(format: "%.0f", profile.weight))
        _heightText = State(initialValue: String(format: "%.0f", profile.height))
        _goal = State(initialValue: profile.goal)
        _activityLevel = State(initialValue: profile.activityLevel)
        _useCustomTargets = State(initialValue: profile.useCustomTargets)
        _customCalories = State(initialValue: "\(Int(profile.targetCalories))")
        _customProtein = State(initialValue: "\(Int(profile.targetProtein))")
        _customFat = State(initialValue: "\(Int(profile.targetFat))")
        _customCarbs = State(initialValue: "\(Int(profile.targetCarbs))")
        _waterTargetText = State(initialValue: "\(Int(profile.waterTarget))")
    }

    private var previewTargets: NutritionCalculator.Targets {
        NutritionCalculator.calculate(
            gender: gender,
            weight: Double(weightText) ?? profile.weight,
            height: Double(heightText) ?? profile.height,
            age: Int(ageText) ?? profile.age,
            goal: goal,
            activityLevel: activityLevel
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Personal") {
                    Picker("Gender", selection: $gender) {
                        ForEach(Gender.allCases) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("25", text: $ageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("70", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }

                    HStack {
                        Text("Height (cm)")
                        Spacer()
                        TextField("175", text: $heightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section("Goal") {
                    Picker("Goal", selection: $goal) {
                        ForEach(Goal.allCases) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                }

                Section("Activity") {
                    Picker("Activity Level", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }

                // Targets section
                Section {
                    Toggle("Set manually", isOn: $useCustomTargets.animation(.spring(response: 0.3)))
                        .tint(.green)

                    if useCustomTargets {
                        // Custom editable targets
                        targetField("Calories (kcal)", text: $customCalories, color: .green)
                        targetField("Protein (g)", text: $customProtein, color: .blue)
                        targetField("Fat (g)", text: $customFat, color: .orange)
                        targetField("Carbs (g)", text: $customCarbs, color: .pink)
                    } else {
                        // Calculated preview
                        let t = previewTargets
                        targetPreviewRow("Calories", value: Int(t.calories), unit: "kcal", color: .green)
                        targetPreviewRow("Protein", value: Int(t.protein), unit: "g", color: .blue)
                        targetPreviewRow("Fat", value: Int(t.fat), unit: "g", color: .orange)
                        targetPreviewRow("Carbs", value: Int(t.carbs), unit: "g", color: .pink)
                    }
                } header: {
                    Text("Daily Targets")
                } footer: {
                    Text(useCustomTargets ? "Enter your own calorie and macro goals" : "Calculated from your profile using Mifflin-St Jeor")
                }

                // Water target
                Section("Water Target") {
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.cyan)
                        Text("Daily goal")
                        Spacer()
                        TextField("2500", text: $waterTargetText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                            .fontWeight(.semibold)
                            .foregroundStyle(.cyan)
                        Text("ml")
                            .foregroundStyle(.secondary)
                    }

                    // Quick presets
                    HStack(spacing: 8) {
                        ForEach([2000, 2500, 3000, 3500], id: \.self) { preset in
                            Button("\(preset)") {
                                waterTargetText = "\(preset)"
                            }
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Int(waterTargetText) == preset
                                    ? Color.cyan.opacity(0.2)
                                    : Color(.tertiarySystemGroupedBackground)
                            )
                            .foregroundStyle(Int(waterTargetText) == preset ? .cyan : .secondary)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func targetField(_ title: String, text: Binding<String>, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    private func targetPreviewRow(_ title: String, value: Int, unit: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
            Spacer()
            Text("\(value) \(unit)")
                .fontWeight(.semibold)
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }

    private func saveChanges() {
        let oldWeight = profile.weight
        let newWeight = Double(weightText) ?? profile.weight

        profile.gender = gender
        profile.age = Int(ageText) ?? profile.age
        profile.weight = newWeight
        profile.height = Double(heightText) ?? profile.height
        profile.goal = goal
        profile.activityLevel = activityLevel
        profile.useCustomTargets = useCustomTargets
        profile.waterTarget = Double(waterTargetText) ?? 2500

        if useCustomTargets {
            profile.targetCalories = Double(customCalories) ?? profile.targetCalories
            profile.targetProtein = Double(customProtein) ?? profile.targetProtein
            profile.targetFat = Double(customFat) ?? profile.targetFat
            profile.targetCarbs = Double(customCarbs) ?? profile.targetCarbs
        } else {
            profile.recalculateTargets()
        }

        // If weight changed, create a BodyMeasurement and sync to HealthKit
        let weightChanged = abs(oldWeight - newWeight) > 0.01
        if weightChanged {
            let measurement = BodyMeasurement(
                userName: profile.userName,
                date: Date(),
                weight: newWeight
            )
            modelContext.insert(measurement)
            SupabaseManager.shared.pushBodyMeasurement(measurement)

            if profile.isHealthKitEnabled {
                Task {
                    try? await HealthKitManager.shared.saveWeight(kg: newWeight)
                }
            }
        }

        try? modelContext.save()
        SupabaseManager.shared.pushProfile(profile)
        dismiss()
    }
}

#Preview {
    ProfileView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
