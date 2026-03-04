import SwiftUI
import SwiftData

struct AddProductSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("currentUser") private var currentUser = ""

    /// If non-nil, we're editing an existing product
    let existingProduct: SavedProduct?

    @State private var name: String
    @State private var gramsText: String
    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var fatText: String
    @State private var carbsText: String

    init(existingProduct: SavedProduct? = nil) {
        self.existingProduct = existingProduct
        _name = State(initialValue: existingProduct?.name ?? "")
        _gramsText = State(initialValue: existingProduct.map { String(format: "%.0f", $0.defaultGrams) } ?? "100")
        _caloriesText = State(initialValue: existingProduct.map { String(format: "%.0f", $0.calories) } ?? "")
        _proteinText = State(initialValue: existingProduct.map { String(format: "%.1f", $0.protein) } ?? "")
        _fatText = State(initialValue: existingProduct.map { String(format: "%.1f", $0.fat) } ?? "")
        _carbsText = State(initialValue: existingProduct.map { String(format: "%.1f", $0.carbs) } ?? "")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && Double(caloriesText) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Product") {
                    TextField("Name", text: $name)
                        .autocorrectionDisabled()

                    HStack {
                        Text("Serving size")
                        Spacer()
                        TextField("100", text: $gramsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("g")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    nutrientField("Calories", text: $caloriesText, unit: "kcal", color: .green)
                    nutrientField("Protein", text: $proteinText, unit: "g", color: .blue)
                    nutrientField("Fat", text: $fatText, unit: "g", color: .orange)
                    nutrientField("Carbs", text: $carbsText, unit: "g", color: .pink)
                } header: {
                    Text("Nutrition (per serving)")
                } footer: {
                    Text("Enter values for the serving size above")
                }
            }
            .navigationTitle(existingProduct == nil ? "New Product" : "Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private func nutrientField(_ title: String, text: Binding<String>, unit: String, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let product = existingProduct {
            // Update existing
            product.name = trimmedName
            product.defaultGrams = Double(gramsText) ?? 100
            product.calories = Double(caloriesText) ?? 0
            product.protein = Double(proteinText) ?? 0
            product.fat = Double(fatText) ?? 0
            product.carbs = Double(carbsText) ?? 0
            try? modelContext.save()
            SupabaseManager.shared.pushSavedProduct(product)
        } else {
            // Create new
            let product = SavedProduct(
                name: trimmedName,
                calories: Double(caloriesText) ?? 0,
                protein: Double(proteinText) ?? 0,
                fat: Double(fatText) ?? 0,
                carbs: Double(carbsText) ?? 0,
                defaultGrams: Double(gramsText) ?? 100
            )
            product.userName = currentUser
            modelContext.insert(product)
            try? modelContext.save()
            SupabaseManager.shared.pushSavedProduct(product)
        }

        dismiss()
    }
}

#Preview {
    AddProductSheet()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
