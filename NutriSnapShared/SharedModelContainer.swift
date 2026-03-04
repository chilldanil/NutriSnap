import SwiftData
import Foundation

enum SharedModelContainer {
    nonisolated static let appGroupIdentifier = "group.com.daniil.NutriSnap"
    nonisolated static let migrationKey = "NutriSnap_didMigrateToAppGroup"

    @MainActor
    static func create() throws -> ModelContainer {
        let schema = Schema([
            FoodItem.self,
            MealEntry.self,
            DailyLog.self,
            UserProfile.self,
            SavedProduct.self,
        ])

        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            fatalError("Failed to find App Group container")
        }

        let newStoreURL = groupURL.appending(path: "NutriSnap.store")

        // One-time migration: copy old default store → App Group
        migrateIfNeeded(to: newStoreURL)

        let config = ModelConfiguration(
            schema: schema,
            url: newStoreURL,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Migration

    /// Copies the old default SwiftData store to the new App Group location.
    /// Uses a UserDefaults flag so it only runs once, even if the new store
    /// was already created empty by a previous launch.
    private static func migrateIfNeeded(to newURL: URL) {
        let fm = FileManager.default

        // Already migrated successfully before → skip
        if UserDefaults.standard.bool(forKey: migrationKey) { return }

        // Find the old default SwiftData store
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }
        let oldStoreURL = appSupport.appending(path: "default.store")

        guard fm.fileExists(atPath: oldStoreURL.path(percentEncoded: false)) else {
            // No old store → nothing to migrate
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        // Remove any empty new store that was created before migration
        let suffixes = ["", "-shm", "-wal"]
        for suffix in suffixes {
            let dst = URL(fileURLWithPath: newURL.path(percentEncoded: false) + suffix)
            try? fm.removeItem(at: dst)
        }

        // Copy old store files to new location
        for suffix in suffixes {
            let src = URL(fileURLWithPath: oldStoreURL.path(percentEncoded: false) + suffix)
            let dst = URL(fileURLWithPath: newURL.path(percentEncoded: false) + suffix)

            guard fm.fileExists(atPath: src.path(percentEncoded: false)) else { continue }

            do {
                try fm.createDirectory(
                    at: dst.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try fm.copyItem(at: src, to: dst)
            } catch {
                print("Migration: failed to copy \(src.lastPathComponent): \(error)")
            }
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
        print("Migration: old store copied to App Group container")
    }
}
