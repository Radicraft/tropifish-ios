import SwiftUI

/// Displays a species' photo from the asset catalog, falling back to a tasteful
/// placeholder while the bundled imagery is still being filled in (the dataset
/// grows ahead of the images). Keeping this in one place means the browser,
/// detail hero, and stock rows all degrade the same way.
struct SpeciesImage: View {
    let species: Species
    var cornerRadius: CGFloat = 12

    private var bundledImage: Image? {
        guard let asset = species.imageAsset,
              UIImage(named: asset) != nil else { return nil }
        return Image(asset)
    }

    var body: some View {
        // `Color.clear` takes whatever frame the caller sets; the image fills it
        // as an overlay and is hard-clipped to those bounds. Without this, a
        // `scaledToFill` photo overflows its frame and bleeds past the row/hero
        // edges (the clip must come *after* the caller's `.frame`, not before).
        Color.clear
            .overlay {
                if let bundledImage {
                    bundledImage
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.teal.opacity(0.22), Color.blue.opacity(0.16)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: "fish.fill")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}
