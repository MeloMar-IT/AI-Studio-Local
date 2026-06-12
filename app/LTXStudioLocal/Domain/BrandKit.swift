import Foundation

public struct BrandKit: Codable, Identifiable, Equatable {
    public var element: ContinuityElement

    // Overlay Metadata
    public var logoAssetPath: String?
    public var brandColors: [String] // Hex codes
    public var titleCardSettings: OverlaySettings
    public var lowerThirdSettings: OverlaySettings
    public var watermarkSettings: WatermarkSettings
    public var subtitleStyleSettings: SubtitleSettings
    public var introCardText: String
    public var outroCardText: String
    public var ctaTemplates: [String]

    public var id: String { element.id }

    public init(element: ContinuityElement) {
        self.element = element
        self.brandColors = ["#000000", "#FFFFFF"]
        self.titleCardSettings = .defaultTitle
        self.lowerThirdSettings = .defaultLowerThird
        self.watermarkSettings = .defaultWatermark
        self.subtitleStyleSettings = .defaultSubtitles
        self.introCardText = ""
        self.outroCardText = ""
        self.ctaTemplates = []

        // Attempt to restore from promptBlock if it contains JSON
        if element.promptBlock.starts(with: "{") {
            if let data = element.promptBlock.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(BrandMetadata.self, from: data) {
                self.logoAssetPath = decoded.logoAssetPath
                self.brandColors = decoded.brandColors
                self.titleCardSettings = decoded.titleCardSettings
                self.lowerThirdSettings = decoded.lowerThirdSettings
                self.watermarkSettings = decoded.watermarkSettings
                self.subtitleStyleSettings = decoded.subtitleStyleSettings
                self.introCardText = decoded.introCardText
                self.outroCardText = decoded.outroCardText
                self.ctaTemplates = decoded.ctaTemplates
            }
        }
    }

    public init(name: String, promptBlock: String) {
        self.element = ContinuityElement(type: .brand, name: name, promptBlock: promptBlock)
        self.brandColors = ["#000000", "#FFFFFF"]
        self.titleCardSettings = .defaultTitle
        self.lowerThirdSettings = .defaultLowerThird
        self.watermarkSettings = .defaultWatermark
        self.subtitleStyleSettings = .defaultSubtitles
        self.introCardText = ""
        self.outroCardText = ""
        self.ctaTemplates = []
    }

    /// Updates the underlying ContinuityElement's promptBlock with serialized metadata
    public mutating func syncElement() {
        let metadata = BrandMetadata(
            logoAssetPath: logoAssetPath,
            brandColors: brandColors,
            titleCardSettings: titleCardSettings,
            lowerThirdSettings: lowerThirdSettings,
            watermarkSettings: watermarkSettings,
            subtitleStyleSettings: subtitleStyleSettings,
            introCardText: introCardText,
            outroCardText: outroCardText,
            ctaTemplates: ctaTemplates
        )
        if let data = try? JSONEncoder().encode(metadata),
           let jsonString = String(data: data, encoding: .utf8) {
            element.promptBlock = jsonString
        }
    }
}

// Internal helper for serialization
struct BrandMetadata: Codable {
    var logoAssetPath: String?
    var brandColors: [String]
    var titleCardSettings: OverlaySettings
    var lowerThirdSettings: OverlaySettings
    var watermarkSettings: WatermarkSettings
    var subtitleStyleSettings: SubtitleSettings
    var introCardText: String
    var outroCardText: String
    var ctaTemplates: [String]
}

public struct OverlaySettings: Codable, Equatable {
    public var isEnabled: Bool
    public var fontName: String
    public var fontSize: Double
    public var color: String // Hex
    public var backgroundColor: String? // Hex
    public var position: OverlayPosition

    public static var defaultTitle: OverlaySettings {
        OverlaySettings(isEnabled: true, fontName: "Helvetica-Bold", fontSize: 48, color: "#FFFFFF", backgroundColor: "#00000088", position: .center)
    }

    public static var defaultLowerThird: OverlaySettings {
        OverlaySettings(isEnabled: true, fontName: "Helvetica", fontSize: 24, color: "#FFFFFF", backgroundColor: "#000000AA", position: .bottomLeft)
    }
}

public struct WatermarkSettings: Codable, Equatable {
    public var isEnabled: Bool
    public var opacity: Double
    public var scale: Double
    public var position: OverlayPosition

    public static var defaultWatermark: WatermarkSettings {
        WatermarkSettings(isEnabled: true, opacity: 0.5, scale: 1.0, position: .topRight)
    }
}

public struct SubtitleSettings: Codable, Equatable {
    public var isEnabled: Bool
    public var fontName: String
    public var fontSize: Double
    public var color: String
    public var outlineColor: String

    public static var defaultSubtitles: SubtitleSettings {
        SubtitleSettings(isEnabled: true, fontName: "Helvetica", fontSize: 18, color: "#FFFFFF", outlineColor: "#000000")
    }
}

public enum OverlayPosition: String, Codable, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight, center, topCenter, bottomCenter
}

extension BrandKit {
    public static var mock: BrandKit {
        var kit = BrandKit(name: "Tech-Future Branding", promptBlock: "Logo in top right, clean sans-serif lower thirds, cyan accents")
        kit.brandColors = ["#00FFFF", "#000000"]
        kit.introCardText = "Welcome to the Future"
        kit.outroCardText = "Thanks for watching"
        kit.syncElement()
        return kit
    }
}
