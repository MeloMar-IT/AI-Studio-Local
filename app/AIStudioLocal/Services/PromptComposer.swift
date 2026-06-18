import Foundation

public struct ComposedPrompt: Equatable {
    public let prompt: String
    public let negativePrompt: String
    public let sourceElementIds: [String]
    public let warnings: [String]
    public let metadata: [String: String]

    public init(
        prompt: String,
        negativePrompt: String,
        sourceElementIds: [String] = [],
        warnings: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.sourceElementIds = sourceElementIds
        self.warnings = warnings
        self.metadata = metadata
    }
}

public protocol PromptComposer {
    func compose(scene: Scene, elements: [ContinuityElement]) -> ComposedPrompt
}

public final class DefaultPromptComposer: PromptComposer {
    public init() {}

    public func compose(scene: Scene, elements: [ContinuityElement]) -> ComposedPrompt {
        var positiveParts: [String] = []
        var negativeParts: [String] = []
        var sourceElementIds: [String] = []
        var warnings: [String] = []
        var metadata: [String: String] = [:]

        // 1. Scene Prompt (Must come first)
        let scenePrompt = scene.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !scenePrompt.isEmpty {
            positiveParts.append(scenePrompt)
        }

        if let sceneNegative = scene.negativePrompt {
            let trimmed = sceneNegative.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                negativeParts.append(trimmed)
            }
        }

        // 2. Elements by type
        // Required Ordering:
        // - Character identity text must be included before style text.
        // - Location text must be included before camera text.
        // - Audio cues must be included near the end.
        let typeOrder: [ContinuityElementType] = [
            .character,
            .style,
            .location,
            .camera,
            .brand,
            .promptBlock,
            .lora,
            .audio // Audio near the end
        ]

        for type in typeOrder {
            // Sort by name for determinism if multiple elements of same type
            let typeElements = elements.filter { $0.type == type }.sorted(by: { $0.id < $1.id })

            for element in typeElements {
                sourceElementIds.append(element.id)
                metadata[element.id] = element.name

                let prompt = element.promptBlock.trimmingCharacters(in: .whitespacesAndNewlines)
                if !prompt.isEmpty {
                    positiveParts.append(prompt)
                }

                if let negative = element.negativePrompt {
                    let trimmed = negative.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        negativeParts.append(trimmed)
                    }
                }
            }
        }

        // Check for missing elements (attached to scene but not provided in elements array)
        let attachedIds = Set(scene.attachedContinuityElements.map { $0.elementId })
        let providedIds = Set(elements.map { $0.id })
        let missingIds = attachedIds.subtracting(providedIds)

        for missingId in missingIds {
            if let attached = scene.attachedContinuityElements.first(where: { $0.elementId == missingId }) {
                warnings.append("Missing element: \(attached.type.rawValue) (\(missingId))")
            } else {
                warnings.append("Missing element: \(missingId)")
            }
        }

        // 3. Consistency Locks
        if scene.consistencyLocks.characterIdentity { metadata["lock_character"] = "true" }
        if scene.consistencyLocks.clothing { metadata["lock_clothing"] = "true" }
        if scene.consistencyLocks.location { metadata["lock_location"] = "true" }
        if scene.consistencyLocks.style { metadata["lock_style"] = "true" }
        if scene.consistencyLocks.brand { metadata["lock_brand"] = "true" }
        if scene.consistencyLocks.audioIdentity { metadata["lock_audio"] = "true" }
        if scene.consistencyLocks.seed { metadata["lock_seed"] = "true" }
        if scene.consistencyLocks.camera { metadata["lock_camera"] = "true" }

        // Deduplicate parts while preserving order
        let finalPositive = deduplicateParts(positiveParts).joined(separator: ", ")
        let finalNegative = deduplicateParts(negativeParts).joined(separator: ", ")

        return ComposedPrompt(
            prompt: finalPositive,
            negativePrompt: finalNegative,
            sourceElementIds: sourceElementIds,
            warnings: warnings,
            metadata: metadata
        )
    }

    private func deduplicateParts(_ parts: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for part in parts {
            if !seen.contains(part) {
                seen.insert(part)
                result.append(part)
            }
        }
        return result
    }
}
