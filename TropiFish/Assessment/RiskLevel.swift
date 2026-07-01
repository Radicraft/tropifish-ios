import Foundation

/// Four-level risk classification used by the assessment engine (brief §6.2
/// defines the four ammonia tiers; other parameters map onto the same scale so
/// the UI can treat status uniformly).
///
/// The tank-home traffic light (§4.5) is a 3-colour view of this: `.safe` →
/// green, `.caution` → amber, `.danger`/`.critical` → red. Keeping four levels
/// internally lets guidance copy distinguish "do a change soon" from "act now",
/// and lets low-urgency parameters like GH cap out at amber (§6.6).
enum RiskLevel: Int, Codable, Comparable, CaseIterable {
    case safe = 0
    case caution = 1
    case danger = 2
    case critical = 3

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Collapse to the tank-home traffic light (§4.5, §12: desaturated colours).
    var trafficLight: TrafficLight {
        switch self {
        case .safe:                 return .green
        case .caution:              return .amber
        case .danger, .critical:    return .red
        }
    }
}

/// Three-state traffic light shown on the tank home screen (brief §4.5, §12).
enum TrafficLight: String, Codable {
    case green
    case amber
    case red
}
