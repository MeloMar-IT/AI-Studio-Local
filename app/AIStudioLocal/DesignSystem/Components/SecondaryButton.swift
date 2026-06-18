import SwiftUI

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let isDestructive: Bool
    let action: () -> Void

    init(_ title: String, icon: String? = nil, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xSmall) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.xSmall)
            .frame(minHeight: 32)
            .background(isDestructive ? Color.red.opacity(0.1) : Color.App.secondaryBackground)
            .foregroundColor(isDestructive ? .red : Color.App.text)
            .cornerRadius(Spacing.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                    .stroke(isDestructive ? Color.red.opacity(0.5) : Color.App.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SecondaryButton_Previews: PreviewProvider {
    static var previews: some View {
        SecondaryButton("Cancel") {}
            .padding()
    }
}
