import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let icon: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(title: String, message: String, icon: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Spacing.medium) {
            ZStack {
                Circle()
                    .fill(Color.App.accent.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: icon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(Color.App.accent)
            }
            .padding(.bottom, Spacing.small)

            VStack(spacing: Spacing.xSmall) {
                Text(title)
                    .font(.App.title3)
                    .foregroundColor(Color.App.text)

                Text(message)
                    .font(.App.body)
                    .foregroundColor(Color.App.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(actionTitle, action: action)
                    .padding(.top, Spacing.medium)
                    .controlSize(.large)
            }
        }
        .padding(Spacing.xxxLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.App.background)
    }
}

struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyStateView(
            title: "No Projects Yet",
            message: "Start by creating your first AI video project.",
            icon: "video.badge.plus",
            actionTitle: "New Project"
        ) {}
    }
}
