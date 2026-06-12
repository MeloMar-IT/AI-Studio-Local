import SwiftUI

struct RenderQueueView: View {
    var body: some View {
        VStack {
            Text("Render Queue")
                .font(.largeTitle)
                .padding()
            Text("Monitor your video generation progress.")
                .foregroundColor(.secondary)

            Spacer()

            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.3))
                .padding()

            Text("Active and completed jobs will appear here.")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
