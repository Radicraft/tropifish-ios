import Foundation

/// Tank-type presets (brief §4.1, §5). Each preset seeds a tank's default
/// `ParameterTargets`. v1 uses these coarse presets; per-species precision is a
/// Phase 2 feature (§5), so the presets deliberately encode "good enough for the
/// bulk of what this kind of tank stocks" rather than exact per-species ranges.
enum TankType: String, Codable, CaseIterable, Identifiable {
    case community
    case planted
    case shrimp
    case cichlid   // hard-water African cichlids
    case discus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .community: return "Community"
        case .planted:   return "Planted"
        case .shrimp:    return "Shrimp"
        case .cichlid:   return "African Cichlid"
        case .discus:    return "Discus"
        }
    }

    /// Sensible default safe ranges for this tank type (brief §3: "Ship with
    /// sensible defaults but let the user override per tank"). All values are in
    /// the app's canonical units — see `ParameterTargets`.
    var defaultTargets: ParameterTargets {
        switch self {
        case .community:
            return ParameterTargets(
                nitrateMax: 40,
                khMin: 3, khMax: 8,
                ghMin: 4, ghMax: 12,
                phMin: 6.5, phMax: 7.5,
                temperatureMin: 24, temperatureMax: 28,
                ammoniaSensitivity: .standard,
                phStabilityDelta: 0.4,
                temperatureStabilityDelta: 2.0
            )
        case .planted:
            return ParameterTargets(
                nitrateMax: 30,
                khMin: 3, khMax: 8,
                ghMin: 4, ghMax: 12,
                phMin: 6.5, phMax: 7.5,
                temperatureMin: 23, temperatureMax: 27,
                ammoniaSensitivity: .standard,
                // Planted/CO2 tanks intentionally swing pH day/night; a slightly
                // wider stability tolerance avoids false alarms (§6.7).
                phStabilityDelta: 0.5,
                temperatureStabilityDelta: 2.0
            )
        case .shrimp:
            return ParameterTargets(
                nitrateMax: 20,
                khMin: 2, khMax: 6,
                ghMin: 4, ghMax: 8,
                phMin: 6.5, phMax: 7.5,
                temperatureMin: 22, temperatureMax: 26,
                // Soft-water inverts are far more ammonia-sensitive (§6.2).
                ammoniaSensitivity: .sensitive,
                phStabilityDelta: 0.3,
                temperatureStabilityDelta: 1.5
            )
        case .cichlid:
            return ParameterTargets(
                nitrateMax: 40,
                khMin: 10, khMax: 18,
                ghMin: 12, ghMax: 20,
                phMin: 7.8, phMax: 8.6,
                temperatureMin: 24, temperatureMax: 28,
                ammoniaSensitivity: .standard,
                phStabilityDelta: 0.4,
                temperatureStabilityDelta: 2.0
            )
        case .discus:
            return ParameterTargets(
                nitrateMax: 20,
                khMin: 1, khMax: 4,
                ghMin: 1, ghMax: 8,
                phMin: 6.0, phMax: 7.0,
                temperatureMin: 28, temperatureMax: 30,
                ammoniaSensitivity: .sensitive,
                phStabilityDelta: 0.3,
                temperatureStabilityDelta: 1.5
            )
        }
    }
}
