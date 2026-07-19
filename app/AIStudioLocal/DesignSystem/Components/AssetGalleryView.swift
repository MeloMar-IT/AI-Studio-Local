import SwiftUI

struct AssetGalleryView: View {
    let assets: [ContinuityAsset]
    var onAdd: () -> Void
    var onDelete: (String) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 120), spacing: Spacing.medium)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Text("Reference Images")
                    .font(.App.headline)

                Spacer()

                Button(action: onAdd) {
                    Label("Add Image", systemImage: "plus")
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.App.accent)
                .font(.App.subheadline)
            }

            if assets.isEmpty {
                Button(action: onAdd) {
                    VStack(spacing: Spacing.small) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("Add reference images for consistency")
                            .font(.App.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(Spacing.xxLarge)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                            .stroke(Color.App.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
                }
                .buttonStyle(.plain)
            } else {
                LazyVGrid(columns: columns, spacing: Spacing.medium) {
                    ForEach(assets) { asset in
                        AssetThumbnailView(asset: asset, onDelete: { onDelete(asset.id) })
                    }

                    Button(action: onAdd) {
                        VStack {
                            Image(systemName: "plus")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 100, height: 100)
                        .background(Color.App.secondaryBackground)
                        .cornerRadius(Spacing.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                                .stroke(Color.App.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct AssetThumbnailView: View {
    let asset: ContinuityAsset
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let image = NSImage(contentsOfFile: asset.path) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(Spacing.cornerRadius)
            } else {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Missing")
                        .font(.App.xxSmall)
                        .foregroundColor(.secondary)
                }
                .frame(width: 100, height: 100)
                .background(Color.App.secondaryBackground)
                .cornerRadius(Spacing.cornerRadius)
            }

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .padding(Spacing.xxxSmall)
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

extension Font.App {
    static let xxSmall = Font.system(size: 8, design: .rounded)
}
