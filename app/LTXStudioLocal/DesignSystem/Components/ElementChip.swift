import SwiftUI

struct ElementChip: View {
    let label: String
    let icon: String?
    var isSelected: Bool = false
    let action: (() -> Void)?
    var onRemove: (() -> Void)? = nil

    init(_ label: String, icon: String? = nil, isSelected: Bool = false, action: (() -> Void)? = nil) {
        self.label = label
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    init(element: ContinuityElement, isSelected: Bool = false, action: (() -> Void)? = nil, onRemove: (() -> Void)? = nil) {
        self.label = element.name
        self.icon = element.type.iconName
        self.isSelected = isSelected
        self.action = action
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: Spacing.xxSmall) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.App.caption)
            }
            Text(label)
                .font(.App.caption)

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? .white.opacity(0.8) : Color.App.secondaryText)
                }
                .buttonStyle(.plain)
                .padding(.leading, 2)
            }
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
