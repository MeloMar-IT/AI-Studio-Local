import SwiftUI

struct ProjectStudioView: View {
    var body: some View {
        EmptyStateView(
            title: "Project Studio",
            message: "Select or create a project to get started. Create and edit your AI video projects here.",
            icon: "video.badge.plus",
            actionTitle: "New Project"
        ) {
            // New Project Action
        }
        .background(Color.App.background)
    }
}
