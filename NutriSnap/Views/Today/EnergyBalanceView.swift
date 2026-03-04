import SwiftUI

/// Displays the energy balance breakdown:
/// - Active calories (exercise/movement from Apple Watch / iPhone)
/// - Basal calories (BMR — resting metabolic rate, Apple Watch only)
/// - TDEE (Total Daily Energy Expenditure = Active + Basal)
/// - Net balance (Consumed - TDEE)
///
/// Science: TDEE is the gold standard for understanding caloric balance.
/// Deficit = weight loss, Surplus = weight gain, Balance = maintenance.
struct EnergyBalanceView: View {
    let consumed: Double
    let active: Double
    let basal: Double

    private var tdee: Double { active + basal }
    private var net: Double { consumed - tdee }

    private var netColor: Color {
        if net < -100 { return .blue }     // Deficit
        if net > 100 { return .orange }    // Surplus
        return .green                       // Near balance
    }

    private var netLabel: String {
        if net < -100 { return "Deficit" }
        if net > 100 { return "Surplus" }
        return "Balance"
    }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "flame.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                Text("Energy Balance")
                    .font(.headline)
                Spacer()
            }

            // Net balance — large center display
            VStack(spacing: 4) {
                Text("\(Int(net))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(netColor)
                    .contentTransition(.numericText())

                Text("kcal \(netLabel)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(netColor.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            // Breakdown bars
            VStack(spacing: 8) {
                energyRow(
                    icon: "fork.knife",
                    label: "Consumed",
                    value: consumed,
                    color: .green
                )

                energyRow(
                    icon: "figure.run",
                    label: "Active",
                    value: active,
                    color: .orange
                )

                energyRow(
                    icon: "bed.double.fill",
                    label: "BMR (rest)",
                    value: basal,
                    color: .purple
                )

                Divider()

                energyRow(
                    icon: "bolt.fill",
                    label: "TDEE (total burned)",
                    value: tdee,
                    color: .red
                )
            }

            // Explanation footer
            if basal == 0 {
                HStack(spacing: 6) {
                    Image(systemName: "applewatch")
                        .font(.caption)
                    Text("Connect Apple Watch for BMR data")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func energyRow(icon: String, label: String, value: Double, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(Int(value)) kcal")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        EnergyBalanceView(consumed: 1450, active: 320, basal: 1650)
        EnergyBalanceView(consumed: 2200, active: 150, basal: 1500)
        EnergyBalanceView(consumed: 800, active: 50, basal: 0)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}
