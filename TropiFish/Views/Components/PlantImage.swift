import SwiftUI

/// A plant's photo from the asset catalog, with a leafy placeholder while the
/// bundled imagery is still being filled in — the plant-side counterpart to
/// `SpeciesImage`, kept identical in behaviour so browser, hero and stock rows
/// all degrade the same way.
struct PlantImage: View {
    let plant: Plant
    var cornerRadius: CGFloat = 12

    private var bundledImage: Image? {
        guard let asset = plant.imageAsset,
              UIImage(named: asset) != nil else { return nil }
        return Image(asset)
    }

    var body: some View {
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
                colors: [Color.green.opacity(0.22), Color.teal.opacity(0.16)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Image(systemName: "leaf.fill")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}
