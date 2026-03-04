import SwiftUI

struct CalorieProgressView: View {
    let eaten: Double
    let target: Double

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(eaten / target, 1.5)
    }

    private var remaining: Int {
        max(0, Int(target - eaten))
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color.green.opacity(0.12), lineWidth: 22)

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [.green.opacity(0.6), .green],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * animatedProgress)
                    ),
                    style: StrokeStyle(lineWidth: 22, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center text
            VStack(spacing: 2) {
                Text("\(Int(eaten))")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())

                Text("/ \(Int(target)) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(remaining) left")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .frame(width: 200, height: 200)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: eaten) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                animatedProgress = progress
            }
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        CalorieProgressView(eaten: 1151, target: 2200)
        CalorieProgressView(eaten: 0, target: 2200)
        CalorieProgressView(eaten: 2200, target: 2200)
    }
    .padding()
    .preferredColorScheme(.dark)
}
