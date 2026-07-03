import Foundation

/// How heavily stocked a tank is, relative to care guidelines
/// (species-suitability feature). Bioload is inherently approximate, so this is
/// framed as an estimate — the copy says as much — and leans on the harder
/// signals (a species that simply won't fit, or a shoaler kept in too small a
/// group) alongside the aggregate volume estimate.
enum StockingLevel: Int, Comparable {
    case understocked = 0
    case wellStocked = 1
    case heavilyStocked = 2
    case overstocked = 3

    static func < (lhs: StockingLevel, rhs: StockingLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var displayName: String {
        switch self {
        case .understocked:   return "Lightly stocked"
        case .wellStocked:    return "Well stocked"
        case .heavilyStocked: return "Heavily stocked"
        case .overstocked:    return "Overstocked"
        }
    }

    var trafficLight: TrafficLight {
        switch self {
        case .understocked, .wellStocked: return .green
        case .heavilyStocked:             return .amber
        case .overstocked:                return .red
        }
    }

    var summary: String {
        switch self {
        case .understocked:   return "Room for more — you could add compatible fish."
        case .wellStocked:    return "A healthy, balanced level of stock."
        case .heavilyStocked: return "Near capacity — keep on top of water changes and don't add much more."
        case .overstocked:    return "Over capacity for this volume — expect faster nitrate build-up and more frequent maintenance."
        }
    }
}

struct StockingReport {
    let level: StockingLevel
    /// Estimated stocking as a percentage of the tank's usable capacity.
    let percentEstimate: Int
    let findings: [SuitabilityFinding]
    /// True when the tank has no stock recorded yet.
    let isEmpty: Bool

    var overall: TrafficLight {
        // The more severe of the volume level and any hard finding (e.g. a
        // won't-fit species) drives the badge.
        let findingLight = (findings.map(\.risk).max() ?? .safe).trafficLight
        return findingLight.severity >= level.trafficLight.severity ? findingLight : level.trafficLight
    }

    /// Findings worth acting on (amber/red), worst first.
    var concerns: [SuitabilityFinding] {
        findings.filter { $0.risk >= .caution }.sorted { $0.risk > $1.risk }
    }
}

enum StockingAssessment {

    /// Fraction of raw volume actually available to fish (substrate, décor,
    /// hardscape displace the rest). A deliberately conservative estimate.
    static let usableFraction = 0.9

    static func assess(tank: Tank) -> StockingReport {
        let entries = tank.stock.compactMap { stocked -> (Species, Int)? in
            guard let species = stocked.species else { return nil }
            return (species, stocked.quantity)
        }

        guard !entries.isEmpty else {
            return StockingReport(level: .understocked, percentEstimate: 0, findings: [], isEmpty: true)
        }

        var findings: [SuitabilityFinding] = []

        // Hard signal: a species that simply doesn't belong in this size of tank.
        for (species, _) in entries where species.minTankSizeL > tank.volumeLiters {
            findings.append(SuitabilityFinding(category: .tankSize, risk: .danger,
                message: "\(species.commonName) needs at least \(species.minTankSizeL.clean) L — more than this \(tank.volumeLiters.clean) L tank.",
                limitingSpecies: species.commonName))
        }

        // Shoaling shortfalls: too few of a species that needs company.
        for (species, qty) in entries where species.isShoaling && qty < species.minGroupSize {
            findings.append(SuitabilityFinding(category: .social, risk: .caution,
                message: "You have \(qty) \(species.commonName) — keep at least \(species.minGroupSize) so they shoal and feel secure.",
                limitingSpecies: species.commonName))
        }

        // Aggregate bioload estimate vs usable volume.
        let requiredVolume = entries.reduce(0.0) { $0 + Double($1.1) * volumePerFish($1.0) }
        let usableVolume = max(1, tank.volumeLiters * usableFraction)
        let percent = Int((requiredVolume / usableVolume * 100).rounded())
        let level = level(forPercent: percent)

        if level >= .heavilyStocked {
            findings.append(SuitabilityFinding(category: .bioload, risk: level == .overstocked ? .danger : .caution,
                message: "Estimated bioload is about \(percent)% of usable capacity. This is an estimate — your water tests are the real check."))
        }

        return StockingReport(level: level, percentEstimate: percent, findings: findings, isEmpty: false)
    }

    /// Estimated volume one adult of this species occupies, in litres. Uses the
    /// species' own figure when authored, otherwise a size-derived fallback
    /// (bioload broadly tracks adult body length).
    static func volumePerFish(_ species: Species) -> Double {
        if let per = species.litersPerAdditionalIndividual { return per }
        return max(1, species.adultSizeCm * 1.2)
    }

    private static func level(forPercent percent: Int) -> StockingLevel {
        switch percent {
        case ..<60:    return .understocked
        case 60..<90:  return .wellStocked
        case 90..<110: return .heavilyStocked
        default:       return .overstocked
        }
    }
}

private extension TrafficLight {
    /// Ordering helper so a report can compare a finding's light to the level's.
    var severity: Int {
        switch self {
        case .green: return 0
        case .amber: return 1
        case .red:   return 2
        }
    }
}
