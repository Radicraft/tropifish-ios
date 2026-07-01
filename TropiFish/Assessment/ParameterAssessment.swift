import Foundation

/// The assessed status of one parameter for a tank's latest reading (brief §6).
struct ParameterAssessment: Identifiable {
    let parameter: WaterParameter
    /// Canonical value assessed (NH₃-N for ammonia); `nil` if not measured in the
    /// latest reading.
    let value: Double?
    let risk: RiskLevel
    let trend: TrendDirection
    /// A rate-of-change alert fired for pH/temperature stability (§6.7, §6.8).
    let stabilityAlert: Bool
    /// Plain-English one-liner from the guidance table, or `nil` when all-clear.
    let guidance: String?

    var id: String { parameter.rawValue }

    var hasData: Bool { value != nil }

    /// Formatted headline value, or an em dash when not measured.
    var displayValue: String {
        guard let value else { return "—" }
        return parameter.formatted(value)
    }

    var trafficLight: TrafficLight { risk.trafficLight }
}

/// The whole-tank rollup used by the home card and detail header (brief §4.5).
struct TankAssessment {
    let parameters: [ParameterAssessment]
    /// The single most-urgent guidance line to surface on the card (§4.5).
    let headline: String?
    /// True once at least one parameter in the latest reading has data.
    let hasData: Bool

    /// Worst traffic light across parameters that have data; green when all-clear.
    var overall: TrafficLight {
        let worst = parameters.compactMap { $0.hasData ? $0.risk : nil }.max()
        return (worst ?? .safe).trafficLight
    }

    /// Parameters that are amber/red, most-severe first — the card's "attention"
    /// list.
    var flagged: [ParameterAssessment] {
        parameters
            .filter { $0.hasData && $0.risk > .safe }
            .sorted { $0.risk > $1.risk }
    }

    static let empty = TankAssessment(parameters: [], headline: nil, hasData: false)
}
