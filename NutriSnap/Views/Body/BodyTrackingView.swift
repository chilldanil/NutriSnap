import SwiftUI
import SwiftData
import Charts

struct BodyTrackingView: View {
    @AppStorage("currentUser") private var currentUser = ""
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var allMeasurements: [BodyMeasurement]

    @State private var showAddSheet = false
    @State private var chartPeriod: ChartPeriod = .threeMonths

    private var measurements: [BodyMeasurement] {
        allMeasurements.filter { $0.userName == currentUser }
    }

    private var latest: BodyMeasurement? { measurements.first }
    private var oldest: BodyMeasurement? { measurements.last }

    private var weightEntries: [BodyMeasurement] {
        measurements.filter { $0.weight != nil }
    }

    private var chartData: [BodyMeasurement] {
        let cutoff = chartPeriod.startDate
        return weightEntries.filter { $0.date >= cutoff }.reversed()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if measurements.isEmpty {
                        emptyState
                    } else {
                        weightHeader
                        weightChart
                        measurementsGrid
                        historySection
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 80)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Body")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddMeasurementSheet(previous: latest)
                    .presentationDetents([.large])
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 60)
            Image(systemName: "figure.arms.open")
                .font(.system(size: 56))
                .foregroundStyle(.green.opacity(0.5))
            Text("Track Your Progress")
                .font(.title2.bold())
            Text("Add your first measurement to start\ntracking weight and body changes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAddSheet = true
            } label: {
                Label("Add Measurement", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Weight header

    private var weightHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Weight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let w = latest?.weight {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", w))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("kg")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("–")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let change = weightChange {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Change")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 3) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text(String(format: "%+.1f kg", change))
                    }
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(change <= 0 ? .green : .orange)
                    if let first = oldest, let days = daysBetween(first.date, latest?.date ?? Date()), days > 0 {
                        Text("\(days) days")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var weightChange: Double? {
        guard weightEntries.count >= 2,
              let latest = weightEntries.first?.weight,
              let first = weightEntries.last?.weight else { return nil }
        return latest - first
    }

    private func daysBetween(_ a: Date, _ b: Date) -> Int? {
        Calendar.current.dateComponents([.day], from: a, to: b).day
    }

    // MARK: - Weight chart

    private var weightChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weight Trend")
                    .font(.headline)
                Spacer()
                Picker("Period", selection: $chartPeriod) {
                    ForEach(ChartPeriod.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            if chartData.count >= 2 {
                Chart(chartData, id: \.id) { entry in
                    if let w = entry.weight {
                        LineMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", w)
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", w)
                        )
                        .foregroundStyle(.green.opacity(0.1))
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", entry.date),
                            y: .value("Weight", w)
                        )
                        .foregroundStyle(.green)
                        .symbolSize(chartData.count > 30 ? 10 : 30)
                    }
                }
                .frame(height: 200)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f", v))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.caption2)
                    }
                }
                .chartYScale(domain: chartYDomain)
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Add at least 2 weight entries\nto see your trend")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 40)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var chartYDomain: ClosedRange<Double> {
        let weights = chartData.compactMap(\.weight)
        guard let min = weights.min(), let max = weights.max() else { return 0...100 }
        let padding = Swift.max((max - min) * 0.15, 1)
        return (min - padding)...(max + padding)
    }

    // MARK: - Body measurements grid

    private var measurementsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Measurements")
                    .font(.headline)
                Spacer()
                if let d = latest?.date {
                    Text(d, format: .dateTime.day().month(.abbreviated))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let items = measurementItems
            if items.isEmpty {
                Text("No body measurements yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(items, id: \.label) { item in
                        measurementCard(item)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private struct MeasurementItem {
        let label: String
        let value: Double
        let unit: String
        let change: Double?
        let color: Color
    }

    private var measurementItems: [MeasurementItem] {
        guard let latest else { return [] }
        let prev = measurements.count >= 2 ? measurements[1] : nil

        var items: [MeasurementItem] = []

        func add(_ label: String, _ val: Double?, _ prevVal: Double?, _ color: Color, _ unit: String = "cm") {
            guard let v = val else { return }
            let change: Double? = prevVal.map { v - $0 }
            items.append(MeasurementItem(label: label, value: v, unit: unit, change: change, color: color))
        }

        add("Body Fat", latest.bodyFat, prev?.bodyFat, .orange, "%")
        add("Chest",    latest.chest,   prev?.chest,   .blue)
        add("Waist",    latest.waist,   prev?.waist,   .pink)
        add("Hips",     latest.hips,    prev?.hips,    .mint)
        add("Neck",     latest.neck,    prev?.neck,    .purple)
        add("Bicep",    latest.bicep,   prev?.bicep,   .cyan)
        add("Thigh",    latest.thigh,   prev?.thigh,   .indigo)

        return items
    }

    private func measurementCard(_ item: MeasurementItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", item.value))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(item.color)
                Text(item.unit)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if let change = item.change, change != 0 {
                HStack(spacing: 2) {
                    Image(systemName: change > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                    Text(String(format: "%+.1f", change))
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(change > 0 ? .orange : .green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("History")
                .font(.headline)

            ForEach(measurements.prefix(20)) { entry in
                historyRow(entry)
                if entry.id != measurements.prefix(20).last?.id {
                    Divider().padding(.leading, 50)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func historyRow(_ entry: BodyMeasurement) -> some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(entry.date, format: .dateTime.day())
                    .font(.title3.bold().monospacedDigit())
                Text(entry.date, format: .dateTime.month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                if let w = entry.weight {
                    HStack(spacing: 4) {
                        Image(systemName: "scalemass.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(String(format: "%.1f kg", w))
                            .font(.subheadline.weight(.medium))
                    }
                }
                let parts = entry.filledMeasurements
                if !parts.isEmpty {
                    Text(parts.map { "\($0.label) \(String(format: "%.0f", $0.value))" }.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Chart period

enum ChartPeriod: String, CaseIterable, Identifiable {
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case all = "All"

    var id: String { rawValue }
    var label: String { rawValue }

    var startDate: Date {
        let cal = Calendar.current
        switch self {
        case .oneMonth:    return cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        case .threeMonths: return cal.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        case .sixMonths:   return cal.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        case .all:         return Date.distantPast
        }
    }
}

#Preview {
    BodyTrackingView()
        .modelContainer(PreviewContainer.shared)
        .preferredColorScheme(.dark)
}
