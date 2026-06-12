import Foundation

public struct ExportTemplate: Codable, Identifiable, Equatable {
    public var element: ContinuityElement

    public var id: String { element.id }

    public init(element: ContinuityElement) {
        self.element = element
    }

    public init(name: String, promptBlock: String) {
        self.element = ContinuityElement(type: .exportTemplate, name: name, promptBlock: promptBlock)
    }
}

extension ExportTemplate {
    public static var mock: ExportTemplate {
        ExportTemplate(name: "TikTok Vertical", promptBlock: "9:16 vertical export, 1080x1920, H.264")
    }
}
