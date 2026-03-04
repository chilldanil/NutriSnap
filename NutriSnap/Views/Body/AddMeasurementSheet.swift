import SwiftUI
import SwiftData

struct AddMeasurementSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currentUser") private var currentUser = ""
    @Query private var profiles: [UserProfile]

    private var currentProfile: UserProfile? {
        profiles.first(where: { $0.userName == currentUser })
    }

    /// When editing an existing measurement, this holds the reference.
    let editing: BodyMeasurement?
    /// Previous measurement for pre-filling new entries.
    let previous: BodyMeasurement?

    private var isEditing: Bool { editing != nil }

    @State private var date: Date

    // Main
    @State private var weightText: String
    @State private var bodyFatText: String

    // Measurements
    @State private var chestText: String
    @State private var waistText: String
    @State private var hipsText: String
    @State private var neckText: String
    @State private var bicepText: String
    @State private var thighText: String

    @State private var showDeleteConfirmation = false

    // MARK: - New measurement (prefill from previous)
    init(previous: BodyMeasurement? = nil) {
        self.editing = nil
        self.previous = previous
        _date        = State(initialValue: Date())
        _weightText  = State(initialValue: previous?.weight.map  { String(format: "%.1f", $0) } ?? "")
        _bodyFatText = State(initialValue: previous?.bodyFat.map { String(format: "%.1f", $0) } ?? "")
        _chestText   = State(initialValue: previous?.chest.map   { String(format: "%.1f", $0) } ?? "")
        _waistText   = State(initialValue: previous?.waist.map   { String(format: "%.1f", $0) } ?? "")
        _hipsText    = State(initialValue: previous?.hips.map    { String(format: "%.1f", $0) } ?? "")
        _neckText    = State(initialValue: previous?.neck.map    { String(format: "%.1f", $0) } ?? "")
        _bicepText   = State(initialValue: previous?.bicep.map   { String(format: "%.1f", $0) } ?? "")
        _thighText   = State(initialValue: previous?.thigh.map   { String(format: "%.1f", $0) } ?? "")
    }

    // MARK: - Edit existing measurement
    init(editing: BodyMeasurement) {
        self.editing = editing
        self.previous = nil
        _date        = State(initialValue: editing.date)
        _weightText  = State(initialValue: editing.weight.map  { String(format: "%.1f", $0) } ?? "")
        _bodyFatText = State(initialValue: editing.bodyFat.map { String(format: "%.1f", $0) } ?? "")
        _chestText   = State(initialValue: editing.chest.map   { String(format: "%.1f", $0) } ?? "")
        _waistText   = State(initialValue: editing.waist.map   { String(format: "%.1f", $0) } ?? "")
        _hipsText    = State(initialValue: editing.hips.map    { String(format: "%.1f", $0) } ?? "")
        _neckText    = State(initialValue: editing.neck.map    { String(format: "%.1f", $0) } ?? "")
        _bicepText   = State(initialValue: editing.bicep.map   { String(format: "%.1f", $0) } ?? "")
        _thighText   = State(initialValue: editing.thigh.map   { String(format: "%.1f", $0) } ?? "")
    }

    private var hasAnyValue: Bool {
        [weightText, bodyFatText, chestText, waistText, hipsText, neckText, bicepText, thighText]
            .contains(where: { Double($0) != nil })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                }

                Section("Weight") {
                    measureField("Weight", text: $weightText, unit: "kg", icon: "scalemass.fill", color: .green)
                    measureField("Body Fat", text: $bodyFatText, unit: "%", icon: "percent", color: .orange)
                }

                Section("Upper Body") {
                    measureField("Chest", text: $chestText, unit: "cm", icon: "figure.arms.open", color: .blue)
                    measureField("Neck", text: $neckText, unit: "cm", icon: "circle.dashed", color: .purple)
                    measureField("Bicep", text: $bicepText, unit: "cm", icon: "figure.strengthtraining.traditional", color: .cyan)
                }

                Section("Core") {
                    measureField("Waist", text: $waistText, unit: "cm", icon: "arrow.left.and.right", color: .pink)
                    measureField("Hips", text: $hipsText, unit: "cm", icon: "arrow.left.and.right.circle", color: .mint)
                }

                Section("Lower Body") {
                    measureField("Thigh", text: $thighText, unit: "cm", icon: "figure.walk", color: .indigo)
                }
            }
            .navigationTitle(isEditing ? "Edit Measurement" : "New Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!hasAnyValue)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isEditing {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Measurement")
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .confirmationDialog("Delete this measurement?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { deleteMeasurement() }
            }
        }
    }

    private func measureField(_ title: String, text: Binding<String>, unit: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(title)
            Spacer()
            TextField("–", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .fontWeight(.semibold)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)
        }
    }

    private func save() {
        let weight = Double(weightText)
        let bodyFat = Double(bodyFatText)
        let chest = Double(chestText)
        let waist = Double(waistText)
        let hips = Double(hipsText)
        let neck = Double(neckText)
        let bicep = Double(bicepText)
        let thigh = Double(thighText)
        let day = Calendar.current.startOfDay(for: date)

        let m: BodyMeasurement

        if let existing = editing {
            // Update existing
            existing.date = day
            existing.weight = weight
            existing.bodyFat = bodyFat
            existing.chest = chest
            existing.waist = waist
            existing.hips = hips
            existing.neck = neck
            existing.bicep = bicep
            existing.thigh = thigh
            m = existing
        } else {
            // Create new
            m = BodyMeasurement(
                userName: currentUser,
                date: day,
                weight: weight,
                bodyFat: bodyFat,
                chest: chest,
                waist: waist,
                hips: hips,
                neck: neck,
                bicep: bicep,
                thigh: thigh
            )
            modelContext.insert(m)
        }

        // Update UserProfile.weight so nutrition targets stay in sync
        if let newWeight = m.weight, let profile = currentProfile {
            let weightChanged = abs(profile.weight - newWeight) > 0.01
            if weightChanged {
                profile.weight = newWeight
                if !profile.useCustomTargets {
                    profile.recalculateTargets()
                }
                SupabaseManager.shared.pushProfile(profile)
            }
        }

        try? modelContext.save()

        // Sync to HealthKit only if enabled
        let hkEnabled = currentProfile?.isHealthKitEnabled ?? false
        if hkEnabled {
            Task {
                if let w = m.weight {
                    try? await HealthKitManager.shared.saveWeight(kg: w, date: m.date)
                }
                if let bf = m.bodyFat {
                    try? await HealthKitManager.shared.saveBodyFat(percent: bf, date: m.date)
                }
            }
        }

        SupabaseManager.shared.pushBodyMeasurement(m)
        dismiss()
    }

    private func deleteMeasurement() {
        guard let existing = editing else { return }
        SupabaseManager.shared.deleteBodyMeasurement(id: existing.id.uuidString)
        modelContext.delete(existing)
        try? modelContext.save()
        dismiss()
    }
}

#Preview("New") {
    AddMeasurementSheet()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
