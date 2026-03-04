import SwiftUI

struct MacroRingsView: View {
    let protein: Double
    let proteinTarget: Double
    let fat: Double
    let fatTarget: Double
    let carbs: Double
    let carbsTarget: Double

    var body: some View {
        HStack(spacing: 20) {
            MacroRing(label: "Protein", current: protein, target: proteinTarget, color: .blue)
            MacroRing(label: "Fat", current: fat, target: fatTarget, color: .orange)
            MacroRing(label: "Carbs", current: carbs, target: carbsTarget, color: .pink)
        }
    }
}

// MARK: - Single ring

struct MacroRing: View {
    let label: String
    let current: Double
    let target: Double
    let color: Color

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(current / target, 1.0)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.12), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(current))")
                    .font(.system(.callout, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
            }
            .frame(width: 72, height: 72)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text("\(Int(current))/\(Int(target))g")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.15)) {
                animatedProgress = progress
            }
        }
        .onChange(of: current) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                animatedProgress = progress
            }
        }
    }
}

#Preview {
    MacroRingsView(
        protein: 82, proteinTarget: 176,
        fat: 28, fatTarget: 61,
        carbs: 131, carbsTarget: 210
    )
    .padding()
    .preferredColorScheme(.dark)
}
