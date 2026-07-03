import SwiftUI

/// Attribution for the bundled species photos (species-suitability feature).
/// Creative-Commons and Wikimedia images require visible credit + licence, so
/// this screen lists every species image that ships with a credit. Reachable
/// from the Fish Guide toolbar.
struct ImageCreditsView: View {
    private var credited: [(species: Species, credit: ImageCredit)] {
        SpeciesCatalog.shared.all.compactMap { species in
            species.imageCredit.map { (species, $0) }
        }
    }

    var body: some View {
        List {
            Section {
                Text("Species photos are used under the licences below. Thanks to the photographers who share their work.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if credited.isEmpty {
                ContentUnavailableView("No Photo Credits Yet",
                                       systemImage: "photo",
                                       description: Text("Species photos are still being added."))
            } else {
                ForEach(credited, id: \.species.id) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.species.commonName)
                            .font(.subheadline.weight(.medium))
                        Text(entry.credit.author)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(entry.credit.license)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Photo Credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}
