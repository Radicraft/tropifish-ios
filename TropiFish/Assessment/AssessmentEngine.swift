import Foundation

/// Turns a tank's readings into per-parameter status + guidance (brief §6).
///
/// Each parameter has its own logic rather than one shared range+trend rule,
/// because the mechanisms genuinely differ (§6): ammonia is a calculated
/// pH/temperature-driven toxicity figure, nitrite is zero-tolerance, nitrate/GH
/// are chronic indicators, and KH/pH/temperature are about stability as much as
/// absolute value.
enum AssessmentEngine {

    /// Assess a tank from its stored readings (newest-first internally).
    static func assess(tank: Tank) -> TankAssessment {
        let readings = tank.readingsByDateDescending
        guard let latest = readings.first else { return .empty }

        let targets = tank.targets
        let context = GuidanceContext(
            isCycling: tank.isCycling,
            tankTypeName: tank.tankType.displayName,
            nitrateNearTapBaseline: nitrateNearTapBaseline(latest: latest, tank: tank)
        )

        let assessments = WaterParameter.displayOrder.map { parameter in
            assess(parameter, latest: latest, readings: readings, targets: targets, context: context)
        }

        let hasData = assessments.contains { $0.hasData }
        let headline = assessments
            .filter { $0.hasData && $0.risk > .safe }
            .max { lhs, rhs in
                if lhs.risk != rhs.risk { return lhs.risk < rhs.risk }
                // Tie-break by display order (ammonia/nitrite first).
                return orderIndex(lhs.parameter) > orderIndex(rhs.parameter)
            }?
            .guidance

        return TankAssessment(parameters: assessments, headline: headline, hasData: hasData)
    }

    // MARK: - Per-parameter dispatch

    private static func assess(
        _ parameter: WaterParameter,
        latest: TestReading,
        readings: [TestReading],
        targets: ParameterTargets,
        context: GuidanceContext
    ) -> ParameterAssessment {
        let value = parameter.value(in: latest)
        let series = readings.compactMap { parameter.value(in: $0) }
        let trend = TrendDirection.detect(newestFirst: series)

        var risk: RiskLevel = .safe
        var stabilityAlert = false

        switch parameter {
        case .ammonia:
            risk = ammoniaRisk(value: value, targets: targets)

        case .nitrite:
            risk = nitriteRisk(value: value)

        case .nitrate:
            risk = nitrateRisk(value: value, trend: trend, targets: targets)

        case .gh:
            // Suitability only — never escalates past amber (§6.6).
            risk = rangeRisk(value: value, range: parameter.range(in: targets), cap: .caution)

        case .kh:
            risk = rangeRisk(value: value, range: parameter.range(in: targets), cap: .caution)
            // Low-and-falling is a leading pH-crash indicator (§6.5): flag while KH
            // is still in the lower half of its range but trending down, before it
            // actually drops below the minimum.
            if let value, trend == .falling,
               value <= (targets.khMin + targets.khMax) / 2 {
                risk = max(risk, .caution)
            }

        case .ph:
            risk = rangeRisk(value: value, range: parameter.range(in: targets), cap: .caution)
            stabilityAlert = stabilityBreached(parameter, latest: latest, readings: readings,
                                                delta: targets.phStabilityDelta)
            if stabilityAlert { risk = max(risk, .caution) }

        case .temperature:
            risk = rangeRisk(value: value, range: parameter.range(in: targets), cap: .caution)
            stabilityAlert = stabilityBreached(parameter, latest: latest, readings: readings,
                                                delta: targets.temperatureStabilityDelta,
                                                within: 24 * 60 * 60)
            if stabilityAlert { risk = max(risk, .caution) }
        }

        let guidance = GuidanceCopy.message(
            for: parameter, risk: risk, trend: trend,
            stabilityAlert: stabilityAlert, context: context
        )

        return ParameterAssessment(
            parameter: parameter, value: value, risk: risk,
            trend: trend, stabilityAlert: stabilityAlert, guidance: guidance
        )
    }

    // MARK: - Parameter-specific rules

    /// §6.2 — calculated NH₃-N against the tank's (preset-adjustable) tiers.
    private static func ammoniaRisk(value: Double?, targets: ParameterTargets) -> RiskLevel {
        guard let value else { return .safe }
        return AmmoniaToxicity.riskLevel(unIonizedAmmonia: value, thresholds: targets.ammoniaThresholds)
    }

    /// §6.3 — zero-tolerance; any non-zero nitrite is red, regardless of trend.
    private static func nitriteRisk(value: Double?) -> RiskLevel {
        guard let value else { return .safe }
        return value > 0 ? .critical : .safe
    }

    /// §6.4 — chronic indicator; trend weighted more heavily than a single value.
    private static func nitrateRisk(value: Double?, trend: TrendDirection, targets: ParameterTargets) -> RiskLevel {
        guard let value else { return .safe }
        if value > targets.nitrateMax {
            return trend == .rising ? .danger : .caution
        }
        // In range but climbing three tests running → early caution (§6.1, §6.4).
        return trend == .rising ? .caution : .safe
    }

    /// Generic range check (§6.1), capped so low-urgency parameters stay amber.
    private static func rangeRisk(value: Double?, range: ClosedRange<Double>?, cap: RiskLevel) -> RiskLevel {
        guard let value, let range else { return .safe }
        return range.contains(value) ? .safe : cap
    }

    /// §6.7 / §6.8 — flag a rate-of-change between the two most recent readings
    /// that both carry this parameter. `within` optionally restricts to readings
    /// close enough in time to matter (temperature: ~24h).
    private static func stabilityBreached(
        _ parameter: WaterParameter,
        latest: TestReading,
        readings: [TestReading],
        delta: Double,
        within interval: TimeInterval? = nil
    ) -> Bool {
        guard let latestValue = parameter.value(in: latest) else { return false }
        // First older reading that also has this parameter.
        guard let previous = readings.dropFirst().first(where: { parameter.value(in: $0) != nil }),
              let previousValue = parameter.value(in: previous) else { return false }
        if let interval, latest.timestamp.timeIntervalSince(previous.timestamp) > interval {
            return false
        }
        return abs(latestValue - previousValue) > delta
    }

    // MARK: - Helpers

    /// §6.4 — is tank nitrate close enough to the tap baseline that a water change
    /// won't help? Uses "within 15 ppm or below the baseline".
    private static func nitrateNearTapBaseline(latest: TestReading, tank: Tank) -> Bool {
        guard let baseline = tank.tapWaterNitrate, let nitrate = latest.nitrate else { return false }
        return nitrate <= baseline + 15
    }

    private static func orderIndex(_ parameter: WaterParameter) -> Int {
        WaterParameter.displayOrder.firstIndex(of: parameter) ?? .max
    }
}
