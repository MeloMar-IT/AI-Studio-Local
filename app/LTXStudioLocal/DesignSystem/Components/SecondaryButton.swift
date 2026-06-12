import SwiftUI

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
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
            .background(Color.App.secondaryBackground)
            .foregroundColor(Color.App.text)
            .cornerRadius(Spacing.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                    .stroke(Color.App.border, lineWidth: 1)
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
