import SwiftUI

struct ProgressCard: View {
    let title: String
    let subtitle: String
    let progress: Double // 0.0 to 1.0
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                    Text(title)
                        .font(.App.headline)
                    Text(subtitle)
                        .font(.App.caption)
                        .foregroundColor(Color.App.secondaryText)
                }

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.App.headline)
                    .foregroundColor(Color.App.accent)
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Color.App.accent)

            HStack {
                Image(systemName: "gearshape.2")
                    .font(.App.footnote)
                    .foregroundColor(Color.App.secondaryText)
                Text(status)
                    .font(.App.footnote)
                    .foregroundColor(Color.App.secondaryText)

                Spacer()

                Button("Cancel") {
                    // Action
                }
                .buttonStyle(.plain)
                .font(.App.footnote)
                .foregroundColor(Color.App.error)
            }
        }
        .padding(Spacing.medium)
        .background(Color.App.surface)
        .cornerRadius(Spacing.cornerRadiusLarge)
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                .stroke(Color.App.border, lineWidth: 1)
        )
    }
}

struct ProgressCard_Previews: PreviewProvider {
    static var previews: some View {
        ProgressCard(
            title: "Generating Scene 1",
            subtitle: "Cyberpunk City",
            progress: 0.45,
            status: "Generating video frames..."
        )
        .padding()
        .frame(width: 400)
    }
}
