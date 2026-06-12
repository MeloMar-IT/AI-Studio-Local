import SwiftUI

struct ProjectStudioView: View {
    var body: some View {
        VStack {
            Text("Project Studio")
                .font(.largeTitle)
                .padding()
            Text("Create and edit your AI video projects here.")
                .foregroundColor(.secondary)

            Spacer()

            Image(systemName: "video.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.3))
                .padding()

            Text("Select or create a project to get started.")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
