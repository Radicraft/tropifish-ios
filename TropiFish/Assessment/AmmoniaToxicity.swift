import Foundation

/// The ammonia toxicity calculation (brief §6.2) — the app's actual point of
/// difference. Kept as a pure, dependency-free namespace so it can be exercised
/// against known reference values in tests before it's ever trusted in the UI
/// (the brief specifically calls for verifying this against reference values,
/// since a subtle bug here would silently give bad health advice — §13).
///
/// What a test kit reports is *total ammonia nitrogen* (TAN): toxic un-ionized
/// NH₃ plus much-less-toxic ionized NH₄⁺. The toxic fraction rises sharply with
/// pH and, more gently, with temperature — so the same TAN reading can be
/// low-risk in a cool, acidic tank and dangerous in a warm, alkaline one.
enum AmmoniaToxicity {

    /// Dissociation constant pKa for the NH₄⁺ ⇌ NH₃ equilibrium at temperature
    /// `temperatureC` (°C):  `pKa = 0.09018 + 2729.92 / (T + 273.15)`.
    static func pKa(temperatureC: Double) -> Double {
        0.09018 + 2729.92 / (temperatureC + 273.15)
    }

    /// Fraction of TAN present as toxic un-ionized NH₃, in `0...1`:
    /// `f = 1 / (1 + 10^(pKa − pH))`.
    static func toxicFraction(ph: Double, temperatureC: Double) -> Double {
        let exponent = pKa(temperatureC: temperatureC) - ph
        return 1.0 / (1.0 + pow(10.0, exponent))
    }

    /// Toxic un-ionized ammonia concentration (NH₃-N, ppm) — the headline figure
    /// the app displays instead of the raw TAN reading (brief §6.2):
    /// `NH₃-N = f × TAN`.
    static func unIonizedAmmonia(totalAmmoniaTAN: Double, ph: Double, temperatureC: Double) -> Double {
        toxicFraction(ph: ph, temperatureC: temperatureC) * totalAmmoniaTAN
    }

    /// Classify a calculated NH₃-N figure into a risk tier using the tank's
    /// (preset-adjustable) thresholds (brief §6.2 risk tiers).
    static func riskLevel(unIonizedAmmonia value: Double, thresholds: AmmoniaThresholds) -> RiskLevel {
        if value >= thresholds.critical { return .critical }
        if value >= thresholds.danger   { return .danger }
        if value >= thresholds.caution  { return .caution }
        return .safe
    }
}
