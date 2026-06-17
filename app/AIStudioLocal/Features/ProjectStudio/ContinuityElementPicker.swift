import SwiftUI

struct ContinuityElementPicker: View {
    @StateObject private var viewModel = ContinuityLibraryViewModel()
    @Environment(\.dismiss) private var dismiss

    let onSelect: (ContinuityElement) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            HStack(spacing: 0) {
                categorySidebar

                VStack(spacing: 0) {
                    searchBar
                    elementList
                }
                .background(Color.App.background)
            }
        }
        .frame(width: 600, height: 400)
    }

    private var header: some View {
        HStack {
            Text("Add Reusable Element")
                .font(.App.headline)
            Spacer()
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.plain)
            .foregroundColor(Color.App.accent)
        }
        .padding()
        .background(Color.App.surface)
        .overlay(
            Rectangle()
                .fill(Color.App.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var categorySidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(selection: $viewModel.selectedCategory) {
                Text("All Categories")
                    .tag(nil as ContinuityElementType?)

                Section {
                    ForEach([ContinuityElementType.character, .location, .style, .camera, .audio, .brand, .promptBlock], id: \.self) { (type: ContinuityElementType) in
                        Label(type.rawValue.capitalized, systemImage: type.iconName)
                            .tag(type as ContinuityElementType?)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 180)
        .overlay(
            Rectangle()
                .fill(Color.App.border)
                .frame(width: 1),
            alignment: .trailing
        )
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

    private var elementList: some View {
        Group {
            if viewModel.filteredElements.isEmpty {
                VStack {
                    Spacer()
                    Text("No elements found")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(viewModel.filteredElements) { element in
                            elementRow(element)
                        }
                    }
                }
            }
        }
    }

    private func elementRow(_ element: ContinuityElement) -> some View {
        Button(action: {
            onSelect(element)
            dismiss()
        }) {
            HStack(spacing: Spacing.small) {
                Image(systemName: element.iconName)
                    .foregroundColor(Color.App.accent)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(element.name)
                        .font(.App.body)
                        .foregroundColor(Color.App.text)

                    if !element.description.isEmpty {
                        Text(element.description)
                            .font(.App.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundColor(Color.App.accent)
            }
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            // Visual feedback could be added here
        }
    }
}
