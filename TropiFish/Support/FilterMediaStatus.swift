import Foundation

/// Where a piece of filter media sits against its replacement schedule. A thin
/// three-state view mapped onto the app's existing `TrafficLight` vocabulary
/// (brief §4.5, §12) so the Filter section reads the same as the water traffic
/// light rather than inventing new colours.
enum FilterMediaStatus: Comparable {
    /// Comfortably before the due date.
    case ok
    /// Within the warning window (default 7 days) of the due date.
    case dueSoon
    /// Past the due date.
    case overdue

    /// Days before the due date at which an item starts showing amber.
    static let dueSoonWindowDays = 7

    /// Ordering so a tank's *worst* media status is `max(...)`.
    private var severity: Int {
        switch self {
        case .ok:      return 0
        case .dueSoon: return 1
        case .overdue: return 2
        }
    }

    static func < (lhs: FilterMediaStatus, rhs: FilterMediaStatus) -> Bool {
        lhs.severity < rhs.severity
    }

    /// Collapse to the tank-home traffic light.
    var trafficLight: TrafficLight {
        switch self {
        case .ok:      return .green
        case .dueSoon: return .amber
        case .overdue: return .red
        }
    }

    var label: String {
        switch self {
        case .ok:      return "OK"
        case .dueSoon: return "Due soon"
        case .overdue: return "Overdue"
        }
    }

    /// Classify a due date relative to `now` (injected for testability).
    static func of(dueDate: Date, now: Date = Date()) -> FilterMediaStatus {
        if dueDate <= now { return .overdue }
        let window = TimeInterval(dueSoonWindowDays * 24 * 60 * 60)
        if dueDate <= now.addingTimeInterval(window) { return .dueSoon }
        return .ok
    }
}
