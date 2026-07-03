import SwiftUI
import SwiftData

/// Full care sheet for a species (species-suitability feature): a photo, the
/// key parameters as easy-to-scan bullets, and — the point of the feature — a
/// one-tap compatibility check against any of the user's tanks, so a keeper in a
/// shop can see whether a fish suits what they already have.
struct SpeciesDetailView: View {
    let species: Species

    @Query(sort: \Tank.createdAt, order: .reverse) private var tanks: [Tank]
    @State private var selectedTankID: UUID?

    private var selectedTank: Tank? {
        tanks.first { $0.id == selectedTankID }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let note = species.subspeciesNote {
                        calloutBox(note)
                    }
                    careGrid
                    if !species.notes.isEmpty {
                        careNotes
                    }
                    compatibilitySection
                        .id("compatibility")
                }
                .padding()
            }
            .navigationTitle(species.commonName)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedTankID == nil { selectedTankID = tanks.first?.id }
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-scrollToCompatibility") {
                    proxy.scrollTo("compatibility", anchor: .bottom)
                }
                #endif
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            SpeciesImage(species: species, cornerRadius: 16)
                .frame(maxWidth: .infinity)
                .frame(height: 220)
            if let credit = species.imageCredit {
                Text("Photo: \(credit.author) · \(credit.license)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(species.commonName)
                .font(.title2.bold())
            Text(species.scientificName)
                .font(.subheadline)
                .italic()
                .foregroundStyle(.secondary)
            if !species.alsoKnownAs.isEmpty {
                Text("Also known as: \(species.alsoKnownAs.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Care at a glance

    private var careGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Care Requirements")
                .font(.headline)
            VStack(spacing: 0) {
                CareRow(icon: "thermometer.medium", label: "Temperature",
                        value: "\(species.tempMinC.clean)–\(species.tempMaxC.clean) °C")
                CareRow(icon: "drop.fill", label: "pH",
                        value: "\(species.phMin.clean)–\(species.phMax.clean)")
                CareRow(icon: "square.grid.2x2.fill", label: "Hardness (GH)",
                        value: "\(species.ghMin.clean)–\(species.ghMax.clean) dGH")
                CareRow(icon: "ruler.fill", label: "Adult size",
                        value: "\(species.adultSizeCm.clean) cm")
                CareRow(icon: "square.resize", label: "Minimum tank",
                        value: "\(species.minTankSizeL.clean) L")
                CareRow(icon: "person.3.fill", label: "Group size",
                        value: species.isShoaling ? "\(species.minGroupSize)+ (shoaling)" : "Fine alone / pair")
                CareRow(icon: "face.smiling", label: "Temperament",
                        value: species.temperament.displayName)
                CareRow(icon: "fork.knife", label: "Diet",
                        value: species.diet.displayName)
                CareRow(icon: "arrow.up.arrow.down", label: "Swim level",
                        value: species.swimZone.displayName)
                CareRow(icon: "graduationcap.fill", label: "Care level",
                        value: species.careLevel.displayName, isLast: true)
            }
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var careNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Good to Know")
                .font(.headline)
            ForEach(species.notes, id: \.self) { note in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                    Text(note)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func calloutBox(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(TrafficLight.amber.color)
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrafficLight.amber.color.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Compatibility

    @ViewBuilder
    private var compatibilitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Check Against Your Tank")
                .font(.headline)

            if tanks.isEmpty {
                Text("Add a tank to check whether this fish suits your water and current stock.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Tank", selection: $selectedTankID) {
                    ForEach(tanks) { tank in
                        Text(tank.name).tag(Optional(tank.id))
                    }
                }
                .pickerStyle(.menu)

                if let tank = selectedTank {
                    CompatibilityReportView(
                        report: CompatibilityEngine.assess(candidate: species, against: tank),
                        tank: tank
                    )
                }
            }
        }
    }
}

/// One labelled care row inside the "Care Requirements" card.
private struct CareRow: View {
    let icon: String
    let label: String
    let value: String
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            if !isLast { Divider().padding(.leading, 14) }
        }
    }
}

/// Renders a compatibility verdict: a traffic-light headline plus the concerns.
struct CompatibilityReportView: View {
    let report: CompatibilityReport
    let tank: Tank

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: report.overall.systemImage)
                    .foregroundStyle(report.overall.color)
                Text(headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(report.overall.color)
            }

            if report.concerns.isEmpty {
                Text(CompatibilityEngine.resolvedStock(of: tank).isEmpty
                     ? "Suits this tank's water targets. No other fish stocked yet to check against."
                     : "Gets on with your current stock and water targets.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(report.concerns) { finding in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: finding.risk.trafficLight.systemImage)
                            .font(.caption)
                            .foregroundStyle(finding.risk.color)
                            .padding(.top, 1)
                        Text(finding.message)
                            .font(.footnote)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(report.overall.color.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var headline: String {
        switch report.overall {
        case .green: return "Good match for \(tank.name)"
        case .amber: return "Check before adding to \(tank.name)"
        case .red:   return "Not recommended for \(tank.name)"
        }
    }
}

#Preview {
    let container = try! TropiFishSchema.makeContainer(inMemory: true)
    container.mainContext.insert(Tank(name: "Community 180", volumeLiters: 180, tankType: .community))
    return NavigationStack {
        SpeciesDetailView(species: SpeciesCatalog.shared.byID("angelfish")!)
    }
    .modelContainer(container)
}
