import Foundation

public struct ComposedPrompt: Equatable {
    public let prompt: String
    public let negativePrompt: String
    public let sourceElementIds: [String]
    public let referenceImagePaths: [String]
    public let loras: [LoRAConfig]
    public let warnings: [String]
    public let metadata: [String: String]

    public init(
        prompt: String,
        negativePrompt: String,
        sourceElementIds: [String] = [],
        referenceImagePaths: [String] = [],
        loras: [LoRAConfig] = [],
        warnings: [String] = [],
        metadata: [String: String] = [:]
    ) {
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.sourceElementIds = sourceElementIds
        self.referenceImagePaths = referenceImagePaths
        self.loras = loras
        self.warnings = warnings
        self.metadata = metadata
    }
}

public protocol PromptComposer {
    func compose(scene: Scene, elements: [ContinuityElement]) -> ComposedPrompt
}

public final class DefaultPromptComposer: PromptComposer {
    private let typeOrder: [ContinuityElementType] = [
        .character,
        .lora,
        .style,
        .location,
        .camera,
        .brand,
        .promptBlock,
        .audio,
        .voiceClone
    ]

    public init() {}

    public func compose(scene: Scene, elements: [ContinuityElement]) -> ComposedPrompt {
        var positiveParts: [String] = []
        var negativeParts: [String] = []
        var sourceElementIds: [String] = []
        var referenceImagePaths: [String] = []
        var loras: [LoRAConfig] = []
        var warnings: [String] = []
        var metadata: [String: String] = [:]

        // 1. Elements by type (Core Definition)
        // Required Ordering for Stability:
        // - Character identity text must be included before style text.
        // - Location text must be included before camera text.
        // - Audio cues must be included near the end.
        NSLog("🎨 DefaultPromptComposer: Starting composition for scene \(scene.id) with \(elements.count) elements")
        for type in typeOrder {
            // Sort by name for determinism if multiple elements of same type
            let typeElements = elements.filter { $0.type == type }.sorted(by: { $0.id < $1.id })

            for element in typeElements {
                NSLog("🎨 DefaultPromptComposer: Resolving element \(element.name) (\(element.id)) of type \(element.type.rawValue)")
                sourceElementIds.append(element.id)
                metadata[element.id] = element.name

                if type == .voiceClone, let refPath = element.voiceCloneReferencePath {
                    metadata["voice_clone_reference_path"] = refPath
                }

                // Collect reference images from assets
                for asset in element.assets {
                    if asset.type.lowercased() == "image" || asset.type.lowercased() == "png" || asset.type.lowercased() == "jpg" || asset.type.lowercased() == "jpeg" {
                        if !referenceImagePaths.contains(asset.path) {
                            referenceImagePaths.append(asset.path)
                        }
                    }
                }

                // Add LoRA if available
                if let loraPath = element.trainedLoraPath {
                    NSLog("🎨 DefaultPromptComposer: Found explicit trainedLoraPath for element \(element.name): \(loraPath)")
                    metadata["lora_\(element.id)"] = loraPath
                    if !loras.contains(where: { $0.path == loraPath }) {
                        loras.append(LoRAConfig(path: loraPath, scale: 1.0))
                    }

                    // The LoRA is only trained to associate its weights with this exact
                    // token (training captions are just the trigger word by itself -- see
                    // ContinuityElement.triggerWord). Merging the LoRA into the model isn't
                    // enough on its own: without this token in the prompt's text
                    // conditioning, there's nothing to invoke the trained identity, so
                    // generations come out looking like the untrained base model. Prepend
                    // it so it lands early in the composed prompt.
                    if let triggerWord = element.triggerWord, !triggerWord.isEmpty {
                        NSLog("🎨 DefaultPromptComposer: Injecting trigger word for \(element.name): \(triggerWord)")
                        positiveParts.append(triggerWord)
                    } else {
                        NSLog("🎨 DefaultPromptComposer: WARNING: \(element.name) has a trained LoRA but no stored triggerWord -- the LoRA may not visibly affect generation.")
                    }
                } else {
                    NSLog("🎨 DefaultPromptComposer: No explicit trainedLoraPath for element \(element.name), checking assets...")
                    // Search assets for ANY element type (e.g. character, style) if it has a .safetensors file
                    for asset in element.assets {
                        if asset.path.hasSuffix(".safetensors") {
                             NSLog("🎨 DefaultPromptComposer: Found LoRA safetensors in assets for \(element.name) (\(element.type.rawValue)): \(asset.path)")
                             if !loras.contains(where: { $0.path == asset.path }) {
                                 loras.append(LoRAConfig(path: asset.path, scale: 1.0))
                             }
                        }
                    }
                }

                let prompt = element.promptBlock.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if !prompt.isEmpty {
                    positiveParts.append(prompt)
                }

                if let negative = element.negativePrompt {
                    let trimmed = negative.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        negativeParts.append(trimmed)
                    }
                }
            }
        }

        // Add instructions to use reference images if they exist
        if !referenceImagePaths.isEmpty {
            positiveParts.insert("follow the visual style and identity from the reference images strictly", at: 0)
        }

        // 2. Scene Prompt (As modifier/context)
        let scenePrompt = scene.prompt.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !scenePrompt.isEmpty {
            positiveParts.append(scenePrompt)
        }

        if let sceneNegative = scene.negativePrompt {
            let trimmed = sceneNegative.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !trimmed.isEmpty {
                negativeParts.append(trimmed)
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
            referenceImagePaths: referenceImagePaths,
            loras: loras,
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
