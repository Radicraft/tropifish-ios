import Foundation

/// Loads and serves the bundled species reference data (species-suitability
/// feature). Decodes `species.json` once, lazily, then keeps it in memory —
/// there are only a few hundred entries so this is cheap and avoids threading a
/// dependency through every view.
///
/// Mirrors the single-source pattern of `TropiFishSchema`: one place builds the
/// catalog so views, the compatibility engine, and previews all agree.
final class SpeciesCatalog {
    static let shared = SpeciesCatalog()

    /// All species, sorted by common name for stable browsing.
    let all: [Species]

    private let byIDIndex: [String: Species]

    private init() {
        let loaded = Self.load()
        self.all = loaded.sorted { $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending }
        self.byIDIndex = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Look up a species by its slug.
    func byID(_ id: String) -> Species? { byIDIndex[id] }

    /// Case-insensitive search across common name, scientific name, and aliases.
    func search(_ query: String) -> [Species] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter { species in
            species.commonName.localizedCaseInsensitiveContains(q)
                || species.scientificName.localizedCaseInsensitiveContains(q)
                || species.alsoKnownAs.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    private static func load() -> [Species] {
        guard let url = Bundle.main.url(forResource: "species", withExtension: "json") else {
            assertionFailure("species.json missing from bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Species].self, from: data)
        } catch {
            assertionFailure("Failed to decode species.json: \(error)")
            return []
        }
    }
}
