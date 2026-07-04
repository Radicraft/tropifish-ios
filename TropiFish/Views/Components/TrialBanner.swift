import SwiftUI

/// A gentle, tappable trial-status card for the tank list (free-trial →
/// one-time-unlock model). Shows days remaining while the trial runs, then an
/// unlock nudge once it ends. Tapping opens the paywall. Callers should only
/// show it while the app is unpaid (`!access.isUnlocked`).
struct TrialBanner: View {
    @EnvironmentObject private var access: AccessManager

    var body: some View {
        Button {
            access.isShowingPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: access.isTrialActive ? "clock.badge.checkmark" : "lock.fill")
                    .font(.title3)
                    .foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Text("Unlock")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var tint: Color { access.isTrialActive ? .teal : .orange }

    private var title: String {
        if access.isTrialActive {
            let d = access.trialDaysRemaining
            return "Free trial — \(d) day\(d == 1 ? "" : "s") left"
        }
        return "Free trial ended"
    }

    private var subtitle: String {
        access.isTrialActive
            ? "Enjoying TropiFish? Unlock it once — \(access.displayPrice), no subscription — to keep it for good."
            : "Unlock to keep logging tests, adding stock, and viewing trends. Your data is still here."
    }
}
