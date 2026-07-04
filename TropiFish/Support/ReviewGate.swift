import Foundation

/// Decides *when* to ask for an App Store review. We only get a handful of
/// prompts per user per year (Apple throttles `requestReview` and may show
/// nothing), so we spend one on a genuine positive moment during the trial —
/// after the keeper has logged a few tests or seen a tank go "all clear" — and
/// never right next to the paywall, where it would bias the rating.
///
/// State lives in `UserDefaults`; the actual prompt is fired by a view holding
/// the `\.requestReview` environment action (see `TankDetailView`).
enum ReviewGate {
    private static let d = UserDefaults.standard
    private static let countKey = "reviewTestsLogged"
    private static let askedKey = "reviewRequested"
    private static let trialStartKey = "trialStartDate"

    /// Minimum days since install before we'll ask, so brand-new users who
    /// haven't lived with the app yet aren't prompted.
    private static let minDaysSinceInstall = 3
    /// Tests logged that, on their own, signal an engaged keeper.
    private static let testsThreshold = 4

    static var testsLogged: Int { d.integer(forKey: countKey) }
    static var hasAsked: Bool { d.bool(forKey: askedKey) }

    static func recordTestLogged() {
        d.set(testsLogged + 1, forKey: countKey)
    }

    static func markAsked() { d.set(true, forKey: askedKey) }

    /// Whether this is a good moment to prompt. `tankAllClear` should be true
    /// when the tank the user just acted on is showing a green, all-in-range
    /// status — a natural "things are going well" beat.
    static func shouldAsk(tankAllClear: Bool) -> Bool {
        guard !hasAsked else { return false }
        let start = d.object(forKey: trialStartKey) as? Date ?? Date()
        let days = Calendar.current.dateComponents([.day], from: start, to: Date()).day ?? 0
        guard days >= minDaysSinceInstall else { return false }
        return testsLogged >= testsThreshold || tankAllClear
    }
}
