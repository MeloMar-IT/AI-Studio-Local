import SwiftUI

struct ModelCard: View {
    let name: String
    let type: String
    let status: String
    let statusColor: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.medium) {
                Image(systemName: "cpu")
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : Color.App.accent)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? Color.App.accent : Color.App.accent.opacity(0.1))
                    .cornerRadius(Spacing.cornerRadius)

                VStack(alignment: .leading, spacing: Spacing.xxxSmall) {
                    Text(name)
                        .font(.App.headline)
                        .foregroundColor(isSelected ? .white : Color.App.text)

                    Text(type)
                        .font(.App.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : Color.App.secondaryText)
                }

                Spacer()

                StatusBadge(label: status, color: isSelected ? .white : statusColor)
            }
            .padding(Spacing.small)
            .background(isSelected ? Color.App.accent : Color.App.surface)
            .cornerRadius(Spacing.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                    .stroke(isSelected ? Color.clear : Color.App.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ModelCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.medium) {
            ModelCard(
                name: "LTX Video v1",
                type: "Base Model",
                status: "Loaded",
                statusColor: .green,
                isSelected: false
            ) {}

            ModelCard(
                name: "Cinematic LoRA",
                type: "Style Adapter",
                status: "Ready",
                statusColor: .blue,
                isSelected: true
            ) {}
        }
        .padding()
        .frame(width: 350)
    }
}
