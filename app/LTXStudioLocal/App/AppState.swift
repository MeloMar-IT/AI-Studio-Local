import Foundation
import Combine

class AppState: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // Mock data indicators
    @Published var isModelLoaded: Bool = false
    @Published var activeJobsCount: Int = 0
}
