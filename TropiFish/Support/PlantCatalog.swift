import Foundation

/// Loads and serves the bundled `plants.json` reference data (plant-tracking
/// feature) — the plant-side counterpart to `SpeciesCatalog`.
final class PlantCatalog {
    static let shared = PlantCatalog()

    /// All plants, sorted by common name.
    let all: [Plant]

    private let byIDIndex: [String: Plant]

    private init() {
        let loaded = Self.load()
        all = loaded.sorted {
            $0.commonName.localizedCaseInsensitiveCompare($1.commonName) == .orderedAscending
        }
        byIDIndex = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func byID(_ id: String) -> Plant? { byIDIndex[id] }

    /// Case-insensitive search across common name, scientific name and aliases.
    func search(_ query: String) -> [Plant] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return all }
        return all.filter { plant in
            plant.commonName.localizedCaseInsensitiveContains(q)
                || plant.scientificName.localizedCaseInsensitiveContains(q)
                || plant.alsoKnownAs.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    private static func load() -> [Plant] {
        guard let url = Bundle.main.url(forResource: "plants", withExtension: "json") else {
            assertionFailure("plants.json missing from bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Plant].self, from: data)
        } catch {
            assertionFailure("plants.json failed to decode: \(error)")
            return []
        }
    }
}
