import SwiftUI

/// First-run onboarding (brief §8 polish). Sets expectations for what makes
/// TropiFish different — it interprets tests and tells you what to do, rather
/// than just storing numbers — then gets out of the way. Shown once.
struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Highlight: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
    }

    private let highlights = [
        Highlight(icon: "drop.fill", title: "Log tests fast",
                  detail: "Tap in all seven parameters using the same increments as your test kit — a full log in under a minute."),
        Highlight(icon: "checkmark.seal.fill", title: "Know what it means",
                  detail: "A traffic-light status per tank, with calculated ammonia toxicity from your pH and temperature — not just the raw number."),
        Highlight(icon: "text.bubble.fill", title: "Know what to do",
                  detail: "Plain-English guidance that catches slow trends early and tells you the next step, not just that something's off.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 10) {
                Image(systemName: "drop.halffull")
                    .font(.system(size: 52, weight: .light))
                    .foregroundStyle(.tint)
                Text("Welcome to TropiFish")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("A precision log for your aquarium water.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 22) {
                ForEach(highlights) { item in
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
            .padding(.horizontal, 28)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .interactiveDismissDisabled()
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) { WelcomeView() }
}
