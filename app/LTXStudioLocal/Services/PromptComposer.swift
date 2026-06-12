import Foundation

public struct ComposedPrompt: Equatable {
    public let prompt: String
    public let negativePrompt: String
    public let metadata: [String: String]

    public init(prompt: String, negativePrompt: String, metadata: [String: String]) {
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.metadata = metadata
    }
}

public protocol PromptComposer {
    func compose(scene: Scene, elements: [ContinuityElement]) -> ComposedPrompt
}

public final class DefaultPromptComposer: PromptComposer {
    public init() {}

    public func compose(scene: Scene, elements: [ContinuityElement]) -> ComposedPrompt {
        var promptParts: [String] = []
        var negativePromptParts: [String] = []
        var metadata: [String: String] = [:]

        // 1. Scene Prompt
        if !scene.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptParts.append(scene.prompt)
        }

        if let sceneNegative = scene.negativePrompt, !sceneNegative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            negativePromptParts.append(sceneNegative)
        }

        // 2. Elements by type (Order: character, location, style, camera, audio, brand, promptBlock, lora)
        let elementOrder: [ContinuityElementType] = [
            .character, .location, .style, .camera, .audio, .brand, .promptBlock, .lora
        ]

        for type in elementOrder {
            let typeElements = elements.filter { $0.type == type }
            for element in typeElements {
                if !element.promptBlock.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    promptParts.append(element.promptBlock)
                    metadata[element.id] = element.name
                }

                if let elementNegative = element.negativePrompt, !elementNegative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    negativePromptParts.append(elementNegative)
                }
            }
        }

        // 3. Consistency Locks (Adding instructions for locks if they are enabled)
        // Note: For now we just add them to metadata. In a real engine, these might affect the prompt or parameters.
        if scene.consistencyLocks.character { metadata["lock_character"] = "true" }
        if scene.consistencyLocks.clothing { metadata["lock_clothing"] = "true" }
        if scene.consistencyLocks.location { metadata["lock_location"] = "true" }
        if scene.consistencyLocks.style { metadata["lock_style"] = "true" }
        if scene.consistencyLocks.brand { metadata["lock_brand"] = "true" }
        if scene.consistencyLocks.audio { metadata["lock_audio"] = "true" }
        if scene.consistencyLocks.seed { metadata["lock_seed"] = "true" }
        if scene.consistencyLocks.camera { metadata["lock_camera"] = "true" }

        let finalPrompt = promptParts.joined(separator: ", ")
        let finalNegativePrompt = negativePromptParts.joined(separator: ", ")

        return ComposedPrompt(
            prompt: finalPrompt,
            negativePrompt: finalNegativePrompt,
            metadata: metadata
        )
    }
}
