import Foundation

public struct ResolvedSceneElement: Identifiable, Equatable {
    public var id: String { reference.elementId }
    public let reference: AttachedContinuityElement
    public let element: ContinuityElement?
    public let isMissing: Bool

    public init(reference: AttachedContinuityElement, element: ContinuityElement?) {
        self.reference = reference
        self.element = element
        self.isMissing = element == nil
    }
}

public protocol SceneResolver {
    func resolve(scene: Scene) throws -> [ResolvedSceneElement]
}

public final class DefaultSceneResolver: SceneResolver {
    private let continuityStore: ContinuityStore

    public init(continuityStore: ContinuityStore = FileContinuityStore()) {
        self.continuityStore = continuityStore
    }

    public func resolve(scene: Scene) throws -> [ResolvedSceneElement] {
        let allElements = try continuityStore.loadAll()
        let elementMap = Dictionary(uniqueKeysWithValues: allElements.map { ($0.id, $0) })

        return scene.attachedContinuityElements.map { reference in
            let element = elementMap[reference.elementId]
            return ResolvedSceneElement(reference: reference, element: element)
        }
    }
}
