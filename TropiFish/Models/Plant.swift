import Foundation

/// An aquarium plant in the bundled reference catalog (plant-tracking feature).
/// Like `Species`, this is **read-only reference data** decoded from
/// `plants.json` — it ships with the app and grows via updates, while the user's
/// own planting choices live in `StockedPlant`.
///
/// Ranges use the app's canonical units (°C, pH, dGH) so a plant's water
/// preferences can be sanity-checked against a tank's targets the same way fish
/// are. `notes` is the bulleted care copy shown in the plant detail.
struct Plant: Codable, Identifiable, Hashable {
    /// Stable slug, e.g. "java-fern" — the key `StockedPlant` references.
    let id: String

    let commonName: String
    var alsoKnownAs: [String] = []
    let scientificName: String

    var imageAsset: String?
    var imageCredit: ImageCredit?

    let difficulty: PlantDifficulty
    let lightNeed: LightNeed
    let co2Need: CO2Need
    let placement: PlantPlacement
    let growthRate: GrowthRate

    let tempMinC: Double
    let tempMaxC: Double
    let phMin: Double
    let phMax: Double
    let ghMin: Double
    let ghMax: Double

    /// Typical maximum height (or spread, for carpeting/floating plants), cm.
    let maxHeightCm: Double

    /// How the plant is propagated, e.g. "Rhizome division", "Cuttings".
    var propagation: String?

    var notes: [String] = []

    private enum CodingKeys: String, CodingKey {
        case id, commonName, alsoKnownAs, scientificName, imageAsset, imageCredit
        case difficulty, lightNeed, co2Need, placement, growthRate
        case tempMinC, tempMaxC, phMin, phMax, ghMin, ghMax
        case maxHeightCm, propagation, notes
    }

    /// Custom decoder so the dataset JSON can omit fields with sensible defaults
    /// (aliases, imagery, propagation, notes) — mirrors `Species`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        commonName = try c.decode(String.self, forKey: .commonName)
        alsoKnownAs = try c.decodeIfPresent([String].self, forKey: .alsoKnownAs) ?? []
        scientificName = try c.decode(String.self, forKey: .scientificName)
        imageAsset = try c.decodeIfPresent(String.self, forKey: .imageAsset)
        imageCredit = try c.decodeIfPresent(ImageCredit.self, forKey: .imageCredit)
        difficulty = try c.decode(PlantDifficulty.self, forKey: .difficulty)
        lightNeed = try c.decode(LightNeed.self, forKey: .lightNeed)
        co2Need = try c.decode(CO2Need.self, forKey: .co2Need)
        placement = try c.decode(PlantPlacement.self, forKey: .placement)
        growthRate = try c.decode(GrowthRate.self, forKey: .growthRate)
        tempMinC = try c.decode(Double.self, forKey: .tempMinC)
        tempMaxC = try c.decode(Double.self, forKey: .tempMaxC)
        phMin = try c.decode(Double.self, forKey: .phMin)
        phMax = try c.decode(Double.self, forKey: .phMax)
        ghMin = try c.decode(Double.self, forKey: .ghMin)
        ghMax = try c.decode(Double.self, forKey: .ghMax)
        maxHeightCm = try c.decode(Double.self, forKey: .maxHeightCm)
        propagation = try c.decodeIfPresent(String.self, forKey: .propagation)
        notes = try c.decodeIfPresent([String].self, forKey: .notes) ?? []
    }
}

extension Plant {
    var tempRange: ClosedRange<Double> { tempMinC...tempMaxC }
    var phRange: ClosedRange<Double> { phMin...phMax }
    var ghRange: ClosedRange<Double> { ghMin...ghMax }
}

/// How demanding a plant is to keep — parallels `CareLevel` for fish.
enum PlantDifficulty: String, Codable, CaseIterable {
    case easy, medium, advanced

    var displayName: String {
        switch self {
        case .easy:     return "Easy"
        case .medium:   return "Medium"
        case .advanced: return "Advanced"
        }
    }
}

enum LightNeed: String, Codable, CaseIterable {
    case low, medium, high

    var displayName: String {
        switch self {
        case .low:    return "Low light"
        case .medium: return "Medium light"
        case .high:   return "High light"
        }
    }
}

enum CO2Need: String, Codable, CaseIterable {
    case none, beneficial, required

    var displayName: String {
        switch self {
        case .none:       return "No CO₂ needed"
        case .beneficial: return "CO₂ beneficial"
        case .required:   return "CO₂ required"
        }
    }
}

/// Where in the tank a plant is typically placed / grows.
enum PlantPlacement: String, Codable, CaseIterable {
    case foreground, midground, background, floating, epiphyte

    var displayName: String {
        switch self {
        case .foreground: return "Foreground"
        case .midground:  return "Midground"
        case .background: return "Background"
        case .floating:   return "Floating"
        case .epiphyte:   return "Epiphyte (on wood/rock)"
        }
    }
}

enum GrowthRate: String, Codable, CaseIterable {
    case slow, moderate, fast

    var displayName: String {
        switch self {
        case .slow:     return "Slow"
        case .moderate: return "Moderate"
        case .fast:     return "Fast"
        }
    }
}
