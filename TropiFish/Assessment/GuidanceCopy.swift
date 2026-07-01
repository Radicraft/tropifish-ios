import Foundation

/// Context the guidance table needs beyond the raw risk/trend (brief §6.2, §6.4).
struct GuidanceContext {
    var isCycling: Bool = false
    var tankTypeName: String = "your tank"
    /// True when tank nitrate is close to the known tap-water baseline, so a
    /// water change won't meaningfully lower it (§6.4).
    var nitrateNearTapBaseline: Bool = false
}

/// Deterministic guidance-copy table keyed on (parameter, status, trend) — not
/// generated at runtime, so it's reviewable before shipping health-adjacent
/// advice (brief §6.1, §6.9). Returns `nil` when there is nothing worth saying.
enum GuidanceCopy {
    static func message(
        for parameter: WaterParameter,
        risk: RiskLevel,
        trend: TrendDirection,
        stabilityAlert: Bool,
        context: GuidanceContext
    ) -> String? {
        switch parameter {
        case .ammonia:     return ammonia(risk: risk, context: context)
        case .nitrite:     return nitrite(risk: risk)
        case .nitrate:     return nitrate(risk: risk, trend: trend, context: context)
        case .kh:          return kh(risk: risk, trend: trend)
        case .gh:          return gh(risk: risk, context: context)
        case .ph:          return ph(risk: risk, stabilityAlert: stabilityAlert)
        case .temperature: return temperature(risk: risk, stabilityAlert: stabilityAlert)
        }
    }

    // §6.2 — cycling tanks get informational copy, not alarm.
    private static func ammonia(risk: RiskLevel, context: GuidanceContext) -> String? {
        guard risk > .safe else { return nil }
        if context.isCycling {
            return "Ammonia is elevated, but this is expected while your tank is cycling. Keep testing daily and avoid large water changes that can slow the cycle."
        }
        switch risk {
        case .caution:
            return "Calculated ammonia is creeping up for your current pH and temperature. Re-test soon and check feeding."
        case .danger, .critical:
            return "Calculated ammonia risk is high for your current pH and temperature. Do a water change now and check for overstocking or overfeeding."
        case .safe:
            return nil
        }
    }

    // §6.3 — any non-zero nitrite is a red flag; do not soften with trend.
    private static func nitrite(risk: RiskLevel) -> String? {
        guard risk > .safe else { return nil }
        return "Nitrite detected — this is always a red flag. Do a partial water change and re-test in 24 hours."
    }

    // §6.4 — trend-weighted, and aware of the tap-water baseline.
    private static func nitrate(risk: RiskLevel, trend: TrendDirection, context: GuidanceContext) -> String? {
        if risk >= .danger {
            if context.nitrateNearTapBaseline {
                return "Nitrate is high but close to your tap-water baseline — a water change alone won't bring it down much. Consider reducing feeding or stocking."
            }
            return "Nitrate is high\(trend == .rising ? " and climbing" : ""). Do a 20–30% water change and check feeding and stocking levels."
        }
        if trend == .rising {
            return "Nitrate has risen three tests running. It's still in range, but consider a water change before it climbs further."
        }
        return nil
    }

    // §6.5 — low-and-falling is the important signal.
    private static func kh(risk: RiskLevel, trend: TrendDirection) -> String? {
        guard risk > .safe || trend == .falling else { return nil }
        if trend == .falling {
            return "KH is trending down — pH crashes become more likely as buffering capacity drops. Consider a KH buffer or more frequent water changes."
        }
        return "KH is outside its range. Low KH leaves pH prone to swings; check buffering if it keeps drifting."
    }

    // §6.6 — suitability, not danger: framed softly.
    private static func gh(risk: RiskLevel, context: GuidanceContext) -> String? {
        guard risk > .safe else { return nil }
        return "GH is outside the ideal range for \(context.tankTypeName). This affects long-term health and breeding more than it's an immediate danger."
    }

    // §6.7 — stability matters as much as the number.
    private static func ph(risk: RiskLevel, stabilityAlert: Bool) -> String? {
        if stabilityAlert {
            return "pH shifted noticeably since your last test. Rapid pH changes stress fish more than a stable off-target pH — check what changed (water change size, new decor, CO₂)."
        }
        guard risk > .safe else { return nil }
        return "pH is outside its configured range. A stable pH matters more than hitting an exact number, so aim for gradual correction."
    }

    // §6.8 — a swing is a stressor independent of the absolute values.
    private static func temperature(risk: RiskLevel, stabilityAlert: Bool) -> String? {
        if stabilityAlert {
            return "Temperature changed by more than your stability threshold since the last reading. Check the heater and room temperature — sudden swings stress fish and can trigger disease."
        }
        guard risk > .safe else { return nil }
        return "Temperature is outside the ideal range. Adjust the heater gradually rather than in large jumps."
    }
}
