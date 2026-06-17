import SwiftUI

struct IconButton: View {
    let icon: String
    let action: () -> Void
    var tooltip: String? = nil

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip ?? "")
    }
}

struct IconButton_Previews: PreviewProvider {
    static var previews: some View {
        IconButton(icon: "trash") {}
            .padding()
    }
}
