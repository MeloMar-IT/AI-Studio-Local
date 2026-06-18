import Foundation

public struct ProjectTemplate: Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String
    public let aspectRatio: String
    public let sceneStructures: [SceneTemplateStructure]

    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String,
        icon: String,
        aspectRatio: String,
        sceneStructures: [SceneTemplateStructure]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.aspectRatio = aspectRatio
        self.sceneStructures = sceneStructures
    }
}

public struct SceneTemplateStructure: Codable {
    public let name: String
    public let defaultPrompt: String

    public init(name: String, defaultPrompt: String = "") {
        self.name = name
        self.defaultPrompt = defaultPrompt
    }
}

extension ProjectTemplate {
    public static var defaultTemplates: [ProjectTemplate] = [
        ProjectTemplate(
            id: "linkedin-sre-explainer",
            name: "LinkedIn SRE Explainer",
            description: "A professional explainer video optimized for LinkedIn.",
            icon: "briefcase.fill",
            aspectRatio: "4:5",
            sceneStructures: [
                SceneTemplateStructure(name: "Hook", defaultPrompt: "A professional SRE standing in front of a dashboard, looking concerned but determined."),
                SceneTemplateStructure(name: "Problem", defaultPrompt: "Close up on a complex monitoring dashboard with many red alerts."),
                SceneTemplateStructure(name: "Example", defaultPrompt: "A simplified diagram of a microservices architecture showing a failure point."),
                SceneTemplateStructure(name: "Insight", defaultPrompt: "The SRE pointing at a solution on the screen, looking relieved."),
                SceneTemplateStructure(name: "Question", defaultPrompt: "A call to action screen with the SRE looking at the camera.")
            ]
        ),
        ProjectTemplate(
            id: "youtube-tech-intro",
            name: "YouTube Tech Intro",
            description: "An engaging intro for technology-focused YouTube videos.",
            icon: "play.rectangle.fill",
            aspectRatio: "16:9",
            sceneStructures: [
                SceneTemplateStructure(name: "Intro", defaultPrompt: "Dynamic fast-paced shots of high-tech hardware and code."),
                SceneTemplateStructure(name: "Problem", defaultPrompt: "A person looking frustrated with an old piece of technology."),
                SceneTemplateStructure(name: "Main Idea", defaultPrompt: "The channel logo appearing over a futuristic background."),
                SceneTemplateStructure(name: "Closing", defaultPrompt: "A smooth transition to the main content area.")
            ]
        ),
        ProjectTemplate(
            id: "book-promo-video",
            name: "Book Promo Video",
            description: "A vertical video designed to promote books on social media.",
            icon: "book.fill",
            aspectRatio: "9:16",
            sceneStructures: [
                SceneTemplateStructure(name: "Hook", defaultPrompt: "An atmospheric shot of an open book with pages turning slowly."),
                SceneTemplateStructure(name: "Book Value", defaultPrompt: "Close up on a key paragraph or a beautiful illustration from the book."),
                SceneTemplateStructure(name: "Quote", defaultPrompt: "Elegant text overlay of a powerful quote from the book over a blurred background."),
                SceneTemplateStructure(name: "CTA", defaultPrompt: "A shot of the book cover with 'Buy Now' or 'Available at' text.")
            ]
        )
    ]
}
