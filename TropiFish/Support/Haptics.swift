import UIKit

/// Centralized haptic feedback for the app.
///
/// Called imperatively (rather than via SwiftUI's `.sensoryFeedback`) so a tap
/// still fires reliably when the triggering view dismisses immediately after —
/// e.g. a Save button that pops its sheet in the same run loop turn.
///
/// Kept deliberately sparse and typed by meaning: a *success* thud confirms a
/// committed change, a *warning* buzz pairs with an on-screen caution, a light
/// *impact* rewards a small additive action, and *selection* ticks navigation.
/// The goal is that every buzz is a signal, never decoration.
enum Haptics {
    /// A change was committed — a saved log, a new tank, media marked changed.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Something needs a second look — pairs with an alert or caution copy
    /// (e.g. adding a fish that isn't a clean match for the tank).
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    /// A small, satisfying additive tap (adding a fish, a firm delete).
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// A light tick for moving between peers — tabs, stepper increments.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
