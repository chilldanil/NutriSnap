import SwiftUI

struct UserPickerView: View {
    @AppStorage("currentUser") private var currentUser = ""

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Logo
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("NutriSnap")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text("Who's tracking today?")
                .font(.title3)
                .foregroundStyle(.secondary)

            // User cards
            HStack(spacing: 20) {
                ForEach(AppUser.allCases) { user in
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentUser = user.rawValue
                            // Also save to shared UserDefaults for the widget
                            UserDefaults(suiteName: "group.com.daniil.NutriSnap")?
                                .set(user.rawValue, forKey: "currentUser")
                        }
                    } label: {
                        VStack(spacing: 16) {
                            Text(user.emoji)
                                .font(.system(size: 56))

                            Text(user.displayName)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(
                                    user == .daniil
                                        ? Color.blue.opacity(0.15)
                                        : Color.pink.opacity(0.15)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(
                                    user == .daniil ? .blue.opacity(0.3) : .pink.opacity(0.3),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    UserPickerView()
        .preferredColorScheme(.dark)
}
