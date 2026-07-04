import SwiftUI
import SwiftData
import Charts

/// Trend charts for a tank's water parameters (brief §4.4). Two modes:
///
/// - **Individual** — one chart per parameter with its safe range shaded, so a
///   reading drifting out of bounds is obvious. Water-change events overlay the
///   nitrate chart so change frequency reads against the nitrate trend (§4.6).
/// - **Combined** — several parameters plotted together on one chart. Because
///   their units are incomparable (ppm vs dKH vs °C vs pH), each series is
///   normalised to *% of its own healthy range*, so a value sitting in the green
///   0–100% band is fine and anything spiking above/below is drifting. A scrubber
///   reads out the real value + unit for every series at a chosen date. This is
///   the multi-parameter view competitors were criticised for lacking.
struct ParameterChartsView: View {
    @Bindable var tank: Tank

    @State private var range: ChartRange = .month
    #if DEBUG
    @State private var mode: ChartMode = ProcessInfo.processInfo.arguments.contains("-combinedCharts") ? .combined : .individual
    #else
    @State private var mode: ChartMode = .individual
    #endif
    /// Which parameters the combined chart overlays; defaults to the cycle set.
    @State private var combinedSelection: Set<WaterParameter> = [.ammonia, .nitrite, .nitrate, .ph]

    private var cutoff: Date? { range.cutoff }

    private func readings(for parameter: WaterParameter) -> [(date: Date, value: Double)] {
        tank.readings
            .filter { cutoff == nil || $0.timestamp >= cutoff! }
            .compactMap { reading in
                parameter.value(in: reading).map { (reading.timestamp, $0) }
            }
            .sorted { $0.date < $1.date }
    }

    /// Readings in the current window, oldest-first — the scrubber's source.
    private var readingsInRange: [TestReading] {
        tank.readings
            .filter { cutoff == nil || $0.timestamp >= cutoff! }
            .sorted { $0.timestamp < $1.timestamp }
    }

    private var waterChangeDates: [Date] {
        tank.waterChanges
            .map(\.timestamp)
            .filter { cutoff == nil || $0 >= cutoff! }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("Mode", selection: $mode) {
                    ForEach(ChartMode.allCases) { m in Text(m.label).tag(m) }
                }
                .pickerStyle(.segmented)

                Picker("Range", selection: $range) {
                    ForEach(ChartRange.allCases) { r in Text(r.label).tag(r) }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .individual:
                    ForEach(WaterParameter.displayOrder) { parameter in
                        ParameterChartCard(
                            parameter: parameter,
                            points: readings(for: parameter),
                            band: band(for: parameter),
                            waterChangeDates: parameter == .nitrate ? waterChangeDates : []
                        )
                    }
                case .combined:
                    CombinedChartCard(
                        targets: tank.targets,
                        selection: $combinedSelection,
                        readings: readingsInRange,
                        waterChangeDates: waterChangeDates
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Shaded safe band per parameter: ammonia uses 0→caution threshold (§6.2);
    /// nitrite has none (zero-tolerance, shown as a line at 0, §6.3).
    private func band(for parameter: WaterParameter) -> ClosedRange<Double>? {
        switch parameter {
        case .ammonia: return 0...tank.targets.ammoniaThresholds.caution
        case .nitrite: return nil
        default:       return parameter.range(in: tank.targets)
        }
    }
}

// MARK: - Combined overlay

/// The multi-parameter overlay: a parameter multi-select, one normalised chart
/// with a colour legend, and a drag-to-read scrubber showing real values.
private struct CombinedChartCard: View {
    let targets: ParameterTargets
    @Binding var selection: Set<WaterParameter>
    let readings: [TestReading]
    let waterChangeDates: [Date]

    /// The date the user is scrubbing to (nil = not scrubbing).
    @State private var rawSelectedDate: Date?

    /// One normalised sample for a series.
    private struct Sample: Identifiable {
        let id = UUID()
        let parameter: WaterParameter
        let date: Date
        let normalized: Double
        let real: Double
    }

    /// Ordered selected parameters (stable display order).
    private var selected: [WaterParameter] {
        WaterParameter.displayOrder.filter { selection.contains($0) }
    }

    private var samples: [Sample] {
        selected.flatMap { parameter -> [Sample] in
            readings.compactMap { reading in
                parameter.value(in: reading).map { value in
                    Sample(parameter: parameter,
                           date: reading.timestamp,
                           normalized: parameter.normalized(value, in: targets),
                           real: value)
                }
            }
        }
    }

    /// The reading nearest the scrubbed date, for the readout callout.
    private var scrubbedReading: TestReading? {
        guard let target = rawSelectedDate else { return nil }
        return readings.min {
            abs($0.timestamp.timeIntervalSince(target)) < abs($1.timestamp.timeIntervalSince(target))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            parameterPicker

            if selected.isEmpty {
                placeholder("Select one or more parameters to overlay.")
            } else if samples.count < 2 {
                placeholder("Log at least two readings to see a combined trend.")
            } else {
                chart
                    .frame(height: 240)
                legend
                Text("Each line is scaled to its own healthy range: the green 0–100% band is ideal. Touch and drag to read exact values.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private var parameterPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(WaterParameter.displayOrder) { parameter in
                let isOn = selection.contains(parameter)
                Button {
                    if isOn { selection.remove(parameter) } else { selection.insert(parameter) }
                    Haptics.selection()
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(parameter.seriesColor)
                            .frame(width: 9, height: 9)
                            .opacity(isOn ? 1 : 0.35)
                        Text(parameter.displayName)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 8)
                    .background(
                        isOn ? parameter.seriesColor.opacity(0.16) : Color.secondary.opacity(0.10),
                        in: Capsule()
                    )
                    .foregroundStyle(isOn ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var chart: some View {
        Chart {
            // Healthy 0–100% zone.
            RectangleMark(
                yStart: .value("Low", 0),
                yEnd: .value("High", 100)
            )
            .foregroundStyle(TrafficLight.green.color.opacity(0.10))

            ForEach(waterChangeDates, id: \.self) { date in
                RuleMark(x: .value("Water change", date))
                    .foregroundStyle(.blue.opacity(0.25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }

            ForEach(samples) { sample in
                LineMark(
                    x: .value("Date", sample.date),
                    y: .value("% of healthy range", sample.normalized),
                    series: .value("Parameter", sample.parameter.displayName)
                )
                .foregroundStyle(by: .value("Parameter", sample.parameter.displayName))
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", sample.date),
                    y: .value("% of healthy range", sample.normalized)
                )
                .foregroundStyle(by: .value("Parameter", sample.parameter.displayName))
                .symbolSize(20)
            }

            if let reading = scrubbedReading {
                RuleMark(x: .value("Selected", reading.timestamp))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: .center, overflowResolution: .init(x: .fit, y: .disabled)) {
                        readout(for: reading)
                    }
            }
        }
        .chartForegroundStyleScale(domain: selected.map(\.displayName),
                                   range: selected.map(\.seriesColor))
        .chartLegend(.hidden) // custom legend below shows live values
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) { Text("\(Int(v))%") }
                }
            }
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartXSelection(value: $rawSelectedDate)
    }

    private func readout(for reading: TestReading) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(reading.timestamp.formatted(date: .abbreviated, time: .omitted))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(selected) { parameter in
                if let value = parameter.value(in: reading) {
                    HStack(spacing: 5) {
                        Circle().fill(parameter.seriesColor).frame(width: 7, height: 7)
                        Text(parameter.displayName)
                            .font(.caption2)
                        Spacer(minLength: 8)
                        Text(parameter.formatted(value))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                    }
                }
            }
        }
        .padding(8)
        .frame(width: 190, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.15)))
    }

    /// Legend row per series with its latest real value.
    private var legend: some View {
        VStack(spacing: 6) {
            ForEach(selected) { parameter in
                HStack(spacing: 8) {
                    Circle().fill(parameter.seriesColor).frame(width: 9, height: 9)
                    Text(parameter.displayName)
                        .font(.caption)
                    Spacer()
                    if let latest = latestValue(for: parameter) {
                        Text(parameter.formatted(latest))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func latestValue(for parameter: WaterParameter) -> Double? {
        readings.reversed().lazy.compactMap { parameter.value(in: $0) }.first
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Individual per-parameter card

private struct ParameterChartCard: View {
    let parameter: WaterParameter
    let points: [(date: Date, value: Double)]
    let band: ClosedRange<Double>?
    let waterChangeDates: [Date]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(parameter.displayName)
                .font(.headline)

            if points.count < 2 {
                Text(points.isEmpty ? "No readings in this range." : "Log at least two readings to see a trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            } else {
                chart
                    .frame(height: 170)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private var chart: some View {
        Chart {
            if let band, let first = points.first?.date, let last = points.last?.date {
                RectangleMark(
                    xStart: .value("Start", first),
                    xEnd: .value("End", last),
                    yStart: .value("Low", band.lowerBound),
                    yEnd: .value("High", band.upperBound)
                )
                .foregroundStyle(TrafficLight.green.color.opacity(0.14))
            }

            if parameter == .nitrite {
                RuleMark(y: .value("Zero", 0))
                    .foregroundStyle(TrafficLight.green.color.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }

            ForEach(waterChangeDates, id: \.self) { date in
                RuleMark(x: .value("Water change", date))
                    .foregroundStyle(.blue.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }

            ForEach(points, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value(parameter.displayName, point.value)
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.monotone)

                PointMark(
                    x: .value("Date", point.date),
                    y: .value(parameter.displayName, point.value)
                )
                .foregroundStyle(pointColor(point.value))
                .symbolSize(28)
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
    }

    /// Colour each point by whether it's inside the shaded band.
    private func pointColor(_ value: Double) -> Color {
        if parameter == .nitrite {
            return value > 0 ? TrafficLight.red.color : TrafficLight.green.color
        }
        guard let band else { return Color.accentColor }
        return band.contains(value) ? TrafficLight.green.color : TrafficLight.amber.color
    }
}

// MARK: - Supporting types

/// Whether the trends screen shows one chart per parameter or a combined overlay.
enum ChartMode: String, CaseIterable, Identifiable {
    case individual
    case combined

    var id: String { rawValue }

    var label: String {
        switch self {
        case .individual: return "Individual"
        case .combined:   return "Combined"
        }
    }
}

/// Chart time window (brief §4.4: at minimum 30 days / 90 days / all-time).
enum ChartRange: String, CaseIterable, Identifiable {
    case month
    case quarter
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .month:   return "30 days"
        case .quarter: return "90 days"
        case .all:     return "All"
        }
    }

    var cutoff: Date? {
        switch self {
        case .month:   return Calendar.current.date(byAdding: .day, value: -30, to: Date())
        case .quarter: return Calendar.current.date(byAdding: .day, value: -90, to: Date())
        case .all:     return nil
        }
    }
}

extension WaterParameter {
    /// Distinct line colour for the combined overlay (and its legend/chips).
    var seriesColor: Color {
        switch self {
        case .ammonia:     return .red
        case .nitrite:     return .orange
        case .nitrate:     return .yellow
        case .kh:          return .teal
        case .gh:          return .mint
        case .ph:          return .blue
        case .temperature: return .purple
        }
    }
}

#Preview {
    let container = try! TropiFishSchema.makeContainer(inMemory: true)
    let tank = Tank(name: "Demo", volumeLiters: 120)
    container.mainContext.insert(tank)
    for i in 0..<8 {
        let date = Calendar.current.date(byAdding: .day, value: -i * 4, to: Date())!
        tank.readings.append(TestReading(
            timestamp: date,
            ammoniaTAN: Double(i) * 0.1,
            nitrite: i == 2 ? 0.25 : 0,
            nitrate: Double(10 + i * 6),
            kh: 6, gh: 8,
            ph: 7.0 + Double(i) * 0.05,
            temperatureC: 25, tank: tank))
    }
    return NavigationStack { ParameterChartsView(tank: tank) }
        .modelContainer(container)
}
