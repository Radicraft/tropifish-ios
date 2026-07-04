import SwiftUI

/// Attribution for the bundled fish and plant photos (species-suitability and
/// plant-tracking features). Creative-Commons and Wikimedia images require
/// visible credit + licence, so this screen lists every bundled image with its
/// author, licence, and a link to the source. Reachable from the Fish Guide and
/// Plant Guide toolbars.
struct ImageCreditsView: View {
    private var fishCredits: [(name: String, credit: ImageCredit)] {
        SpeciesCatalog.shared.all.compactMap { s in
            s.imageCredit.map { (s.commonName, $0) }
        }
    }

    private var plantCredits: [(name: String, credit: ImageCredit)] {
        PlantCatalog.shared.all.compactMap { p in
            p.imageCredit.map { (p.commonName, $0) }
        }
    }

    var body: some View {
        List {
            Section {
                Text("The fish and plant photos below are used under the licences shown. Thanks to the photographers who share their work on Wikimedia Commons.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            creditSection("Fish", credits: fishCredits)
            creditSection("Plants", credits: plantCredits)
        }
        .navigationTitle("Photo Credits")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func creditSection(_ title: String, credits: [(name: String, credit: ImageCredit)]) -> some View {
        if !credits.isEmpty {
            Section(title) {
                ForEach(credits, id: \.name) { entry in
                    CreditRow(name: entry.name, credit: entry.credit)
                }
            }
        }
    }
}

/// One attribution row: subject, author, licence, tappable through to the source
/// (title·author·source·licence — full TASL where a source URL is present).
private struct CreditRow: View {
    let name: String
    let credit: ImageCredit

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name)
                .font(.subheadline.weight(.medium))
            Text(credit.author)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let url = URL(string: credit.sourceURL), !credit.sourceURL.isEmpty {
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text(credit.license)
                        Image(systemName: "arrow.up.right.square")
                    }
                    .font(.caption2)
                }
            } else {
                Text(credit.license)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
