import SwiftUI

/// The browsable "Fish Guide" (species-suitability feature). Doubles as a picker
/// when adding a species to a tank's stock: pass `onSelect` to switch into
/// picker mode (tapping a card returns the species and dismisses) — otherwise
/// cards push the full species detail.
///
/// Laid out as an adaptive grid so it fills an iPad's width with several columns
/// while collapsing to a single column on iPhone (and inside the narrow "Add
/// Fish" sheet).
struct SpeciesBrowserView: View {
    /// Non-nil puts the browser in picker mode.
    var onSelect: ((Species) -> Void)?
    /// When picking for a specific tank, we can show a compatibility hint per card.
    var compatibilityTank: Tank?

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Species] { SpeciesCatalog.shared.search(query) }
    private let columns = [GridItem(.adaptive(minimum: 330), spacing: 14)]

    var body: some View {
        ScrollView {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
                    .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(results) { species in
                        card(for: species)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $query, prompt: "Search by name or species")
        .navigationTitle(onSelect == nil ? "Fish Guide" : "Add Fish")
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
    private func card(for species: Species) -> some View {
        if let onSelect {
            Button {
                onSelect(species)
                dismiss()
            } label: {
                SpeciesRow(species: species, compatibilityTank: compatibilityTank)
                    .speciesCardStyle()
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                SpeciesDetailView(species: species)
            } label: {
                SpeciesRow(species: species, compatibilityTank: nil)
                    .speciesCardStyle()
            }
            .buttonStyle(.plain)
        }
    }
}

private extension View {
    /// Card chrome for a browser cell (grid tiles need their own background;
    /// in a `List` the row provided it).
    func speciesCardStyle() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// One browser card: thumbnail, names, and a small care/temperament tag (or a
/// compatibility dot when picking for a specific tank).
struct SpeciesRow: View {
    let species: Species
    var compatibilityTank: Tank?

    var body: some View {
        HStack(spacing: 14) {
            SpeciesImage(species: species, cornerRadius: 10)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(species.commonName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(species.scientificName)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Tag(text: species.careLevel.displayName)
                    Tag(text: species.temperament.displayName)
                }
                .padding(.top, 1)
            }

            Spacer(minLength: 8)

            if let tank = compatibilityTank {
                let light = CompatibilityEngine.assess(candidate: species, against: tank).overall
                Image(systemName: light.systemImage)
                    .font(.subheadline)
                    .foregroundStyle(light.color)
            }
        }
        .padding(.vertical, 6)
    }
}

/// Small pill used for care level / temperament.
private struct Tag: View {
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
    NavigationStack { SpeciesBrowserView(onSelect: nil, compatibilityTank: nil) }
}
