import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("General")) {
                Text("App Version: 1.0.0 (MVP)")
            }

            Section(header: Text("Worker Configuration")) {
                Text("Worker Status: Disconnected (Mock Mode)")
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Appearance")) {
                Text("Theme: Dark (Locked)")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
