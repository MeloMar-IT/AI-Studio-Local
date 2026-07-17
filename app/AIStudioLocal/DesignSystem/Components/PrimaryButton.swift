import SwiftUI

struct PrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: {
            NSLog("🔘 PrimaryButton: Clicked '\(title)'")
            action()
        }) {
            HStack(spacing: Spacing.xSmall) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.xSmall)
            .frame(minHeight: 32)
            .background(isEnabled ? Color.App.accent : Color.App.accent.opacity(0.3))
            .foregroundColor(isEnabled ? .white : .white.opacity(0.6))
            .cornerRadius(Spacing.cornerRadius)
        }
        .buttonStyle(.plain)
    }
}

struct PrimaryButton_Previews: PreviewProvider {
    static var previews: some View {
        PrimaryButton("Create Video", icon: "sparkles") {}
            .padding()
    }
}
