import Foundation

/// One line of a suitability verdict — reused by both the compatibility check
/// and the stocking assessment. Carries a `RiskLevel` (so the UI can colour it
/// with the existing traffic-light palette) plus plain-English copy.
struct SuitabilityFinding: Identifiable {
    enum Category: String {
        case temperature, ph, gh, temperament, tankSize, social, bioload, water
    }

    let id = UUID()
    let category: Category
    let risk: RiskLevel
    let message: String
    /// The stocked species most responsible, when there is a single culprit.
    var limitingSpecies: String?
}

/// Verdict for adding a candidate species to a tank.
struct CompatibilityReport {
    let candidate: Species
    let findings: [SuitabilityFinding]

    /// Worst risk drives the headline traffic light; no findings → all clear.
    var overall: TrafficLight {
        (findings.map(\.risk).max() ?? .safe).trafficLight
    }

    /// Only the findings worth acting on (amber/red), worst first.
    var concerns: [SuitabilityFinding] {
        findings.filter { $0.risk >= .caution }.sorted { $0.risk > $1.risk }
    }

    var isEmptyTankFit: Bool { findings.allSatisfy { $0.risk == .safe } }
}

/// Checks whether a candidate species suits a tank, given the tank's current
/// stock and configured water targets (species-suitability feature).
///
/// The crucial rule (aquarium brief §5): for water parameters, compute the
/// **intersection** of every fish's acceptable range — the workable overlap —
/// **not the average**. If two residents want non-overlapping pH, there is no
/// happy middle, and the app must say which fish is the limiting factor rather
/// than papering over it with a mean.
enum CompatibilityEngine {

    /// The three ranged water parameters we can reason about per species.
    private enum Param: String {
        case temperature, ph, gh

        var category: SuitabilityFinding.Category {
            switch self {
            case .temperature: return .temperature
            case .ph:          return .ph
            case .gh:          return .gh
            }
        }

        var label: String {
            switch self {
            case .temperature: return "temperature"
            case .ph:          return "pH"
            case .gh:          return "GH"
            }
        }

        func range(_ s: Species) -> ClosedRange<Double> {
            switch self {
            case .temperature: return s.tempRange
            case .ph:          return s.phRange
            case .gh:          return s.ghRange
            }
        }

        /// Below this overlap width, the shared band is uncomfortably narrow.
        var narrowWidth: Double {
            switch self {
            case .temperature: return 1.5
            case .ph:          return 0.4
            case .gh:          return 3
            }
        }

        func format(_ value: Double) -> String {
            switch self {
            case .temperature: return "\(value.clean)°C"
            case .ph:          return value.clean
            case .gh:          return "\(value.clean) dGH"
            }
        }
    }

    static func assess(candidate: Species, against tank: Tank) -> CompatibilityReport {
        // Distinct stocked species (a species stocked once is enough to constrain).
        let stocked = resolvedStock(of: tank).filter { $0.id != candidate.id }

        var findings: [SuitabilityFinding] = []
        findings.append(contentsOf: parameterFindings(candidate: candidate, stocked: stocked, tank: tank))
        findings.append(contentsOf: temperamentFindings(candidate: candidate, stocked: stocked))
        findings.append(contentsOf: tankSizeFindings(candidate: candidate, tank: tank))
        findings.append(contentsOf: socialFindings(candidate: candidate))

        return CompatibilityReport(candidate: candidate, findings: findings)
    }

    /// Unique species currently stocked in the tank.
    static func resolvedStock(of tank: Tank) -> [Species] {
        var seen = Set<String>()
        return tank.stock.compactMap(\.species).filter { seen.insert($0.id).inserted }
    }

    // MARK: - Water parameters (intersection, not average)

    private static func parameterFindings(candidate: Species, stocked: [Species], tank: Tank) -> [SuitabilityFinding] {
        var findings: [SuitabilityFinding] = []

        for param in [Param.temperature, .ph, .gh] {
            // Everyone who has to share this water: candidate + existing residents.
            let participants = [candidate] + stocked

            // Intersection = highest floor, lowest ceiling — and who sets each.
            let floor = participants.map { (s: $0, v: param.range($0).lowerBound) }.max { $0.v < $1.v }!
            let ceil  = participants.map { (s: $0, v: param.range($0).upperBound) }.min { $0.v < $1.v }!

            if floor.v > ceil.v {
                // No overlap at all — name the two fish pulling in opposite directions.
                let a = floor.s, b = ceil.s
                let msg = "\(a.commonName) needs \(param.label) ≥ \(param.format(floor.v)) but "
                    + "\(b.commonName) needs ≤ \(param.format(ceil.v)) — the ranges don't overlap."
                let culprit = (a.id == candidate.id) ? b : a
                findings.append(SuitabilityFinding(category: param.category, risk: .danger,
                                                   message: msg, limitingSpecies: culprit.commonName))
            } else if (ceil.v - floor.v) < param.narrowWidth && !stocked.isEmpty {
                // Overlap exists but it's a tight band to hold — flag as caution.
                let msg = "Workable \(param.label) is only \(param.format(floor.v))–\(param.format(ceil.v)); "
                    + "keep it stable to suit both this fish and \(narrowestOther(param: param, candidate: candidate, stocked: stocked)?.commonName ?? "your stock")."
                findings.append(SuitabilityFinding(category: param.category, risk: .caution, message: msg,
                                                   limitingSpecies: floor.s.id == candidate.id ? ceil.s.commonName : floor.s.commonName))
            }

            // Does the candidate suit the tank's *configured* water target, too?
            if let waterFinding = tankWaterFinding(param: param, candidate: candidate, tank: tank) {
                findings.append(waterFinding)
            }
        }
        return findings
    }

    /// Which resident most tightly bounds this parameter (for narrow-band copy).
    private static func narrowestOther(param: Param, candidate: Species, stocked: [Species]) -> Species? {
        stocked.min { (param.range($0).upperBound - param.range($0).lowerBound) < (param.range($1).upperBound - param.range($1).lowerBound) }
    }

    /// Compare the candidate's preferred range to the tank's configured target
    /// band (from `ParameterTargets`) — the "will this fish suit my water" angle,
    /// which matters even for an empty tank.
    private static func tankWaterFinding(param: Param, candidate: Species, tank: Tank) -> SuitabilityFinding? {
        let target: ClosedRange<Double>
        switch param {
        case .temperature: target = tank.targets.temperatureMin...tank.targets.temperatureMax
        case .ph:          target = tank.targets.phMin...tank.targets.phMax
        case .gh:          target = tank.targets.ghMin...tank.targets.ghMax
        }
        let species = param.range(candidate)
        // Overlap of species preference and the tank's target band.
        let lo = max(species.lowerBound, target.lowerBound)
        let hi = min(species.upperBound, target.upperBound)
        guard lo > hi else { return nil }   // they overlap → fine
        let msg = "This tank targets \(param.label) \(param.format(target.lowerBound))–\(param.format(target.upperBound)), "
            + "but \(candidate.commonName) prefers \(param.format(species.lowerBound))–\(param.format(species.upperBound))."
        return SuitabilityFinding(category: .water, risk: .caution, message: msg)
    }

    // MARK: - Temperament

    private static func temperamentFindings(candidate: Species, stocked: [Species]) -> [SuitabilityFinding] {
        guard !stocked.isEmpty else { return [] }
        var findings: [SuitabilityFinding] = []

        // Predation, both directions — a fish that fits in a mouth tends to end up there.
        let predators = stocked.filter { $0.temperament == .predatory }
        if candidate.temperament == .predatory {
            if let prey = stocked.filter({ $0.adultSizeCm * 2.2 <= candidate.adultSizeCm }).first {
                findings.append(SuitabilityFinding(category: .temperament, risk: .danger,
                    message: "\(candidate.commonName) is predatory and large enough to eat \(prey.commonName).",
                    limitingSpecies: prey.commonName))
            }
        }
        if let predator = predators.first(where: { candidate.adultSizeCm * 2.2 <= $0.adultSizeCm }) {
            findings.append(SuitabilityFinding(category: .temperament, risk: .danger,
                message: "\(predator.commonName) is predatory and could eat a fish the size of \(candidate.commonName).",
                limitingSpecies: predator.commonName))
        }

        // Aggression mismatch — peaceful fish get bullied by aggressive tankmates.
        let aggressive = stocked.filter { $0.temperament == .aggressive || $0.temperament == .semiAggressive }
        if candidate.temperament == .peaceful, let bully = aggressive.first {
            findings.append(SuitabilityFinding(category: .temperament, risk: .caution,
                message: "\(candidate.commonName) is peaceful and may be harassed by \(bully.commonName).",
                limitingSpecies: bully.commonName))
        }
        if (candidate.temperament == .aggressive || candidate.temperament == .semiAggressive),
           let meek = stocked.first(where: { $0.temperament == .peaceful }) {
            findings.append(SuitabilityFinding(category: .temperament, risk: .caution,
                message: "\(candidate.commonName) can be \(candidate.temperament.displayName.lowercased()) toward peaceful tankmates like \(meek.commonName).",
                limitingSpecies: meek.commonName))
        }

        // Fin-nipping — a classic community-tank gotcha.
        if candidate.finNipper, !stocked.isEmpty {
            findings.append(SuitabilityFinding(category: .temperament, risk: .caution,
                message: "\(candidate.commonName) is a known fin-nipper — avoid slow, long-finned tankmates (e.g. bettas, fancy guppies, angelfish)."))
        }
        return findings
    }

    // MARK: - Tank size & social

    private static func tankSizeFindings(candidate: Species, tank: Tank) -> [SuitabilityFinding] {
        guard candidate.minTankSizeL > tank.volumeLiters else { return [] }
        let risk: RiskLevel = candidate.minTankSizeL > tank.volumeLiters * 1.25 ? .danger : .caution
        return [SuitabilityFinding(category: .tankSize, risk: risk,
            message: "\(candidate.commonName) needs at least \(candidate.minTankSizeL.clean) L; this tank is \(tank.volumeLiters.clean) L.")]
    }

    private static func socialFindings(candidate: Species) -> [SuitabilityFinding] {
        guard candidate.isShoaling else { return [] }
        return [SuitabilityFinding(category: .social, risk: .safe,
            message: "Keep \(candidate.commonName) in a group of \(candidate.minGroupSize) or more — they're a shoaling species.")]
    }
}

extension Double {
    /// Trim a trailing ".0" so "24.0" reads as "24" but "7.5" stays "7.5".
    var clean: String {
        self == rounded() ? String(Int(self)) : String(format: "%g", self)
    }
}
