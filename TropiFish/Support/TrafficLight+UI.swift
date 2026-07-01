import SwiftUI

/// UI mapping for the traffic-light status (brief §12: desaturated, calm
/// traffic-light colours rather than saturated stoplight ones, so a warning
/// reads as considered rather than alarming).
extension TrafficLight {
    var color: Color {
        switch self {
        case .green: return Color(red: 0.30, green: 0.62, blue: 0.42)
        case .amber: return Color(red: 0.82, green: 0.60, blue: 0.24)
        case .red:   return Color(red: 0.78, green: 0.33, blue: 0.31)
        }
    }

    var label: String {
        switch self {
        case .green: return "All clear"
        case .amber: return "Needs attention"
        case .red:   return "Action needed"
        }
    }

    var systemImage: String {
        switch self {
        case .green: return "checkmark.circle.fill"
        case .amber: return "exclamationmark.triangle.fill"
        case .red:   return "exclamationmark.octagon.fill"
        }
    }
}

extension RiskLevel {
    /// Short status word for a per-parameter row.
    var statusLabel: String {
        switch self {
        case .safe:     return "OK"
        case .caution:  return "Caution"
        case .danger:   return "Danger"
        case .critical: return "Critical"
        }
    }

    var color: Color { trafficLight.color }
}
