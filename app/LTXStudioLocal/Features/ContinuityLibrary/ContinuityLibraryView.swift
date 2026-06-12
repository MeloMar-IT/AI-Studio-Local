import SwiftUI

struct ContinuityLibraryView: View {
    var body: some View {
        VStack {
            Text("Continuity Library")
                .font(.largeTitle)
                .padding()
            Text("Manage reusable characters, locations, and styles.")
                .foregroundColor(.secondary)

            Spacer()

            Image(systemName: "person.2.square.stack")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.3))
                .padding()

            Text("Your reusable creative elements will appear here.")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
