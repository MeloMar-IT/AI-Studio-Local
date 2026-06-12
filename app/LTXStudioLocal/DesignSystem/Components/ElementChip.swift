import SwiftUI

struct ElementChip: View {
    let label: String
    let icon: String?
    var isSelected: Bool = false
    let action: (() -> Void)?

    init(_ label: String, icon: String? = nil, isSelected: Bool = false, action: (() -> Void)? = nil) {
        self.label = label
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        HStack(spacing: Spacing.xxSmall) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.App.caption)
            }
            Text(label)
                .font(.App.caption)
        }
        .padding(.horizontal, Spacing.small)
        .padding(.vertical, Spacing.xxSmall)
        .background(isSelected ? Color.App.accent : Color.App.secondaryBackground)
        .foregroundColor(isSelected ? .white : Color.App.text)
        .cornerRadius(Spacing.xxxLarge) // Pills are usually very rounded
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.xxxLarge)
                .stroke(Color.App.border, lineWidth: 1)
        )
        .contentShape(Rectangle()) // Ensure the whole area is tappable
        .onTapGesture {
            action?()
        }
    }
}

struct ElementChip_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ElementChip("Cinematic", icon: "video")
            ElementChip("Marcel", icon: "person.fill", isSelected: true)
        }
        .padding()
    }
}
