import SwiftUI

/// First-run onboarding (brief §8 polish). Sets expectations for what TropiFish
/// does — the full feature set, not just water logging — and who's behind it:
/// tropical-fish keepers, offering a guide to use alongside your own judgement.
/// Shown once; the same content lives on in `AboutView` for later reference.
struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    FeatureList(features: AppInfo.features)
                    MadeByKeepersCard()
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 12)
            }

            Button {
                Haptics.impact(.medium)
                hasCompletedOnboarding = true
                dismiss()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .background(.bar)
        }
        .interactiveDismissDisabled()
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "drop.halffull")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tint)
            Text("Welcome to TropiFish")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text("Your aquarium's water, fish and filter — all in one place.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

/// The app's feature highlights, laid out as icon + title + detail rows. Shared
/// by the Welcome screen and the About screen via `AppInfo.features`.
struct FeatureList: View {
    let features: [AppInfo.Feature]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(features) { item in
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: item.icon)
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(width: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title).font(.headline)
                        Text(item.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

/// The credibility + guide-only disclaimer + "get in touch" block. Its own view
/// so both onboarding and About present the same message identically.
struct MadeByKeepersCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Built by tropical-fish keepers", systemImage: "heart.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)

            Text("TropiFish is made by \(AppInfo.studioName), a small studio of hobbyists who keep these tanks ourselves. It's a **guide to use alongside your own judgement**, not a substitute for it — species data and safe ranges are sensible starting points, so always cross-check anything important for your fish.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Spotted something that looks wrong, or want a feature added? We'd genuinely like to hear from you.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let url = AppInfo.feedbackMailURL {
                Link(destination: url) {
                    Label("Get in touch", systemImage: "envelope.fill")
                        .font(.footnote.weight(.semibold))
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) { WelcomeView() }
}
