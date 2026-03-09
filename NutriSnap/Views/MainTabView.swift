import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "flame.fill")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
                .tag(1)

            BodyTrackingView()
                .tabItem {
                    Label("Body", systemImage: "figure.arms.open")
                }
                .tag(2)

            GymTrackingView()
                .tabItem {
                    Label("Sport", systemImage: "dumbbell.fill")
                }
                .tag(3)

            MyProductsView()
                .tabItem {
                    Label("Products", systemImage: "tray.full.fill")
                }
                .tag(4)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(5)
        }
        .tint(.green)
    }
}

#Preview {
    MainTabView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
