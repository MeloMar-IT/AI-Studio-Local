import SwiftUI

struct StatusBadge: View {
    let label: String
    let color: Color

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, Spacing.xSmall)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

struct StatusBadge_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            StatusBadge(label: "Completed", color: .green)
            StatusBadge(label: "Processing", color: .blue)
            StatusBadge(label: "Failed", color: .red)
        }
        .padding()
    }
}
