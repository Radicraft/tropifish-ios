import SwiftUI

extension View {
    /// Constrain content to a comfortable reading column and centre it, so
    /// `ScrollView`-based screens (detail sheets, charts, the paywall) don't
    /// stretch edge-to-edge on iPad. On a compact-width iPhone the content is
    /// already narrower than the cap, so this is a no-op there.
    func readableWidth(_ maxWidth: CGFloat = 700) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}
