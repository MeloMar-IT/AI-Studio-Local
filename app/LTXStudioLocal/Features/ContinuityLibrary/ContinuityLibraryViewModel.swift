import Foundation
import Combine
import SwiftUI

@MainActor
class ContinuityLibraryViewModel: ObservableObject {
    private let store: ContinuityStore

    @Published var elements: [ContinuityElement] = []
    @Published var selectedCategory: ContinuityElementType?
    @Published var searchText: String = ""
    @Published var selectedElementId: String?
    @Published var isLoading: Bool = false
    @Published var error: Error?

    init(store: ContinuityStore = FileContinuityStore()) {
        self.store = store
        loadElements()
    }

    func loadElements() {
        isLoading = true
        do {
            elements = try store.loadAll()
            if elements.isEmpty {
                try store.loadDefaultElements()
                elements = try store.loadAll()
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    var filteredElements: [ContinuityElement] {
        elements.filter { element in
            let matchesCategory = selectedCategory == nil || element.type == selectedCategory
            let matchesSearch = searchText.isEmpty ||
                element.name.localizedCaseInsensitiveContains(searchText) ||
                element.description.localizedCaseInsensitiveContains(searchText) ||
                element.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesCategory && matchesSearch
        }
    }

    var selectedElement: ContinuityElement? {
        elements.first { $0.id == selectedElementId }
    }

    func selectElement(_ elementId: String?) {
        selectedElementId = elementId
    }

    func createNewElement(type: ContinuityElementType) {
        let newElement = ContinuityElement(
            type: type,
            name: "New \(type.rawValue.capitalized)",
            promptBlock: ""
        )
        do {
            try store.save(newElement)
            elements.append(newElement)
            selectedElementId = newElement.id
        } catch {
            self.error = error
        }
    }

    func updateElement(_ element: ContinuityElement) {
        do {
            try store.save(element)
            if let index = elements.firstIndex(where: { $0.id == element.id }) {
                elements[index] = element
            }
        } catch {
            self.error = error
        }
    }

    func deleteElement(_ elementId: String) {
        do {
            try store.delete(elementId: elementId)
            elements.removeAll { $0.id == elementId }
            if selectedElementId == elementId {
                selectedElementId = nil
            }
        } catch {
            self.error = error
        }
    }
}
