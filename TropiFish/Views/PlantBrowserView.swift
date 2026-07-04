import SwiftUI

/// The browsable "Plant Guide" (plant-tracking feature). Doubles as a picker when
/// adding a plant to a tank: pass `onSelect` to switch into picker mode (tapping
/// a card returns the plant and dismisses) — otherwise cards push the full
/// detail. Adaptive grid, mirroring `SpeciesBrowserView`.
struct PlantBrowserView: View {
    var onSelect: ((Plant) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Plant] { PlantCatalog.shared.search(query) }
    private let columns = [GridItem(.adaptive(minimum: 330), spacing: 14)]

    var body: some View {
        ScrollView {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(results) { plant in
                        card(for: plant)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $query, prompt: "Search by name or species")
        .navigationTitle(onSelect == nil ? "Plant Guide" : "Add Plant")
        .navigationBarTitleDisplayMode(onSelect == nil ? .large : .inline)
        .toolbar {
            if onSelect != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func card(for plant: Plant) -> some View {
        Group {
            if let onSelect {
                Button {
                    onSelect(plant)
                    dismiss()
                } label: {
                    PlantRow(plant: plant).plantCardStyle()
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    PlantDetailView(plant: plant)
                } label: {
                    PlantRow(plant: plant).plantCardStyle()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private extension View {
    func plantCardStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// One browser card: thumbnail, names, and small placement/difficulty tags.
struct PlantRow: View {
    let plant: Plant

    var body: some View {
        HStack(spacing: 14) {
            PlantImage(plant: plant, cornerRadius: 10)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(plant.commonName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(plant.scientificName)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    PlantTag(text: plant.placement.displayName)
                    PlantTag(text: plant.difficulty.displayName)
                }
                .padding(.top, 1)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 6)
    }
}

private struct PlantTag: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}

#Preview {
    NavigationStack { PlantBrowserView(onSelect: nil) }
}
