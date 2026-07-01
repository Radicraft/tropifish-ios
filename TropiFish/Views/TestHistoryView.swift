import SwiftUI
import SwiftData

/// Chronological log of a tank's tests and water changes (brief §4.3), each
/// editable and deletable. Water changes are interleaved with tests so the
/// timeline reads the way the tank actually happened.
struct TestHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var tank: Tank

    @State private var editingReading: TestReading?
    @State private var editingWaterChange: WaterChangeEvent?

    /// Unified, newest-first timeline of both event kinds.
    private enum Entry: Identifiable {
        case reading(TestReading)
        case waterChange(WaterChangeEvent)

        var id: String {
            switch self {
            case .reading(let r):     return "r-\(r.id.uuidString)"
            case .waterChange(let w): return "w-\(w.id.uuidString)"
            }
        }

        var timestamp: Date {
            switch self {
            case .reading(let r):     return r.timestamp
            case .waterChange(let w): return w.timestamp
            }
        }
    }

    private var entries: [Entry] {
        let readings = tank.readings.map(Entry.reading)
        let changes = tank.waterChanges.map(Entry.waterChange)
        return (readings + changes).sorted { $0.timestamp > $1.timestamp }
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock",
                    description: Text("Logged tests and water changes will appear here.")
                )
            } else {
                List {
                    ForEach(entries) { entry in
                        switch entry {
                        case .reading(let reading):
                            Button { editingReading = reading } label: {
                                TestReadingRow(tank: tank, reading: reading)
                            }
                            .buttonStyle(.plain)
                        case .waterChange(let event):
                            Button { editingWaterChange = event } label: {
                                WaterChangeRow(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingReading) { reading in
            LogTestView(tank: tank, existing: reading)
        }
        .sheet(item: $editingWaterChange) { event in
            LogWaterChangeView(tank: tank, existing: event)
        }
    }

    private func delete(at offsets: IndexSet) {
        let snapshot = entries
        for index in offsets {
            switch snapshot[index] {
            case .reading(let r):     modelContext.delete(r)
            case .waterChange(let w): modelContext.delete(w)
            }
        }
    }
}

/// One test row: timestamp, a compact parameter summary, and a status dot from
/// the same assessment logic the home screen uses.
private struct TestReadingRow: View {
    let tank: Tank
    let reading: TestReading

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(reading.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.medium))
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = reading.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var dotColor: Color {
        let worst = WaterParameter.displayOrder
            .compactMap { param -> RiskLevel? in
                singleRisk(param)
            }
            .max()
        return (worst ?? .safe).color
    }

    /// Lightweight per-reading risk for the row dot (ammonia/nitrite specials +
    /// simple range for the rest). Trend/stability need history, so the dot is a
    /// snapshot; the full assessment lives on the detail screen.
    private func singleRisk(_ parameter: WaterParameter) -> RiskLevel? {
        guard let value = parameter.value(in: reading) else { return nil }
        switch parameter {
        case .ammonia:
            return AmmoniaToxicity.riskLevel(unIonizedAmmonia: value, thresholds: tank.targets.ammoniaThresholds)
        case .nitrite:
            return value > 0 ? .critical : .safe
        default:
            guard let range = parameter.range(in: tank.targets) else { return .safe }
            return range.contains(value) ? .safe : .caution
        }
    }

    private var summary: String {
        var parts: [String] = []
        if let a = reading.unIonizedAmmonia { parts.append("NH₃ \(WaterParameter.ammonia.formatted(a, includeUnit: false))") }
        else if let tan = reading.ammoniaTAN { parts.append("TAN \(tan.formatted())") }
        if let n = reading.nitrite { parts.append("NO₂ \(n.formatted())") }
        if let n = reading.nitrate { parts.append("NO₃ \(n.formatted())") }
        if let p = reading.ph { parts.append("pH \(p.formatted())") }
        if let t = reading.temperatureC { parts.append("\(t.formatted())°C") }
        return parts.isEmpty ? "No values" : parts.joined(separator: " · ")
    }
}

private struct WaterChangeRow: View {
    let event: WaterChangeEvent

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "drop.triangle.fill")
                .foregroundStyle(.blue)
                .font(.footnote)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.medium))
                Text(changeSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let note = event.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var changeSummary: String {
        if let pct = event.percentChanged {
            return "Water change · \(pct.formatted())%"
        }
        return "Water change"
    }
}

#Preview {
    let container = try! TropiFishSchema.makeContainer(inMemory: true)
    let tank = Tank(name: "Demo", volumeLiters: 120)
    container.mainContext.insert(tank)
    tank.readings.append(TestReading(nitrate: 20, ph: 7.0, temperatureC: 25, tank: tank))
    return NavigationStack { TestHistoryView(tank: tank) }
        .modelContainer(container)
}
