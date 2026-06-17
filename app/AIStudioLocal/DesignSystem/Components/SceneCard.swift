import SwiftUI

struct SceneCard: View {
    let sceneNumber: Int
    let prompt: String
    let duration: String
    let status: String
    let statusColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Color.App.secondaryBackground
                    Image(systemName: "photo")
                        .foregroundColor(Color.App.secondaryText.opacity(0.5))

                    Text("\(sceneNumber)")
                        .font(.App.footnote)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .padding(Spacing.xSmall)
                }
                .frame(height: 100)
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                    Text(prompt)
                        .font(.App.caption)
                        .lineLimit(2)
                        .frame(height: 32, alignment: .topLeading)

                    HStack {
                        Text(duration)
                            .font(.system(size: 10))
                            .foregroundColor(Color.App.secondaryText)

                        Spacer()

                        StatusBadge(label: status, color: statusColor)
                    }
                    .padding(.top, Spacing.xxSmall)
                }
                .padding(Spacing.small)
            }
            .background(Color.App.surface)
            .cornerRadius(Spacing.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                    .stroke(Color.App.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(width: 160)
    }
}

struct SceneCard_Previews: PreviewProvider {
    static var previews: some View {
        SceneCard(
            sceneNumber: 1,
            prompt: "A wide shot of a desert landscape.",
            duration: "5.0s",
            status: "Ready",
            statusColor: .green
        ) {}
        .padding()
    }
}
