import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("currentUser") private var currentUser = ""
    @Query private var profiles: [UserProfile]
    @State private var isRestoring = false

    private var currentProfile: UserProfile? {
        profiles.first(where: { $0.userName == currentUser })
    }

    var body: some View {
        Group {
            if currentUser.isEmpty {
                UserPickerView()
                    .transition(.opacity)
            } else if isRestoring {
                restoringView
                    .transition(.opacity)
            } else if let profile = currentProfile, profile.isOnboarded {
                MainTabView()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                OnboardingView(userName: currentUser)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentUser)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: currentProfile?.isOnboarded)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: isRestoring)
        .onChange(of: currentUser) { _, newUser in
            guard !newUser.isEmpty else { return }
            let hasProfile = profiles.contains { $0.userName == newUser }
            if !hasProfile {
                restoreFromSupabase(userName: newUser)
            }
        }
    }

    // MARK: - Restoring spinner

    private var restoringView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Restoring data...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Restore from Supabase

    private func restoreFromSupabase(userName: String) {
        isRestoring = true
        Task {
            let manager = SupabaseManager.shared

            // 1. Restore profile
            if let profileRow = await manager.fetchProfile(userName: userName) {
                let _ = manager.restoreProfile(from: profileRow, into: modelContext)
            }

            // 2. Restore all daily logs
            let logRows = await manager.fetchDailyLogs(userName: userName)
            if !logRows.isEmpty {
                manager.restoreDailyLogs(from: logRows, into: modelContext)
            }

            // 3. Save everything
            try? modelContext.save()

            // 4. Refresh widget
            WidgetCenter.shared.reloadAllTimelines()

            isRestoring = false
        }
    }
}

#Preview("Picker") {
    ContentView()
        .modelContainer(for: [FoodItem.self, MealEntry.self, DailyLog.self, UserProfile.self], inMemory: true)
        .preferredColorScheme(.dark)
}

#Preview("Main App") {
    ContentView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
