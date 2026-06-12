import Foundation

public struct ImprovedPrompt: Equatable {
    public let original: String
    public let improved: String
    public let changes: [String: String]
}

public protocol PromptImprovementHelper {
    func improve(_ prompt: String) -> ImprovedPrompt
}

public final class DefaultPromptImprovementHelper: PromptImprovementHelper {
    public init() {}

    public func improve(_ prompt: String) -> ImprovedPrompt {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return ImprovedPrompt(original: prompt, improved: "", changes: [:])
        }

        // Rule-based enrichment
        let subject = extractSubject(from: trimmed)
        let action = extractAction(from: trimmed)
        var environment = "cinematic setting"
        var cameraMovement = "steady shot"
        var lighting = "natural lighting"
        var mood = "atmospheric"
        var audioCues = "subtle ambient sounds"

        // Basic keyword detection to tailor enrichment
        let lowerPrompt = trimmed.lowercased()

        if lowerPrompt.contains("city") || lowerPrompt.contains("urban") || lowerPrompt.contains("street") {
            environment = "bustling futuristic cityscape with neon reflections"
            lighting = "vibrant night lighting with blue and magenta hues"
            audioCues = "distant city hum, hover-vehicle whirring"
        } else if lowerPrompt.contains("forest") || lowerPrompt.contains("nature") || lowerPrompt.contains("tree") {
            environment = "lush ancient forest with giant moss-covered trees"
            lighting = "dappled sunlight filtering through dense canopy"
            audioCues = "rustling leaves, distant bird calls"
        } else if lowerPrompt.contains("interior") || lowerPrompt.contains("room") || lowerPrompt.contains("office") {
            environment = "sleek minimalist high-tech interior"
            lighting = "soft recessed LED lighting"
            audioCues = "faint electronic hum, keyboard clicks"
        }

        if lowerPrompt.contains("running") || lowerPrompt.contains("walking") || lowerPrompt.contains("moving") {
            cameraMovement = "dynamic tracking shot following the movement"
        } else if lowerPrompt.contains("looking") || lowerPrompt.contains("staring") || lowerPrompt.contains("face") {
            cameraMovement = "slow dramatic zoom into a close-up"
            lighting = "dramatic rim lighting"
        }

        if lowerPrompt.contains("dark") || lowerPrompt.contains("night") || lowerPrompt.contains("shadow") {
            mood = "mysterious and moody"
            lighting = "low-key lighting with deep shadows"
        } else if lowerPrompt.contains("bright") || lowerPrompt.contains("sun") || lowerPrompt.contains("happy") {
            mood = "uplifting and bright"
            lighting = "high-key warm golden hour lighting"
        }

        let improved = "Subject: \(subject). Action: \(action). Environment: \(environment). Camera: \(cameraMovement). Lighting: \(lighting). Mood: \(mood). Audio: \(audioCues)."

        let changes = [
            "Subject": subject,
            "Action": action,
            "Environment": environment,
            "Camera": cameraMovement,
            "Lighting": lighting,
            "Mood": mood,
            "Audio": audioCues
        ]

        return ImprovedPrompt(original: prompt, improved: improved, changes: changes)
    }

    private func extractSubject(from prompt: String) -> String {
        // Very basic subject extraction: usually the first few words or until a verb
        let components = prompt.components(separatedBy: .whitespaces)
        if components.count >= 2 {
            return components.prefix(2).joined(separator: " ")
        }
        return prompt
    }

    private func extractAction(from prompt: String) -> String {
        // Very basic action extraction: everything after the subject
        let components = prompt.components(separatedBy: .whitespaces)
        if components.count > 2 {
            return components.dropFirst(2).joined(separator: " ")
        }
        return "exists in the scene"
    }
}
