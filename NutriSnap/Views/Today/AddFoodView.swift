import SwiftUI
import SwiftData
import PhotosUI

struct AddFoodView: View {
    let mealType: MealType
    let onSave: ([FoodItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("currentUser") private var currentUser = ""
    @Query(sort: \FoodItem.name) private var allFoods: [FoodItem]
    @Query(sort: \SavedProduct.name) private var allSavedProducts: [SavedProduct]

    // Search
    @State private var searchText = ""
    @State private var searchResults: [EdamamFoodResult] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?

    // AI Recognition
    @State private var showImageSourcePicker = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var capturedImage: UIImage?
    @State private var isRecognizing = false
    @State private var recognitionResult: AIService.FoodRecognition?
    @State private var recognitionError: String?
    @State private var aiEstimatedGrams: Double = 100

    // AI Meal Description
    @State private var showMealDescription = false
    @State private var mealDescriptionText = ""
    @State private var isParsing = false
    @State private var parsedFoods: [AIService.ParsedFoodItem] = []
    @State private var parseError: String?

    // Detail sheet
    @State private var selectedResult: EdamamFoodResult?

    // Manual entry toggle
    @State private var showManual = false
    @State private var manName = ""
    @State private var manCalories = ""
    @State private var manProtein = ""
    @State private var manFat = ""
    @State private var manCarbs = ""
    @State private var manGrams = ""

    // Recent foods (deduplicated by name, max 10)
    private var recentFoods: [FoodItem] {
        var seen = Set<String>()
        var result: [FoodItem] = []
        for food in allFoods.reversed() {
            let key = food.name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(food)
            if result.count >= 10 { break }
        }
        return result
    }

    private var myProducts: [SavedProduct] {
        allSavedProducts.filter { $0.userName == currentUser }
    }

    private var showIdleSections: Bool {
        searchText.isEmpty && searchResults.isEmpty && !isSearching && !isRecognizing && !isParsing && parsedFoods.isEmpty
    }

    private var showRecentSection: Bool {
        showIdleSections && !recentFoods.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchHeader
                    .padding(.horizontal)
                    .padding(.top, 8)

                Divider().padding(.top, 10)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        // AI recognition
                        if isRecognizing { recognizingCard }
                        if let result = recognitionResult { aiResultCard(result) }
                        if let err = recognitionError { errorCard(err) }

                        // AI meal description results
                        if isParsing { parsingCard }
                        if !parsedFoods.isEmpty { parsedFoodsSection }
                        if let err = parseError { errorCard(err) }

                        // Search state
                        if isSearching {
                            ProgressView("Searching...")
                                .padding(32)
                        } else if let err = searchError {
                            errorCard(err)
                        } else if !searchResults.isEmpty {
                            resultsList
                        } else if !searchText.isEmpty && !isSearching {
                            noResults
                        }

                        // My Products (only when idle)
                        if showIdleSections && !myProducts.isEmpty {
                            myProductsSection
                        }

                        // Recent foods (only when idle)
                        if showRecentSection {
                            recentFoodsSection
                        }

                        // Describe meal
                        mealDescriptionSection

                        // Manual entry
                        manualSection
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add to \(mealType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(item: $selectedResult) { result in
                FoodDetailSheet(result: result, defaultGrams: aiEstimatedGrams) { foodItem in
                    onSave([foodItem])
                    dismiss()
                }
            }
            .confirmationDialog("Add Photo", isPresented: $showImageSourcePicker) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") { showCamera = true }
                }
                Button("Choose from Library") { showPhotoLibrary = true }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(source: .camera) { image in
                    handleCapturedImage(image)
                }
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showPhotoLibrary) {
                ImagePicker(source: .photoLibrary) { image in
                    handleCapturedImage(image)
                }
            }
        }
    }

    // MARK: - Search header

    private var searchHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search food...", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit { triggerSearch() }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        searchError = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button { showImageSourcePicker = true } label: {
                Image(systemName: "camera.fill")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.green, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .onChange(of: searchText) { _, newVal in
            debouncedSearch(newVal)
        }
    }

    // MARK: - Recent foods

    private var recentFoodsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.green)
                Text("Recently Added")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentFoods, id: \.id) { food in
                        Button {
                            quickAddRecent(food)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(food.name)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                HStack(spacing: 4) {
                                    Text("\(Int(food.calories))")
                                        .foregroundStyle(.green)
                                    Text("kcal")
                                        .foregroundStyle(.tertiary)
                                }
                                .font(.caption2)
                                Text("\(Int(food.grams))g")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(10)
                            .frame(width: 110, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - My Products section

    private var myProductsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "tray.full.fill")
                    .foregroundStyle(.green)
                Text("My Products")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(myProducts) { product in
                        Button {
                            quickAddProduct(product)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name)
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                    .foregroundStyle(.primary)
                                HStack(spacing: 4) {
                                    Text("\(Int(product.calories))")
                                        .foregroundStyle(.green)
                                    Text("kcal")
                                        .foregroundStyle(.tertiary)
                                }
                                .font(.caption2)
                                Text("\(Int(product.defaultGrams))g")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(10)
                            .frame(width: 110, alignment: .leading)
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(.green.opacity(0.2))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func quickAddProduct(_ product: SavedProduct) {
        let food = product.toFoodItem()
        onSave([food])
        dismiss()
    }

    // MARK: - AI recognition cards

    private var recognizingCard: some View {
        HStack(spacing: 14) {
            if let img = capturedImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Recognizing food...")
                        .font(.subheadline.weight(.medium))
                }
                Text("AI is analyzing your photo")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal).padding(.top, 12)
    }

    private func aiResultCard(_ result: AIService.FoodRecognition) -> some View {
        HStack(spacing: 14) {
            if let img = capturedImage {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").foregroundStyle(.green)
                    Text(result.foodName).font(.subheadline.bold())
                }
                Text("~\(Int(result.estimatedGrams))g · \(result.description)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        }
        .padding(14)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.green.opacity(0.3)))
        .padding(.horizontal).padding(.top, 12)
    }

    private func errorCard(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal).padding(.top, 8)
    }

    // MARK: - Meal description section

    private var mealDescriptionSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) { showMealDescription.toggle() }
            } label: {
                HStack {
                    Image(systemName: "sparkles").foregroundStyle(.purple)
                    Text("Describe your meal").font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showMealDescription ? 90 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if showMealDescription {
                VStack(spacing: 10) {
                    Text("Describe what you ate and AI will break it down into individual items with nutrition")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    TextField("e.g. 3 eggs, 2 tomatoes, splash of oil", text: $mealDescriptionText, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(10)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Button {
                        parseMealDescription()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                            Text("Analyze")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent).tint(.purple)
                    .disabled(mealDescriptionText.trimmingCharacters(in: .whitespaces).isEmpty || isParsing)
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal).padding(.top, 12)
    }

    private var parsingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
            VStack(alignment: .leading, spacing: 4) {
                Text("Analyzing your meal...")
                    .font(.subheadline.weight(.medium))
                Text("AI is breaking down ingredients")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal).padding(.top, 12)
    }

    private var parsedFoodsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(.purple)
                Text("AI Breakdown")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                let totalCal = parsedFoods.reduce(0) { $0 + $1.calories }
                Text("\(Int(totalCal)) kcal total")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.green)
            }
            .padding(.horizontal).padding(.top, 14).padding(.bottom, 6)

            ForEach(parsedFoods) { item in
                parsedFoodRow(item)
                if item.id != parsedFoods.last?.id {
                    Divider().padding(.leading, 16)
                }
            }

            // Add all button
            Button {
                addAllParsedFoods()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add all \(parsedFoods.count) items")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent).tint(.green)
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .background(Color.purple.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.purple.opacity(0.2)))
        .padding(.horizontal).padding(.top, 12)
    }

    private func parsedFoodRow(_ item: AIService.ParsedFoodItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 8) {
                    Text("\(Int(item.grams))g")
                    Text("P \(Int(item.protein))")
                    Text("F \(Int(item.fat))")
                    Text("C \(Int(item.carbs))")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("\(Int(item.calories))")
                .font(.subheadline.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
            Text("kcal")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    // MARK: - Search results

    private var resultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Results")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal).padding(.top, 14).padding(.bottom, 6)

            ForEach(searchResults) { item in
                Button { selectedResult = item } label: {
                    searchResultRow(item)
                }
                .buttonStyle(.plain)

                if item.id != searchResults.last?.id {
                    Divider().padding(.leading, 76)
                }
            }
        }
    }

    private func searchResultRow(_ item: EdamamFoodResult) -> some View {
        HStack(spacing: 12) {
            if let urlStr = item.imageURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Color(.tertiarySystemGroupedBackground)
                            .overlay(Image(systemName: "fork.knife").foregroundStyle(.tertiary))
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: "fork.knife").foregroundStyle(.tertiary))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.label).font(.subheadline.weight(.medium)).lineLimit(1)
                HStack(spacing: 12) {
                    Text("\(Int(item.caloriesPer100g)) kcal").foregroundStyle(.green)
                    Text("P \(Int(item.proteinPer100g))")
                    Text("F \(Int(item.fatPer100g))")
                    Text("C \(Int(item.carbsPer100g))")
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Text("per 100g").font(.caption2).foregroundStyle(.tertiary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal).padding(.vertical, 10)
    }

    private var noResults: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.secondary)
            Text("No results for \"\(searchText)\"").font(.subheadline).foregroundStyle(.secondary)
            Text("Try a different name or enter manually").font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity).padding(32)
    }

    // MARK: - Manual entry

    private var manualSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) { showManual.toggle() }
            } label: {
                HStack {
                    Image(systemName: "pencil.line").foregroundStyle(.green)
                    Text("Enter manually").font(.subheadline.weight(.medium))
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showManual ? 90 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if showManual {
                VStack(spacing: 10) {
                    manualField("Food name", text: $manName, keyboard: .default)
                    HStack(spacing: 10) {
                        manualField("Grams", text: $manGrams, keyboard: .decimalPad)
                        manualField("Calories", text: $manCalories, keyboard: .decimalPad)
                    }
                    HStack(spacing: 10) {
                        manualField("Protein", text: $manProtein, keyboard: .decimalPad)
                        manualField("Fat", text: $manFat, keyboard: .decimalPad)
                        manualField("Carbs", text: $manCarbs, keyboard: .decimalPad)
                    }
                    Button { saveManual() } label: {
                        Text("Save").font(.subheadline.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent).tint(.green)
                    .disabled(manName.isEmpty || manCalories.isEmpty)
                }
                .padding(.horizontal, 14).padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal).padding(.top, 16)
    }

    private func manualField(_ title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(.tertiary)
            TextField("0", text: text)
                .keyboardType(keyboard).padding(10)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Logic

    private func debouncedSearch(_ query: String) {
        searchTask?.cancel()
        searchError = nil
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []; return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await performSearch(query: query)
        }
    }

    private func triggerSearch() {
        searchTask?.cancel()
        Task { await performSearch(query: searchText) }
    }

    @MainActor
    private func performSearch(query: String) async {
        isSearching = true; searchError = nil
        do {
            let results = try await EdamamService.shared.searchFood(query: query)
            guard !Task.isCancelled else { return }
            searchResults = results
        } catch {
            guard !Task.isCancelled else { return }
            searchError = "Search failed. Check your connection."
            searchResults = []
        }
        isSearching = false
    }

    private func handleCapturedImage(_ image: UIImage) {
        capturedImage = image
        isRecognizing = true
        recognitionResult = nil; recognitionError = nil

        Task {
            do {
                let result = try await AIService.shared.recognizeFood(image: image)
                await MainActor.run {
                    recognitionResult = result
                    isRecognizing = false
                    aiEstimatedGrams = result.estimatedGrams
                    searchText = result.foodName
                    triggerSearch()
                }
            } catch {
                await MainActor.run {
                    isRecognizing = false
                    recognitionError = "Couldn't identify food: \(error.localizedDescription)"
                }
            }
        }
    }

    private func parseMealDescription() {
        let text = mealDescriptionText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        isParsing = true
        parseError = nil
        parsedFoods = []

        Task {
            do {
                let items = try await AIService.shared.parseMealDescription(text: text)
                await MainActor.run {
                    parsedFoods = items
                    isParsing = false
                }
            } catch {
                await MainActor.run {
                    isParsing = false
                    parseError = "Couldn't parse meal: \(error.localizedDescription)"
                }
            }
        }
    }

    private func addAllParsedFoods() {
        let foods = parsedFoods.map { item in
            FoodItem(
                name: item.name,
                calories: item.calories,
                protein: item.protein,
                fat: item.fat,
                carbs: item.carbs,
                grams: item.grams
            )
        }
        onSave(foods)
        dismiss()
    }

    private func quickAddRecent(_ food: FoodItem) {
        let newFood = FoodItem(
            name: food.name,
            calories: food.calories,
            protein: food.protein,
            fat: food.fat,
            carbs: food.carbs,
            grams: food.grams,
            edamamFoodId: food.edamamFoodId
        )
        onSave([newFood])
        dismiss()
    }

    private func saveManual() {
        let food = FoodItem(
            name: manName,
            calories: Double(manCalories) ?? 0,
            protein: Double(manProtein) ?? 0,
            fat: Double(manFat) ?? 0,
            carbs: Double(manCarbs) ?? 0,
            grams: Double(manGrams) ?? 0
        )
        onSave([food])
        dismiss()
    }
}

#Preview {
    AddFoodView(mealType: .lunch) { _ in }
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
