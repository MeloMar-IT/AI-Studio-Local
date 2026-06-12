import SwiftUI

struct GenerationVersionCard: View {
    let generation: SceneGeneration
    let onUse: () -> Void
    let onViewPrompt: () -> Void
    let onDelete: () -> Void
    let onRegenerate: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Preview Image Placeholder
            ZStack {
                if let previewPath = generation.previewImagePath {
                    // In a real app, we would load the image from the path
                    // For now, use a placeholder
                    Rectangle()
                        .fill(Color.App.surface)
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color.App.border)
                        )
                } else {
                    Rectangle()
                        .fill(Color.App.surface)
                        .overlay(
                            Image(systemName: "video.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Color.App.border)
                        )
                }

                if isHovered {
                    Rectangle()
                        .fill(Color.black.opacity(0.3))

                    HStack(spacing: Spacing.medium) {
                        IconButton(icon: "play.fill", action: onUse)
                            .help("Use this version")
                        IconButton(icon: "sparkles", action: onRegenerate)
                            .help("Regenerate from same settings")
                    }
                }
            }
            .frame(height: 100)
            .clipped()

            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(generation.createdAt, style: .date)
                        .font(.App.caption)
                        .foregroundColor(Color.App.secondaryText)
                    Spacer()
                    Text(generation.createdAt, style: .time)
                        .font(.App.caption)
                        .foregroundColor(Color.App.secondaryText)
                }

                if let profile = generation.modelProfile {
                    Text(profile.name)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.App.accent.opacity(0.1))
                        .foregroundColor(Color.App.accent)
                        .cornerRadius(4)
                }

                HStack {
                    if let seed = generation.seed {
                        Text("Seed: \(seed)")
                            .font(.system(size: 9))
                    }

                    Spacer()

                    if let resolution = generation.resolution {
                        Text("\(resolution.width)x\(resolution.height)")
                            .font(.system(size: 9))
                    }
                }
                .foregroundColor(Color.App.secondaryText)
            }
            .padding(Spacing.small)
        }
        .background(Color.App.background)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.App.border, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Use this version", action: onUse)
            Button("View Prompt", action: onViewPrompt)
            Button("Regenerate from same settings", action: onRegenerate)
            Divider()
            Button("Delete version", role: .destructive, action: onDelete)
        }
    }
}

struct GenerationVersionCard_Previews: PreviewProvider {
    static var previews: some View {
        GenerationVersionCard(
            generation: .mock,
            onUse: {},
            onViewPrompt: {},
            onDelete: {},
            onRegenerate: {}
        )
        .frame(width: 180)
        .padding()
    }
}
