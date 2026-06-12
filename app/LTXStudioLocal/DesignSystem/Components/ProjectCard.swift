import SwiftUI

struct ProjectCard: View {
    let title: String
    let description: String
    let lastModified: String
    let thumbnail: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Thumbnail Placeholder
                ZStack {
                    if let thumbnail = thumbnail {
                        // In a real app, this would be an image
                        Color.App.secondaryBackground
                        Text(thumbnail)
                    } else {
                        Color.App.secondaryBackground
                        Image(systemName: "video")
                            .font(.largeTitle)
                            .foregroundColor(Color.App.secondaryText)
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text(title)
                        .font(.App.headline)
                        .lineLimit(1)

                    Text(description)
                        .font(.App.caption)
                        .foregroundColor(Color.App.secondaryText)
                        .lineLimit(2)
                        .frame(height: 32, alignment: .topLeading)

                    Text(lastModified)
                        .font(.system(size: 10))
                        .foregroundColor(Color.App.secondaryText.opacity(0.7))
                        .padding(.top, Spacing.xxSmall)
                }
                .padding(Spacing.small)
            }
            .background(Color.App.surface)
            .cornerRadius(Spacing.cornerRadiusLarge)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                    .stroke(Color.App.border, lineWidth: 1)
            )
            .shadow(color: Color.App.shadow, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .frame(width: 200)
    }
}

struct ProjectCard_Previews: PreviewProvider {
    static var previews: some View {
        ProjectCard(
            title: "Cyberpunk City",
            description: "A neon-lit city with flying cars and rainy streets.",
            lastModified: "Modified 2 hours ago",
            thumbnail: nil
        ) {}
        .padding()
    }
}
