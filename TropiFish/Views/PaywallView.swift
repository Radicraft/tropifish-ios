import SwiftUI

/// The one-time-unlock paywall (free-trial → buy-once model). Framed honestly as
/// a hobbyist project: no subscription, buy once, and the money funds future
/// updates. Shown when a trial-expired keeper taps a gated action, or from the
/// trial banner. Always dismissible — the soft-gate keeps existing data
/// viewable, so we never trap the user here.
struct PaywallView: View {
    @EnvironmentObject private var access: AccessManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    trialStatus
                    featureList
                    reassurance
                }
                .padding()
                .padding(.bottom, 8)
            }
            .safeAreaInset(edge: .bottom) { purchaseBar }
            .navigationTitle("Unlock TropiFish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.system(size: 46))
                .foregroundStyle(.teal)
                .padding(.top, 8)
            Text("Keep every feature, for good")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("A single payment of \(access.displayPrice) unlocks TropiFish forever — no subscription, ever.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var trialStatus: some View {
        if access.isTrialActive {
            Label("You still have \(access.trialDaysRemaining) day\(access.trialDaysRemaining == 1 ? "" : "s") left in your free trial.",
                  systemImage: "clock")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.teal)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        } else if access.isTrialExpired {
            Label("Your free trial has ended. Unlock to keep logging tests, adding stock, and viewing trends.",
                  systemImage: "lock.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.orange)
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(AppInfo.features) { feature in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: feature.icon)
                        .foregroundStyle(.teal)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title).font(.subheadline.weight(.semibold))
                        Text(feature.detail).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private var reassurance: some View {
        VStack(spacing: 6) {
            Text("TropiFish is a hobbyist project by \(AppInfo.studioName), a small studio of fishkeepers. Buying it once directly funds new species, plants, and features — thank you for supporting an independent app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("One-time purchase · No subscription · Your logs stay on your device")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 4)
    }

    private var purchaseBar: some View {
        VStack(spacing: 10) {
            if case .failed(let message) = access.purchaseState {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await access.purchase() }
            } label: {
                Group {
                    if access.purchaseState == .working {
                        ProgressView().tint(.white)
                    } else {
                        Text("Unlock full app · \(access.displayPrice)")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 26)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(access.purchaseState == .working)

            Button("Restore purchase") {
                Task { await access.restore() }
            }
            .font(.subheadline)
            .disabled(access.purchaseState == .working)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.bar)
    }
}

#Preview {
    PaywallView()
        .environmentObject(AccessManager())
}
