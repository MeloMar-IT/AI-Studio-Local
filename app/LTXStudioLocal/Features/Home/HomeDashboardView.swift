import SwiftUI

struct HomeDashboardView: View {
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 8) {
                Text("Welcome to LTX Studio Local")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Create stunning AI videos locally on your Mac.")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 20) {
                DashboardCard(title: "New Project", icon: "plus.circle", description: "Start a new video creation from scratch.")
                DashboardCard(title: "Open Project", icon: "folder", description: "Continue working on an existing project.")
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("Recent Projects")
                    .font(.headline)

                Text("No recent projects yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5])))
            }
            .frame(maxWidth: 600)

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DashboardCard: View {
    let title: String
    let icon: String
    let description: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 200, height: 160)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct HomeDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        HomeDashboardView()
    }
}
