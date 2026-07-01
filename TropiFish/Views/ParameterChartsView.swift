import SwiftUI
import SwiftData
import Charts

/// Per-parameter trend charts with the safe range shaded as a band, so a reading
/// drifting out of bounds is visually obvious (brief §4.4). Includes a
/// 30-day / 90-day / all-time toggle, and overlays water-change events on the
/// nitrate chart so change frequency reads against the nitrate trend (§4.6).
struct ParameterChartsView: View {
    @Bindable var tank: Tank
    @State private var range: ChartRange = .month

    private var cutoff: Date? { range.cutoff }

    private func readings(for parameter: WaterParameter) -> [(date: Date, value: Double)] {
        tank.readings
            .filter { cutoff == nil || $0.timestamp >= cutoff! }
            .compactMap { reading in
                parameter.value(in: reading).map { (reading.timestamp, $0) }
            }
            .sorted { $0.date < $1.date }
    }

    private var waterChangeDates: [Date] {
        tank.waterChanges
            .map(\.timestamp)
            .filter { cutoff == nil || $0 >= cutoff! }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Picker("Range", selection: $range) {
                    ForEach(ChartRange.allCases) { r in Text(r.label).tag(r) }
                }
                .pickerStyle(.segmented)

                ForEach(WaterParameter.displayOrder) { parameter in
                    ParameterChartCard(
                        parameter: parameter,
                        points: readings(for: parameter),
                        band: band(for: parameter),
                        waterChangeDates: parameter == .nitrate ? waterChangeDates : []
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

#Preview {
    let container = try! TropiFishSchema.makeContainer(inMemory: true)
    let tank = Tank(name: "Demo", volumeLiters: 120)
    container.mainContext.insert(tank)
    for i in 0..<6 {
        let date = Calendar.current.date(byAdding: .day, value: -i * 4, to: Date())!
        tank.readings.append(TestReading(timestamp: date, nitrate: Double(10 + i * 6), ph: 7.0, temperatureC: 25, tank: tank))
    }
    return NavigationStack { ParameterChartsView(tank: tank) }
        .modelContainer(container)
}
