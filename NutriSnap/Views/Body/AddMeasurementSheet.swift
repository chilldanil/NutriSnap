import SwiftUI
import SwiftData

struct AddMeasurementSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currentUser") private var currentUser = ""

    let previous: BodyMeasurement?

    @State private var date = Date()

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

    init(previous: BodyMeasurement? = nil) {
        self.previous = previous
        _weightText  = State(initialValue: previous?.weight.map  { String(format: "%.1f", $0) } ?? "")
        _bodyFatText = State(initialValue: previous?.bodyFat.map { String(format: "%.1f", $0) } ?? "")
        _chestText   = State(initialValue: previous?.chest.map   { String(format: "%.1f", $0) } ?? "")
        _waistText   = State(initialValue: previous?.waist.map   { String(format: "%.1f", $0) } ?? "")
        _hipsText    = State(initialValue: previous?.hips.map    { String(format: "%.1f", $0) } ?? "")
        _neckText    = State(initialValue: previous?.neck.map    { String(format: "%.1f", $0) } ?? "")
        _bicepText   = State(initialValue: previous?.bicep.map   { String(format: "%.1f", $0) } ?? "")
        _thighText   = State(initialValue: previous?.thigh.map   { String(format: "%.1f", $0) } ?? "")
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
            .navigationTitle("New Measurement")
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
        let m = BodyMeasurement(
            userName: currentUser,
            date: Calendar.current.startOfDay(for: date),
            weight: Double(weightText),
            bodyFat: Double(bodyFatText),
            chest: Double(chestText),
            waist: Double(waistText),
            hips: Double(hipsText),
            neck: Double(neckText),
            bicep: Double(bicepText),
            thigh: Double(thighText)
        )
        modelContext.insert(m)
        try? modelContext.save()

        Task {
            if let w = m.weight {
                try? await HealthKitManager.shared.saveWeight(kg: w, date: m.date)
            }
            if let bf = m.bodyFat {
                try? await HealthKitManager.shared.saveBodyFat(percent: bf, date: m.date)
            }
        }

        SupabaseManager.shared.pushBodyMeasurement(m)
        dismiss()
    }
}

#Preview {
    AddMeasurementSheet()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
