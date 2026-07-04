import Foundation

/// The seven v1 water parameters, as a single source of truth for display,
/// units, value extraction and safe-range lookup (brief §3, §6). Ammonia is
/// represented here by its *calculated* toxic NH₃-N figure — the app's headline
/// number (§6.2) — not the raw TAN reading.
///
/// Nitrite and ammonia deliberately return `nil` from `range(in:)`: they are not
/// assessed with a simple min/max band (nitrite is zero-tolerance §6.3; ammonia
/// uses calculated risk tiers §6.2). Everything else is a genuine range.
enum WaterParameter: String, CaseIterable, Identifiable {
    case ammonia
    case nitrite
    case nitrate
    case kh
    case gh
    case ph
    case temperature

    var id: String { rawValue }

    /// Order the assessment/detail UI presents parameters in — acute dangers
    /// first (ammonia, nitrite), then the slower indicators.
    static let displayOrder: [WaterParameter] = [
        .ammonia, .nitrite, .nitrate, .kh, .gh, .ph, .temperature
    ]

    var displayName: String {
        switch self {
        case .ammonia:     return "Ammonia"
        case .nitrite:     return "Nitrite"
        case .nitrate:     return "Nitrate"
        case .kh:          return "KH"
        case .gh:          return "GH"
        case .ph:          return "pH"
        case .temperature: return "Temperature"
        }
    }

    /// Unit shown next to the value. pH is unitless.
    var unit: String {
        switch self {
        case .ammonia:     return "ppm NH₃-N"
        case .nitrite:     return "ppm"
        case .nitrate:     return "ppm"
        case .kh:          return "dKH"
        case .gh:          return "dGH"
        case .ph:          return ""
        case .temperature: return "°C"
        }
    }

    var systemImage: String {
        switch self {
        case .ammonia:     return "aqi.high"
        case .nitrite:     return "aqi.medium"
        case .nitrate:     return "chart.line.uptrend.xyaxis"
        case .kh:          return "shield.lefthalf.filled"
        case .gh:          return "drop.halffull"
        case .ph:          return "waveform.path.ecg"
        case .temperature: return "thermometer.medium"
        }
    }

    /// Canonical value used for status and charts. Ammonia resolves to the
    /// calculated NH₃-N (nil unless the TAN+pH+temp bundle is complete, §6.2).
    func value(in reading: TestReading) -> Double? {
        switch self {
        case .ammonia:     return reading.unIonizedAmmonia
        case .nitrite:     return reading.nitrite
        case .nitrate:     return reading.nitrate
        case .kh:          return reading.kh
        case .gh:          return reading.gh
        case .ph:          return reading.ph
        case .temperature: return reading.temperatureC
        }
    }

    /// Configured safe range for a simple threshold/band check, or `nil` for the
    /// specially-handled parameters (ammonia, nitrite).
    func range(in targets: ParameterTargets) -> ClosedRange<Double>? {
        switch self {
        case .ammonia, .nitrite: return nil
        case .nitrate:     return 0...targets.nitrateMax
        case .kh:          return targets.khMin...targets.khMax
        case .gh:          return targets.ghMin...targets.ghMax
        case .ph:          return targets.phMin...targets.phMax
        case .temperature: return targets.temperatureMin...targets.temperatureMax
        }
    }

    /// Reference band used to normalise this parameter onto a shared 0–100%
    /// "% of healthy range" axis for the combined overlay chart. Unlike
    /// `range(in:)` this is always defined: ammonia uses 0→its caution tier and
    /// nitrite uses 0→a nominal 0.25 ppm toxicity marker (both are "keep near
    /// zero", so 100% reads as "at the unsafe line"). The rest reuse their safe
    /// band, so 0–100% spans exactly the healthy range.
    func referenceBand(in targets: ParameterTargets) -> ClosedRange<Double> {
        switch self {
        case .ammonia: return 0...targets.ammoniaThresholds.caution
        case .nitrite: return 0...0.25
        default:       return range(in: targets) ?? 0...1
        }
    }

    /// Position a real value on the 0–100(+) normalised scale for the combined
    /// chart. Values above the band read past 100%, below read negative.
    func normalized(_ value: Double, in targets: ParameterTargets) -> Double {
        let band = referenceBand(in: targets)
        let span = band.upperBound - band.lowerBound
        guard span > 0 else { return 0 }
        return (value - band.lowerBound) / span * 100
    }

    /// Number of decimal places appropriate for this parameter's display.
    var fractionDigits: Int {
        switch self {
        case .ammonia:     return 3   // NH₃-N figures are small
        case .nitrite, .ph: return 2
        case .nitrate, .kh, .gh, .temperature: return 1
        }
    }

    /// Format a value with this parameter's unit (e.g. "0.045 ppm NH₃-N").
    func formatted(_ value: Double, includeUnit: Bool = true) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...fractionDigits)))
        guard includeUnit, !unit.isEmpty else { return number }
        return "\(number) \(unit)"
    }
}
