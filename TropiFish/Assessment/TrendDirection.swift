import Foundation

/// Direction of movement across the most recent readings (brief §6.1 trend
/// check). A parameter that has moved the same way across the last three tests
/// is flagged even while its absolute value is still inside the safe range —
/// this is what catches a slow nitrate creep or a depleting KH early.
enum TrendDirection: String {
    case rising
    case falling
    case steady
    case insufficientData

    var isDirectional: Bool { self == .rising || self == .falling }

    /// Detect a trend from values ordered **newest-first** (the order
    /// `Tank.readingsByDateDescending` produces). Considers up to the last five
    /// but requires at least three consecutive same-direction moves.
    ///
    /// `epsilon` treats sub-noise wobble as steady so measurement granularity
    /// (e.g. a test kit that only resolves to 0.25 ppm) doesn't fake a trend.
    static func detect(newestFirst values: [Double], epsilon: Double = 0) -> TrendDirection {
        let recent = Array(values.prefix(5))
        guard recent.count >= 3 else { return .insufficientData }
        // Walk oldest→newest and check the three most recent transitions.
        let ordered = Array(recent.reversed())
        let lastThree = Array(ordered.suffix(3))

        var rising = true
        var falling = true
        for i in 1..<lastThree.count {
            let delta = lastThree[i] - lastThree[i - 1]
            if delta <= epsilon { rising = false }
            if delta >= -epsilon { falling = false }
        }
        if rising { return .rising }
        if falling { return .falling }
        return .steady
    }
}
