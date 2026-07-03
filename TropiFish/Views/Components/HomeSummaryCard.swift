import SwiftUI

/// A collective at-a-glance summary across every tank, shown at the top of the
/// home screen so the dashboard feels alive before you drill into a single tank.
/// Rolls up fish, species, water volume and tank count, with a health headline
/// driven by the same assessment engine as the per-tank traffic light.
struct HomeSummaryCard: View {
    let tanks: [Tank]

    // MARK: Collective stats

    private var fishCount: Int {
        tanks.reduce(0) { $0 + $1.stock.reduce(0) { $0 + $1.quantity } }
    }
    private var speciesCount: Int {
        Set(tanks.flatMap { $0.stock.map(\.speciesID) }).count
    }
    private var totalVolume: Double {
        tanks.reduce(0) { $0 + $1.volumeLiters }
    }
    /// Tanks that have data and aren't showing an all-clear light.
    private var attentionCount: Int {
        tanks.filter {
            let a = AssessmentEngine.assess(tank: $0)
            return a.hasData && a.overall != .green
        }.count
    }
    /// Tanks with a filter media item overdue for a change.
    private var filtersDueCount: Int {
        tanks.filter { ($0.filterMediaWorstStatus() ?? .ok) == .overdue }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headline
            HStack(spacing: 0) {
                StatTile(value: "\(fishCount)", label: fishCount == 1 ? "Fish" : "Fish",
                         systemImage: "fish.fill", tint: .teal)
                tileDivider
                StatTile(value: "\(speciesCount)", label: speciesCount == 1 ? "Species" : "Species",
                         systemImage: "circle.hexagongrid.fill", tint: .indigo)
                tileDivider
                StatTile(value: volumeText, label: "Litres",
                         systemImage: "drop.fill", tint: .blue)
                tileDivider
                StatTile(value: "\(tanks.count)", label: tanks.count == 1 ? "Tank" : "Tanks",
                         systemImage: "square.stack.3d.up.fill", tint: .green)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: Headline

    private var headline: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.headline)
                .foregroundStyle(statusColor)
            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var statusIcon: String {
        if attentionCount > 0 { return "exclamationmark.triangle.fill" }
        if filtersDueCount > 0 { return "wrench.and.screwdriver.fill" }
        return "checkmark.seal.fill"
    }
    private var statusColor: Color {
        if attentionCount > 0 { return TrafficLight.red.color }
        if filtersDueCount > 0 { return TrafficLight.amber.color }
        return TrafficLight.green.color
    }
    private var statusText: String {
        if attentionCount > 0 {
            return "\(attentionCount) tank\(attentionCount == 1 ? "" : "s") need attention"
        }
        if filtersDueCount > 0 {
            return "\(filtersDueCount) tank\(filtersDueCount == 1 ? " has" : "s have") filter media due"
        }
        return "Everything's looking healthy"
    }

    private var volumeText: String {
        if totalVolume >= 1000 {
            return String(format: "%.1fk", totalVolume / 1000)
        }
        return String(Int(totalVolume.rounded()))
    }

    private var tileDivider: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.18))
            .frame(width: 1, height: 34)
    }
}

/// One stat in the summary card: a tinted icon, a big number, and a label.
private struct StatTile: View {
    let value: String
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.footnote)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let container = try! TropiFishSchema.makeContainer(inMemory: true)
    let t1 = Tank(name: "Community 180", volumeLiters: 180, tankType: .community)
    let t2 = Tank(name: "Shrimp Nano", volumeLiters: 30, tankType: .shrimp)
    container.mainContext.insert(t1)
    container.mainContext.insert(t2)
    t1.stock.append(StockedSpecies(speciesID: "neon-tetra", quantity: 12, tank: t1))
    t1.stock.append(StockedSpecies(speciesID: "bronze-cory", quantity: 6, tank: t1))
    t2.stock.append(StockedSpecies(speciesID: "cherry-shrimp", quantity: 20, tank: t2))
    return HomeSummaryCard(tanks: [t1, t2])
        .padding()
        .modelContainer(container)
}
