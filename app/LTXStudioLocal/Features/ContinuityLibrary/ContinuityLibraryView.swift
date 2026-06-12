import SwiftUI

struct ContinuityLibraryView: View {
    @StateObject private var viewModel = ContinuityLibraryViewModel()

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            ContinuityElementListView(viewModel: viewModel)
                .navigationTitle("Library")
                .toolbar {
                    ToolbarItem {
                        Menu {
                            ForEach(ContinuityElementType.allCases, id: \.self) { type in
                                Button(type.rawValue.capitalized) {
                                    viewModel.createNewElement(type: type)
                                }
                            }
                        } label: {
                            Label("Add Element", systemImage: "plus")
                        }
                    }
                }
        } detail: {
            if let selectedElement = viewModel.selectedElement {
                ContinuityElementDetailView(viewModel: viewModel, element: selectedElement)
                    .id(selectedElement.id)
            } else {
                EmptyStateView(
                    title: "Select an element",
                    message: "Choose an element from the list or create a new one to get started.",
                    icon: "person.2.square.stack"
                )
            }
        }
    }

    private var sidebar: some View {
        List(selection: $viewModel.selectedCategory) {
            Text("Categories")
                .font(.App.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, Spacing.small)

            NavigationLink(value: nil as ContinuityElementType?) {
                Label("All Elements", systemImage: "square.grid.2x2")
            }

            Section {
                ForEach(ContinuityElementType.allCases, id: \.self) { type in
                    NavigationLink(value: type) {
                        Label(type.rawValue.capitalized, systemImage: iconForType(type))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Continuity")
    }

    private func iconForType(_ type: ContinuityElementType) -> String {
        switch type {
        case .character: return "person.fill"
        case .location: return "mappin.and.ellipse"
        case .style: return "paintpalette.fill"
        case .camera: return "video.fill"
        case .audio: return "waveform"
        case .brand: return "briefcase.fill"
        case .promptBlock: return "text.alignleft"
        case .lora: return "cpu"
        case .exportTemplate: return "square.and.arrow.up.fill"
        }
    }
}
