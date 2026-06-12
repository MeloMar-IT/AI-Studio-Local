import SwiftUI

struct HomeDashboardView: View {
    var body: some View {
        VStack(spacing: Spacing.xxLarge) {
            VStack(spacing: Spacing.xSmall) {
                Text("Welcome to LTX Studio Local")
                    .font(.App.largeTitle)
                Text("Create stunning AI videos locally on your Mac.")
                    .font(.App.subtitle)
                    .foregroundColor(Color.App.secondaryText)
            }

            HStack(spacing: Spacing.medium) {
                DashboardCard(title: "New Project", icon: "plus.circle", description: "Start a new video creation from scratch.")
                DashboardCard(title: "Open Project", icon: "folder", description: "Continue working on an existing project.")
            }

            VStack(alignment: .leading, spacing: Spacing.medium) {
                Text("Recent Projects")
                    .font(.App.headline)

                EmptyStateView(
                    title: "No Recent Projects",
                    message: "Your recently edited projects will appear here.",
                    icon: "clock"
                )
                .frame(height: 200)
                .background(Color.App.surface)
                .cornerRadius(Spacing.cornerRadiusLarge)
                .overlay(
                    RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                        .stroke(Color.App.border, style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
            }
            .frame(maxWidth: 600)

            Spacer()
        }
        .padding(Spacing.xxLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.App.background)
    }
}

struct DashboardCard: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        Button(action: {}) {
            VStack(spacing: Spacing.medium) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(Color.App.accent)

                VStack(spacing: Spacing.xxSmall) {
                    Text(title)
                        .font(.App.headline)
                    Text(description)
                        .font(.App.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.App.secondaryText)
                }
            }
            .frame(width: 200, height: 160)
            .background(Color.App.surface)
            .cornerRadius(Spacing.cornerRadiusLarge)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                    .stroke(Color.App.border, lineWidth: 1)
            )
            .shadow(color: Color.App.shadow, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct HomeDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        HomeDashboardView()
    }
}
