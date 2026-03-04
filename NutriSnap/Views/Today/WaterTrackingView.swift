import SwiftUI

struct WaterTrackingView: View {
    let currentMl: Double
    let targetMl: Double
    let onAdd: (Double) -> Void

    private var progress: Double {
        guard targetMl > 0 else { return 0 }
        return min(currentMl / targetMl, 1.0)
    }

    private var remaining: Double {
        max(targetMl - currentMl, 0)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
                Text("Water")
                    .font(.headline)
                Spacer()
                Text("\(Int(currentMl)) / \(Int(targetMl)) ml")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.cyan.opacity(0.12))
                        .frame(height: 10)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 10)
                        .animation(.spring(response: 0.4), value: currentMl)
                }
            }
            .frame(height: 10)

            // Remaining text
            if remaining > 0 {
                Text("\(Int(remaining)) ml remaining")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.cyan)
                    Text("Goal reached!")
                        .foregroundStyle(.cyan)
                }
                .font(.caption.weight(.medium))
            }

            // Quick-add buttons
            HStack(spacing: 8) {
                waterButton(ml: 150, icon: "cup.and.saucer.fill")
                waterButton(ml: 250, icon: "mug.fill")
                waterButton(ml: 500, icon: "waterbottle.fill")
                waterButton(ml: 750, icon: "waterbottle.fill")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func waterButton(ml: Double, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                onAdd(ml)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.cyan)
                Text("+\(Int(ml))")
                    .font(.caption2.bold().monospacedDigit())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.cyan.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WaterTrackingView(
        currentMl: 1250,
        targetMl: 2500,
        onAdd: { _ in }
    )
    .padding()
    .preferredColorScheme(.dark)
}
