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
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Color.App.secondaryText.opacity(0.5))

            VStack(spacing: Spacing.xSmall) {
                Text(title)
                    .font(.App.headline)

                Text(message)
                    .font(.App.subheadline)
                    .foregroundColor(Color.App.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            if let actionTitle = actionTitle, let action = action {
                PrimaryButton(actionTitle, action: action)
                    .padding(.top, Spacing.small)
            }
        }
        .padding(Spacing.xxxLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
