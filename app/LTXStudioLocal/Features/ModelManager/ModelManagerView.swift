import SwiftUI

struct ModelManagerView: View {
    var body: some View {
        VStack {
            Text("Model Manager")
                .font(.largeTitle)
                .padding()
            Text("Download and manage local AI models.")
                .foregroundColor(.secondary)

            Spacer()

            Image(systemName: "cpu")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.3))
                .padding()

            Text("Local models will be managed here.")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
