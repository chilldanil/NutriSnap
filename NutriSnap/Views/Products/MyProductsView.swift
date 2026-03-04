import SwiftUI
import SwiftData

struct MyProductsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUser") private var currentUser = ""
    @Query(sort: \SavedProduct.name) private var allProducts: [SavedProduct]

    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var productToEdit: SavedProduct?

    private var products: [SavedProduct] {
        let userProducts = allProducts.filter { $0.userName == currentUser }
        if searchText.isEmpty {
            return userProducts
        }
        return userProducts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allProducts.filter({ $0.userName == currentUser }).isEmpty {
                    emptyState
                } else {
                    productList
                }
            }
            .navigationTitle("My Products")
            .searchable(text: $searchText, prompt: "Search products")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddProductSheet()
            }
            .sheet(item: $productToEdit) { product in
                AddProductSheet(existingProduct: product)
            }
        }
    }

    // MARK: - Product List

    private var productList: some View {
        List {
            ForEach(products) { product in
                productRow(product)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        productToEdit = product
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteProduct(product)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Product Row

    private func productRow(_ product: SavedProduct) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(product.name)
                    .font(.body.weight(.medium))
                Spacer()
                Text("\(Int(product.defaultGrams))g")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                nutrientBadge(value: product.calories, unit: "kcal", color: .green)
                nutrientBadge(value: product.protein, unit: "P", color: .blue)
                nutrientBadge(value: product.fat, unit: "F", color: .orange)
                nutrientBadge(value: product.carbs, unit: "C", color: .pink)
            }
        }
        .padding(.vertical, 4)
    }

    private func nutrientBadge(value: Double, unit: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(value.truncatingRemainder(dividingBy: 1) == 0
                 ? "\(Int(value)) \(unit)"
                 : String(format: "%.1f %@", value, unit))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Products", systemImage: "tray")
        } description: {
            Text("Save your favorite products here for quick access when logging food")
        } actions: {
            Button {
                showAddSheet = true
            } label: {
                Text("Add Product")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    // MARK: - Delete

    private func deleteProduct(_ product: SavedProduct) {
        let productId = product.id.uuidString
        modelContext.delete(product)
        try? modelContext.save()
        SupabaseManager.shared.deleteSavedProduct(id: productId)
    }
}

#Preview {
    MyProductsView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
