import Foundation

/// App-level constants and the canonical feature list, shared by the first-run
/// `WelcomeView` and the always-available `AboutView` so the two never drift.
enum AppInfo {
    /// The studio behind the app, shown in the About screen and the disclaimer card.
    static let studioName = "Radicraft"

    /// Marketing version + build from the bundle, e.g. "Version 1.0 (1)".
    static var versionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    /// Where the in-app "Get in touch" mail is addressed. This is the public
    /// support/feedback contact — confirm it before an App Store release.
    static let supportEmail = "mikesoft98@gmail.com"

    /// Non-consumable "unlock the full app" product (free-trial → one-time-buy
    /// model). The price shown to the user comes from StoreKit's localised
    /// `displayPrice`; this literal is only a fallback for when the product can't
    /// be loaded (e.g. offline, or before the App Store Connect entry exists).
    static let unlockProductID = "com.fathom.TropiFish.fullaccess"
    static let unlockPriceFallback = "£4.99"

    /// Length of the free trial before the unlock is required.
    static let trialLengthDays = 14

    /// A pre-addressed feedback mail link for the "get in touch" affordances.
    static var feedbackMailURL: URL? {
        let subject = "TropiFish feedback"
        let encoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        return URL(string: "mailto:\(supportEmail)?subject=\(encoded)")
    }

    /// One capability of the app, shown as an icon + title + one-liner. The full
    /// list is the single source of truth for "what this app does" so onboarding
    /// and the About screen stay in step as features are added.
    struct Feature: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    static let features: [Feature] = [
        Feature(icon: "drop.fill", title: "Log tests fast",
                detail: "Tap in all seven parameters using the same increments as your test kit — a full log in under a minute."),
        Feature(icon: "checkmark.seal.fill", title: "Know what it means",
                detail: "A traffic-light status per tank, with calculated ammonia toxicity from your pH and temperature — not just the raw number."),
        Feature(icon: "text.bubble.fill", title: "Know what to do",
                detail: "Plain-English guidance that catches slow trends early and tells you the next step, not just that something's off."),
        Feature(icon: "fish.fill", title: "Stock the right fish",
                detail: "A built-in guide to over 130 species with photos, and a compatibility check that flags anything that won't suit your water or tank size."),
        Feature(icon: "leaf.fill", title: "Track fish and plants",
                detail: "A photo guide to common aquarium plants, plus a log for every inhabitant and plant — added, trimmed, lost, or just a note on how they're doing."),
        Feature(icon: "chart.xyaxis.line", title: "See the trends",
                detail: "Every parameter charted over time, so a slow drift shows up long before it becomes a problem."),
        Feature(icon: "wrench.and.screwdriver.fill", title: "Stay on top of maintenance",
                detail: "Track each piece of filter media and get reminders when it's due — plus water-change reminders on your own schedule.")
    ]
}
