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
        Group {
            if let bundledImage {
                bundledImage
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
