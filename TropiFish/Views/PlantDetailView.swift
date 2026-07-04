import SwiftUI

/// Full care sheet for an aquarium plant (plant-tracking feature): a photo, the
/// key growing requirements as easy-to-scan rows, and the care notes — the
/// plant-side counterpart to `SpeciesDetailView` (without the fish compatibility
/// check, which doesn't apply to plants).
struct PlantDetailView: View {
    let plant: Plant

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                careGrid
                if !plant.notes.isEmpty {
                    careNotes
                }
            }
            .padding()
            .readableWidth()
        }
        .navigationTitle(plant.commonName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            PlantImage(plant: plant, cornerRadius: 18)
                .frame(maxWidth: .infinity)
                .frame(height: 230)
                .overlay(alignment: .bottomTrailing) {
                    if let credit = plant.imageCredit {
                        Text("\(credit.author) · \(credit.license)")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.35), in: Capsule())
                            .padding(8)
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(plant.commonName)
                    .font(.title.bold())
                Text(plant.scientificName)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                if !plant.alsoKnownAs.isEmpty {
                    Text("Also known as: \(plant.alsoKnownAs.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
        }
    }

    private var careGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Growing Requirements")
                .font(.headline)
            VStack(spacing: 0) {
                PlantCareRow(icon: "sun.max.fill", label: "Light",
                             value: plant.lightNeed.displayName)
                PlantCareRow(icon: "aqi.medium", label: "CO₂",
                             value: plant.co2Need.displayName)
                PlantCareRow(icon: "graduationcap.fill", label: "Difficulty",
                             value: plant.difficulty.displayName)
                PlantCareRow(icon: "square.3.layers.3d.top.filled", label: "Placement",
                             value: plant.placement.displayName)
                PlantCareRow(icon: "arrow.up.forward", label: "Growth rate",
                             value: plant.growthRate.displayName)
                PlantCareRow(icon: "ruler.fill", label: "Max height",
                             value: "\(plant.maxHeightCm.clean) cm")
                PlantCareRow(icon: "thermometer.medium", label: "Temperature",
                             value: "\(plant.tempMinC.clean)–\(plant.tempMaxC.clean) °C")
                PlantCareRow(icon: "drop.fill", label: "pH",
                             value: "\(plant.phMin.clean)–\(plant.phMax.clean)")
                PlantCareRow(icon: "square.grid.2x2.fill", label: "Hardness (GH)",
                             value: "\(plant.ghMin.clean)–\(plant.ghMax.clean) dGH")
                if let propagation = plant.propagation {
                    PlantCareRow(icon: "arrow.triangle.branch", label: "Propagation",
                                 value: propagation, isLast: true)
                }
            }
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var careNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Good to Know")
                .font(.headline)
            ForEach(plant.notes, id: \.self) { note in
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
}

/// One labelled row inside the plant "Growing Requirements" card.
private struct PlantCareRow: View {
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
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            if !isLast { Divider().padding(.leading, 14) }
        }
    }
}

#Preview {
    NavigationStack {
        PlantDetailView(plant: PlantCatalog.shared.byID("java-fern")!)
    }
}
