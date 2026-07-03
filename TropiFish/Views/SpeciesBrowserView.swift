import SwiftUI

/// The browsable "Fish Guide" (species-suitability feature). Doubles as a picker
/// when adding a species to a tank's stock: pass `onSelect` to switch into
/// picker mode (tapping a row returns the species and dismisses) — otherwise
/// rows push the full species detail.
struct SpeciesBrowserView: View {
    /// Non-nil puts the browser in picker mode.
    var onSelect: ((Species) -> Void)?
    /// When picking for a specific tank, we can show a compatibility hint per row.
    var compatibilityTank: Tank?

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Species] { SpeciesCatalog.shared.search(query) }

    var body: some View {
        List {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                ForEach(results) { species in
                    row(for: species)
                }
            }
        }
        .listStyle(.plain)
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
    private func row(for species: Species) -> some View {
        if let onSelect {
            Button {
                onSelect(species)
                dismiss()
            } label: {
                SpeciesRow(species: species, compatibilityTank: compatibilityTank)
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                SpeciesDetailView(species: species)
            } label: {
                SpeciesRow(species: species, compatibilityTank: nil)
            }
        }
    }
}

/// One browser row: thumbnail, names, and a small care/temperament tag (or a
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
