import Foundation

/// Ammonia risk-tier boundaries applied to the *calculated* un-ionized ammonia
/// figure (NH₃-N, ppm) — not the raw test-kit TAN reading (brief §6.2).
///
/// The brief gives published freshwater guideline values as the default, and
/// asks that they be preset-adjustable because livebearers/goldfish tolerate
/// more than soft-water species like tetras, rams, or shrimp.
struct AmmoniaThresholds: Codable, Equatable {
    /// Below `caution` → Safe. `[caution, danger)` → Caution.
    /// `[danger, critical)` → Danger. `>= critical` → Critical.
    var caution: Double
    var danger: Double
    var critical: Double

    /// Published defaults from §6.2, suitable for typical hardy community fish.
    static let standard = AmmoniaThresholds(caution: 0.02, danger: 0.05, critical: 0.2)

    /// Tighter tiers for soft-water / sensitive stock (shrimp, discus, rams).
    static let sensitive = AmmoniaThresholds(caution: 0.01, danger: 0.03, critical: 0.1)
}

/// Convenience selector so `TankType` presets don't hard-code the same numbers.
enum AmmoniaSensitivity: String, Codable, CaseIterable {
    case standard
    case sensitive

    var thresholds: AmmoniaThresholds {
        switch self {
        case .standard:  return .standard
        case .sensitive: return .sensitive
        }
    }
}

/// Per-tank configurable safe ranges and stability thresholds (brief §3, §6).
///
/// Stored as a Codable value on `Tank`. Seeded from `TankType.defaultTargets`
/// at tank creation, then freely overridable by the user.
///
/// **Canonical units** (display conversion happens at the UI layer):
/// - Nitrate: ppm (mg/L)
/// - KH: dKH
/// - GH: dGH
/// - pH: unitless
/// - Temperature: °C  (also the unit the ammonia toxicity calc requires, §6.2)
///
/// Ammonia and nitrite are deliberately *not* simple min/max ranges here:
/// ammonia is assessed via the calculated NH₃-N tiers (`ammonia`), and nitrite
/// is zero-tolerance with no configurable range (§6.3).
struct ParameterTargets: Codable, Equatable {
    // Nitrate — only an upper bound matters (§6.4).
    var nitrateMax: Double

    // KH buffering range (§6.5).
    var khMin: Double
    var khMax: Double

    // GH suitability range (§6.6).
    var ghMin: Double
    var ghMax: Double

    // pH range (§6.7).
    var phMin: Double
    var phMax: Double

    // Temperature range in °C (§6.8).
    var temperatureMin: Double
    var temperatureMax: Double

    // Ammonia NH₃-N risk tiers (§6.2).
    var ammoniaSensitivity: AmmoniaSensitivity

    // Stability thresholds (§6.7, §6.8).
    /// Max acceptable pH change between consecutive readings before a stability
    /// warning fires (~0.3–0.5 pH units).
    var phStabilityDelta: Double
    /// Max acceptable temperature change (°C) between readings ~24h apart before
    /// a stress-risk warning fires (~2 °C).
    var temperatureStabilityDelta: Double

    var ammoniaThresholds: AmmoniaThresholds { ammoniaSensitivity.thresholds }
}
