import SwiftUI

/// Always-available "About" screen, reached from the Tanks tab. Re-presents the
/// onboarding content — full feature list, the built-by-keepers / guide-only
/// message, and a way to get in touch — so the disclaimer and contact stay
/// discoverable after first run, and links out to the photo credits.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    FeatureList(features: AppInfo.features)
                    MadeByKeepersCard()

                    NavigationLink {
                        ImageCreditsView()
                    } label: {
                        Label("Fish photo credits", systemImage: "camera.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                    }
                    .buttonStyle(.plain)

                    Text("\(AppInfo.versionString) · An app by \(AppInfo.studioName)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "drop.halffull")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tint)
            Text("TropiFish")
                .font(.largeTitle.bold())
            Text("Your aquarium's water, fish and filter — all in one place.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) { AboutView() }
}
