import Foundation

public struct ImportSummary: Identifiable {
    public let id = UUID()
    public var imported: Int = 0
    public var updated: Int = 0
    public var skipped: Int = 0
    public var failed: Int = 0
    public var errors: [String] = []

    public var totalProcessed: Int {
        imported + updated + skipped + failed
    }

    public init() {}
}

public enum ImportConflictStrategy {
    case skip
    case replace
    case keepBoth
}
