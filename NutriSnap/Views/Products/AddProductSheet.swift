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

    // Label scanning
    @State private var showImageSourcePicker = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var isScanning = false
    @State private var scanError: String?
    @State private var scannedImage: UIImage?

    // Barcode scanning
    @State private var showBarcodeScanner = false
    @State private var isLookingUpBarcode = false
    @State private var pendingBarcode: String?

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
                // Scan section (only for new products)
                if existingProduct == nil {
                    Section {
                        scanSectionContent
                    } footer: {
                        Text("Scan a barcode or nutrition label to auto-fill all fields")
                    }
                }

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
            .confirmationDialog("Scan Label", isPresented: $showImageSourcePicker) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { showCamera = true }
                }
                Button("Choose from Library") { showPhotoLibrary = true }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(source: .camera) { image in
                    handleScannedImage(image)
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showPhotoLibrary) {
                ImagePicker(source: .photoLibrary) { image in
                    handleScannedImage(image)
                }
            }
            .fullScreenCover(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(scannedCode: $pendingBarcode)
                    .ignoresSafeArea()
            }
            .onChange(of: pendingBarcode) { _, barcode in
                guard let barcode else { return }
                pendingBarcode = nil
                handleScannedBarcode(barcode)
            }
        }
    }

    // MARK: - Scan section

    @ViewBuilder
    private var scanSectionContent: some View {
        if isScanning {
            HStack(spacing: 14) {
                if let img = scannedImage {
                    Image(uiImage: img)
                        .resizable().scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Reading label...")
                            .font(.subheadline.weight(.medium))
                    }
                    Text("AI is extracting nutrition data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        } else if isLookingUpBarcode {
            HStack(spacing: 14) {
                Image(systemName: "barcode.viewfinder")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .frame(width: 48, height: 48)
                    .background(Color.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Looking up product...")
                            .font(.subheadline.weight(.medium))
                    }
                    Text("Searching OpenFoodFacts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        } else if let error = scanError {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Button {
                        scanError = nil
                        showBarcodeScanner = true
                    } label: {
                        Label("Scan Barcode", systemImage: "barcode.viewfinder")
                            .font(.subheadline.weight(.medium))
                    }
                    Button {
                        scanError = nil
                        showImageSourcePicker = true
                    } label: {
                        Label("Scan Label", systemImage: "camera.fill")
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
        } else {
            Button {
                showBarcodeScanner = true
            } label: {
                scanRowLabel(
                    icon: "barcode.viewfinder",
                    title: "Scan Barcode",
                    subtitle: "Find product by EAN code"
                )
            }
            .buttonStyle(.plain)

            Button {
                showImageSourcePicker = true
            } label: {
                scanRowLabel(
                    icon: "camera.viewfinder",
                    title: "Scan Nutrition Label",
                    subtitle: "Auto-fill from package photo"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func scanRowLabel(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 40, height: 40)
                .background(Color.green.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Scan logic

    private func handleScannedBarcode(_ barcode: String) {
        isLookingUpBarcode = true
        scanError = nil

        Task {
            do {
                let result = try await OpenFoodFactsService.shared.lookupBarcode(barcode)
                await MainActor.run {
                    isLookingUpBarcode = false
                    applyBarcodeResult(result)
                }
            } catch {
                await MainActor.run {
                    isLookingUpBarcode = false
                    scanError = error.localizedDescription
                }
            }
        }
    }

    private func applyBarcodeResult(_ result: OpenFoodFactsService.ProductResult) {
        let serving = result.servingGrams ?? 100
        let scale = serving / 100.0

        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            if let brand = result.brand {
                name = "\(brand) – \(result.name)"
            } else {
                name = result.name
            }
        }

        gramsText = String(format: "%.0f", serving)
        caloriesText = String(format: "%.0f", result.caloriesPer100g * scale)
        proteinText = String(format: "%.1f", result.proteinPer100g * scale)
        fatText = String(format: "%.1f", result.fatPer100g * scale)
        carbsText = String(format: "%.1f", result.carbsPer100g * scale)
    }

    private func handleScannedImage(_ image: UIImage) {
        scannedImage = image
        isScanning = true
        scanError = nil

        Task {
            do {
                let result = try await AIService.shared.parseNutritionLabel(image: image)
                await MainActor.run {
                    applyLabelResult(result)
                    isScanning = false
                }
            } catch {
                await MainActor.run {
                    isScanning = false
                    scanError = "Couldn't read label: \(error.localizedDescription)"
                }
            }
        }
    }

    private func applyLabelResult(_ result: AIService.NutritionLabelResult) {
        let serving = result.suggestedServingGrams
        let scale = serving / 100.0

        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = result.productName
        }

        gramsText = String(format: "%.0f", serving)
        caloriesText = String(format: "%.0f", result.caloriesPer100g * scale)
        proteinText = String(format: "%.1f", result.proteinPer100g * scale)
        fatText = String(format: "%.1f", result.fatPer100g * scale)
        carbsText = String(format: "%.1f", result.carbsPer100g * scale)
    }

    // MARK: - Fields

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
