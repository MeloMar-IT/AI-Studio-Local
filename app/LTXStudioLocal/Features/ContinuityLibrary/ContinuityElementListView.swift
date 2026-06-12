import SwiftUI

struct ContinuityElementListView: View {
    @ObservedObject var viewModel: ContinuityLibraryViewModel

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if viewModel.filteredElements.isEmpty {
                emptyState
            } else {
                List(selection: $viewModel.selectedElementId) {
                    ForEach(viewModel.filteredElements) { element in
                        elementRow(element)
                            .tag(element.id)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search elements...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
        }
        .padding(Spacing.small)
        .background(Color.App.secondaryBackground)
        .cornerRadius(Spacing.small)
        .padding(Spacing.medium)
    }

    private func elementRow(_ element: ContinuityElement) -> some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: element.iconName)
                .foregroundColor(Color.App.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(element.name)
                    .font(.App.body)
                    .lineLimit(1)

                if !element.description.isEmpty {
                    Text(element.description)
                        .font(.App.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.medium) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))

            Text("No elements found")
                .font(.App.headline)

            Text("Try a different search or category.")
                .font(.App.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}
