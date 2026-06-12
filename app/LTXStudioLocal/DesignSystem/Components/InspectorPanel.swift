import SwiftUI

struct InspectorPanel<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.App.headline)

                Spacer()

                IconButton(icon: "xmark") {
                    // Action to close or handle panel
                }
            }
            .padding(Spacing.medium)
            .background(Color.App.surface)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    content
                }
                .padding(Spacing.medium)
            }
        }
        .frame(width: 300)
        .background(Color.App.background)
        .overlay(
            Rectangle()
                .fill(Color.App.border)
                .frame(width: 1)
                .frame(maxHeight: .infinity),
            alignment: .leading
        )
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    let isCollapsible: Bool
    @State private var isExpanded: Bool
    let content: Content

    init(title: String, isCollapsible: Bool = false, isExpanded: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isCollapsible = isCollapsible
        self._isExpanded = State(initialValue: isExpanded)
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if isCollapsible {
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    HStack {
                        Text(title.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color.App.secondaryText)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color.App.secondaryText)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color.App.secondaryText)
            }

            if isExpanded {
                content
            }
        }
    }
}

struct InspectorPanel_Previews: PreviewProvider {
    static var previews: some View {
        InspectorPanel(title: "Scene Inspector") {
            InspectorSection(title: "Settings") {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("Duration: 5.0s")
                        .font(.App.subheadline)
                    Text("Resolution: 1080p")
                        .font(.App.subheadline)
                }
            }

            InspectorSection(title: "Elements") {
                HStack {
                    ElementChip("Cyberpunk", icon: "sparkles")
                    ElementChip("Marcel", icon: "person.fill")
                }
            }
        }
        .frame(height: 600)
    }
}
