import Foundation

/// A tropical fish species in the bundled reference catalog (species-suitability
/// feature). This is **read-only reference data** decoded from `species.json`,
/// deliberately *not* a SwiftData `@Model` — it ships with the app and grows via
/// app updates, while the user's own stocking choices live in `StockedSpecies`.
///
/// Ranges use the app's canonical units (matching `ParameterTargets`): °C, pH
/// (unitless), and dGH. The `notes` array is the bulleted care copy shown in the
/// species detail; `subspeciesNote` flags when a common name covers varieties
/// with materially different needs (e.g. some "gourami" are grouped, some not).
struct Species: Codable, Identifiable, Hashable {
    /// Stable slug, e.g. "neon-tetra" — the key `StockedSpecies` references.
    let id: String

    let commonName: String
    /// Other names shops use, for search (e.g. ["Cardinal"] or ["Red Cherry"]).
    var alsoKnownAs: [String] = []
    let scientificName: String

    /// Asset-catalog image name. Falls back to a placeholder if the image set
    /// isn't bundled yet (dataset grows ahead of imagery).
    var imageAsset: String?
    var imageCredit: ImageCredit?

    let careLevel: CareLevel
    /// Typical adult length, cm.
    let adultSizeCm: Double
    /// Recommended minimum tank volume for this species, litres.
    let minTankSizeL: Double

    let tempMinC: Double
    let tempMaxC: Double
    let phMin: Double
    let phMax: Double
    let ghMin: Double
    let ghMax: Double

    let temperament: Temperament
    /// Minimum group size for shoaling/schooling species; 0 = not a shoaler.
    var minGroupSize: Int = 0
    let swimZone: SwimZone
    let diet: Diet

    /// True for known fin-nippers (relevant against long-finned tankmates).
    var finNipper: Bool = false

    /// Optional recommended added volume per extra individual beyond the first
    /// (litres), used by the stocking estimate. When absent, a size-derived
    /// fallback is used.
    var litersPerAdditionalIndividual: Double?

    /// Bulleted care points shown in the detail view.
    var notes: [String] = []

    /// Set when this entry represents varieties that differ enough to call out.
    var subspeciesNote: String?

    private enum CodingKeys: String, CodingKey {
        case id, commonName, alsoKnownAs, scientificName, imageAsset, imageCredit
        case careLevel, adultSizeCm, minTankSizeL, tempMinC, tempMaxC
        case phMin, phMax, ghMin, ghMax, temperament, minGroupSize, swimZone, diet
        case finNipper, litersPerAdditionalIndividual, notes, subspeciesNote
    }

    /// Custom decoder so the dataset JSON can omit fields that have sensible
    /// defaults (aliases, group size, fin-nipping, notes). Swift's synthesized
    /// `Decodable` ignores property defaults and would demand every key — this
    /// keeps the ~150-entry `species.json` lean and forgiving.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        commonName = try c.decode(String.self, forKey: .commonName)
        alsoKnownAs = try c.decodeIfPresent([String].self, forKey: .alsoKnownAs) ?? []
        scientificName = try c.decode(String.self, forKey: .scientificName)
        imageAsset = try c.decodeIfPresent(String.self, forKey: .imageAsset)
        imageCredit = try c.decodeIfPresent(ImageCredit.self, forKey: .imageCredit)
        careLevel = try c.decode(CareLevel.self, forKey: .careLevel)
        adultSizeCm = try c.decode(Double.self, forKey: .adultSizeCm)
        minTankSizeL = try c.decode(Double.self, forKey: .minTankSizeL)
        tempMinC = try c.decode(Double.self, forKey: .tempMinC)
        tempMaxC = try c.decode(Double.self, forKey: .tempMaxC)
        phMin = try c.decode(Double.self, forKey: .phMin)
        phMax = try c.decode(Double.self, forKey: .phMax)
        ghMin = try c.decode(Double.self, forKey: .ghMin)
        ghMax = try c.decode(Double.self, forKey: .ghMax)
        temperament = try c.decode(Temperament.self, forKey: .temperament)
        minGroupSize = try c.decodeIfPresent(Int.self, forKey: .minGroupSize) ?? 0
        swimZone = try c.decode(SwimZone.self, forKey: .swimZone)
        diet = try c.decode(Diet.self, forKey: .diet)
        finNipper = try c.decodeIfPresent(Bool.self, forKey: .finNipper) ?? false
        litersPerAdditionalIndividual = try c.decodeIfPresent(Double.self, forKey: .litersPerAdditionalIndividual)
        notes = try c.decodeIfPresent([String].self, forKey: .notes) ?? []
        subspeciesNote = try c.decodeIfPresent(String.self, forKey: .subspeciesNote)
    }
}

extension Species {
    /// Convenience for range checks / display.
    var tempRange: ClosedRange<Double> { tempMinC...tempMaxC }
    var phRange: ClosedRange<Double> { phMin...phMax }
    var ghRange: ClosedRange<Double> { ghMin...ghMax }

    /// Whether this species needs to be kept in a group.
    var isShoaling: Bool { minGroupSize > 1 }
}

/// How demanding a species is to keep.
enum CareLevel: String, Codable, CaseIterable {
    case beginner, intermediate, advanced

    var displayName: String {
        switch self {
        case .beginner:     return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced:     return "Advanced"
        }
    }
}

/// Broad temperament bands used by the compatibility engine.
enum Temperament: String, Codable, CaseIterable {
    case peaceful
    case semiAggressive
    case aggressive
    /// Eats fish/shrimp small enough to fit in its mouth.
    case predatory

    var displayName: String {
        switch self {
        case .peaceful:       return "Peaceful"
        case .semiAggressive: return "Semi-aggressive"
        case .aggressive:     return "Aggressive"
        case .predatory:      return "Predatory"
        }
    }
}

/// Where in the water column a fish spends most of its time (stocking balance).
enum SwimZone: String, Codable, CaseIterable {
    case top, middle, bottom, all

    var displayName: String {
        switch self {
        case .top:    return "Top"
        case .middle: return "Middle"
        case .bottom: return "Bottom"
        case .all:    return "All levels"
        }
    }
}

enum Diet: String, Codable, CaseIterable {
    case herbivore, omnivore, carnivore

    var displayName: String {
        switch self {
        case .herbivore: return "Herbivore"
        case .omnivore:  return "Omnivore"
        case .carnivore: return "Carnivore"
        }
    }
}

/// Attribution for a bundled image, surfaced in the in-app credits screen so the
/// app complies with Creative-Commons / Wikimedia attribution requirements.
struct ImageCredit: Codable, Hashable {
    let author: String
    let license: String       // e.g. "CC BY-SA 4.0", "Public domain"
    let sourceURL: String
}
