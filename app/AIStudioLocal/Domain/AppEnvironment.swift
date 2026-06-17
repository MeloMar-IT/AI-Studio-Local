import Foundation

public enum AppEnvironment: String, Codable, CaseIterable {
    case development
    case test
    case production

    public var isProduction: Bool {
        self == .production
    }
}
