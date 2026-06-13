import Foundation

import AVFoundation
import AppKit

public protocol ExportService {
    func exportProject(_ project: Project, scenes: [Scene], preset: ExportPreset, projectURL: URL) async throws -> ExportMetadata
}

public enum ExportError: Error, LocalizedError {
    case emptyTimeline
    case projectFolderMissing
    case missingClip(sceneId: String, clipIndex: Int)
    case sceneNotFound(sceneId: String)
    case generationNotFound(sceneId: String)
    case videoFileMissing(path: String)
    case fileSystemError(Error)
    case renderingError(String)

    public var errorDescription: String? {
        asAppError.message
    }

    public var asAppError: AppError {
        switch self {
        case .emptyTimeline:
            return AppError(
                title: "Empty Timeline",
                message: "Cannot export an empty timeline. Please add clips first.",
                suggestedActions: ["Add scenes to the timeline"]
            )
        case .projectFolderMissing:
            return AppError.projectLoadFailed(error: self)
        case .missingClip(let sceneId, let index):
            return AppError(
                title: "Missing Clip",
                message: "Clip \(index + 1) refers to a missing or invalid scene: \(sceneId)",
                suggestedActions: ["Remove and re-add the scene to the timeline"]
            )
        case .sceneNotFound(let sceneId):
            return AppError(
                title: "Scene Not Found",
                message: "Scene not found: \(sceneId)",
                suggestedActions: ["Verify the project structure"]
            )
        case .generationNotFound(let sceneId):
            return AppError(
                title: "No Generation Found",
                message: "No generation found for scene: \(sceneId)",
                suggestedActions: ["Generate a video for this scene before exporting"]
            )
        case .videoFileMissing(let path):
            return AppError.missingMediaFile(path: path)
        case .fileSystemError(let error):
            return AppError.exportFailed(error: error)
        case .renderingError(let message):
            return AppError.exportFailed(error: NSError(domain: "Export", code: -1, userInfo: [NSLocalizedDescriptionKey: message]))
        }
    }
}

public final class AVFoundationExportService: ExportService {
    private let fileManager: FileManager
    private let jsonEncoder: JSONEncoder
    private let continuityStore: ContinuityStore

    public init(fileManager: FileManager = .default, continuityStore: ContinuityStore = FileContinuityStore()) {
        self.fileManager = fileManager
        self.continuityStore = continuityStore
        self.jsonEncoder = JSONEncoder()
        self.jsonEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.jsonEncoder.dateEncodingStrategy = .iso8601
    }

    public func exportProject(_ project: Project, scenes: [Scene], preset: ExportPreset, projectURL: URL) async throws -> ExportMetadata {
        guard !project.timeline.clips.isEmpty else {
            throw ExportError.emptyTimeline
        }

        guard fileManager.fileExists(atPath: projectURL.path) else {
            throw ExportError.projectFolderMissing
        }

        let exportsURL = projectURL.appendingPathComponent("exports")
        if !fileManager.fileExists(atPath: exportsURL.path) {
            try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
        }

        let exportId = UUID().uuidString
        let fileName = "export-\(exportId.prefix(8)).mp4"
        let outputURL = exportsURL.appendingPathComponent(fileName)

        // Find Brand Kit if any
        let brandKit = try loadBrandKit(for: project)

        // Actual AVFoundation Rendering
        try await renderVideo(project: project, scenes: scenes, preset: preset, brandKit: brandKit, outputURL: outputURL, projectURL: projectURL)

        // Prepare metadata
        let clipMetadata = project.timeline.clips.compactMap { clip -> ExportClipMetadata? in
            guard let scene = scenes.first(where: { $0.id == clip.sceneId }) else { return nil }
            return ExportClipMetadata(
                sceneId: scene.id,
                sceneName: scene.name,
                generationId: scene.generations.first?.id,
                duration: clip.duration
            )
        }

        let metadata = ExportMetadata(
            id: exportId,
            projectId: project.id,
            projectName: project.name,
            preset: preset,
            clips: clipMetadata,
            brandKit: brandKit,
            outputPath: "exports/\(fileName)"
        )

        let metadataURL = exportsURL.appendingPathComponent("metadata-\(exportId.prefix(8)).json")
        let data = try jsonEncoder.encode(metadata)
        try data.write(to: metadataURL)

        return metadata
    }

    private func loadBrandKit(for project: Project) throws -> BrandKit? {
        guard let brandKitId = project.defaultBrandKitId else { return nil }
        let elements = try continuityStore.loadAll()
        if let element = elements.first(where: { $0.id == brandKitId && $0.type == .brand }) {
            return BrandKit(element: element)
        }
        return nil
    }

    private func renderVideo(project: Project, scenes: [Scene], preset: ExportPreset, brandKit: BrandKit?, outputURL: URL, projectURL: URL) async throws {
        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError.renderingError("Could not create video track")
        }

        var currentTime = CMTime.zero
        let renderSize = CGSize(width: preset.width, height: preset.height)
        var sceneTimeRanges: [(scene: Scene, timeRange: CMTimeRange)] = []

        // 1. Validate all clips and files exist first
        var validatedAssets: [(URL, CMTime)] = []
        for (index, clip) in project.timeline.clips.enumerated() {
            guard let scene = scenes.first(where: { $0.id == clip.sceneId }) else {
                throw ExportError.missingClip(sceneId: clip.sceneId, clipIndex: index)
            }
            guard let generation = scene.generations.first else {
                throw ExportError.generationNotFound(sceneId: scene.id)
            }
            guard let relativePath = generation.outputPath else {
                throw ExportError.generationNotFound(sceneId: scene.id)
            }

            let assetURL = projectURL.appendingPathComponent(relativePath)
            guard fileManager.fileExists(atPath: assetURL.path) else {
                throw ExportError.videoFileMissing(path: relativePath)
            }
            let duration = CMTime(seconds: clip.duration, preferredTimescale: 600)
            validatedAssets.append((assetURL, duration))
        }

        // 2. Concatenate clips
        for (index, (assetURL, duration)) in validatedAssets.enumerated() {
            let clip = project.timeline.clips[index]
            let scene = scenes.first(where: { $0.id == clip.sceneId })!
            let asset = AVAsset(url: assetURL)

            do {
                let assetVideoTracks = try await asset.loadTracks(withMediaType: .video)
                guard let assetVideoTrack = assetVideoTracks.first else {
                    throw ExportError.renderingError("No video track found in \(assetURL.lastPathComponent)")
                }

                let timeRange = CMTimeRange(start: .zero, duration: duration)
                try videoTrack.insertTimeRange(timeRange, of: assetVideoTrack, at: currentTime)
                sceneTimeRanges.append((scene: scene, timeRange: CMTimeRange(start: currentTime, duration: duration)))
                currentTime = CMTimeAdd(currentTime, duration)
            } catch {
                throw ExportError.renderingError("Could not load track for scene \(scene.id): \(error.localizedDescription)")
            }
        }

        // Apply Overlays
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: currentTime)

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        if let brandKit = brandKit {
            try setupOverlays(for: videoComposition, size: renderSize, brandKit: brandKit, totalDuration: currentTime, sceneTimeRanges: sceneTimeRanges)
        }

        // Export
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.renderingError("Could not create export session")
        }

        exportSession.videoComposition = videoComposition
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        await exportSession.export()

        if let error = exportSession.error {
            throw ExportError.renderingError(error.localizedDescription)
        }
    }

    private func setupOverlays(for videoComposition: AVMutableVideoComposition, size: CGSize, brandKit: BrandKit, totalDuration: CMTime, sceneTimeRanges: [(scene: Scene, timeRange: CMTimeRange)]) throws {
        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: size)

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: size)

        let overlayLayer = CALayer()
        overlayLayer.frame = CGRect(origin: .zero, size: size)

        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(overlayLayer)

        // 1. Watermark
        if brandKit.watermarkSettings.isEnabled, let logoPath = brandKit.logoAssetPath {
            let logoURL = URL(fileURLWithPath: logoPath)
            if let image = NSImage(contentsOf: logoURL) {
                let watermarkLayer = CALayer()
                let logoScale = brandKit.watermarkSettings.scale
                let logoSize = CGSize(width: size.width * 0.15 * logoScale,
                                     height: size.width * 0.15 * logoScale * (image.size.height / image.size.width))

                watermarkLayer.frame = calculatePosition(brandKit.watermarkSettings.position, elementSize: logoSize, parentSize: size)
                watermarkLayer.contents = image.layerContents(forContentsScale: 2.0)
                watermarkLayer.opacity = Float(brandKit.watermarkSettings.opacity)
                overlayLayer.addSublayer(watermarkLayer)
            }
        }

        // 2. Title Card (Intro)
        if brandKit.titleCardSettings.isEnabled && !brandKit.introCardText.isEmpty {
            let titleLayer = CATextLayer()
            titleLayer.string = brandKit.introCardText
            titleLayer.font = NSFont(name: brandKit.titleCardSettings.fontName, size: CGFloat(brandKit.titleCardSettings.fontSize))
            titleLayer.fontSize = CGFloat(brandKit.titleCardSettings.fontSize)
            titleLayer.alignmentMode = .center
            titleLayer.foregroundColor = NSColor(hex: brandKit.titleCardSettings.color)?.cgColor ?? NSColor.white.cgColor
            titleLayer.frame = CGRect(x: 0, y: size.height/2 - 50, width: size.width, height: 100)
            titleLayer.opacity = 0 // Start hidden

            // Animation: show for first 3 seconds
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            animation.values = [1.0, 1.0, 0.0]
            animation.keyTimes = [0.0, 0.8, 1.0] // Stay visible for most of the duration
            animation.duration = 3.5
            animation.beginTime = AVCoreAnimationBeginTimeAtZero
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            titleLayer.add(animation, forKey: "introFade")

            overlayLayer.addSublayer(titleLayer)
        }

        // 3. Outro Card
        if !brandKit.outroCardText.isEmpty {
            let outroLayer = CATextLayer()
            outroLayer.string = brandKit.outroCardText
            outroLayer.font = NSFont(name: brandKit.titleCardSettings.fontName, size: CGFloat(brandKit.titleCardSettings.fontSize))
            outroLayer.fontSize = CGFloat(brandKit.titleCardSettings.fontSize)
            outroLayer.alignmentMode = .center
            outroLayer.foregroundColor = NSColor(hex: brandKit.titleCardSettings.color)?.cgColor ?? NSColor.white.cgColor
            outroLayer.frame = CGRect(x: 0, y: size.height/2 - 50, width: size.width, height: 100)
            outroLayer.opacity = 0

            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 0.0
            animation.toValue = 1.0
            animation.duration = 0.5
            animation.beginTime = totalDuration.seconds - 3.0
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            outroLayer.add(animation, forKey: "outroFadeIn")

            overlayLayer.addSublayer(outroLayer)
        }

        // 4. Lower Thirds (Scene Names)
        if brandKit.lowerThirdSettings.isEnabled {
            for (scene, timeRange) in sceneTimeRanges {
                let lowerThirdLayer = CATextLayer()
                lowerThirdLayer.string = scene.name
                lowerThirdLayer.font = NSFont(name: brandKit.lowerThirdSettings.fontName, size: CGFloat(brandKit.lowerThirdSettings.fontSize))
                lowerThirdLayer.fontSize = CGFloat(brandKit.lowerThirdSettings.fontSize)
                lowerThirdLayer.alignmentMode = .left
                lowerThirdLayer.foregroundColor = NSColor(hex: brandKit.lowerThirdSettings.color)?.cgColor ?? NSColor.white.cgColor
                lowerThirdLayer.opacity = 0

                let textHeight = CGFloat(brandKit.lowerThirdSettings.fontSize) * 1.2
                let textWidth = size.width * 0.4
                lowerThirdLayer.frame = calculatePosition(brandKit.lowerThirdSettings.position, elementSize: CGSize(width: textWidth, height: textHeight), parentSize: size)

                // Simple background for lower third
                if let bgColorStr = brandKit.lowerThirdSettings.backgroundColor, let bgColor = NSColor(hex: bgColorStr) {
                    lowerThirdLayer.backgroundColor = bgColor.cgColor
                }

                let animation = CAKeyframeAnimation(keyPath: "opacity")
                animation.values = [0.0, 1.0, 1.0, 0.0]
                animation.keyTimes = [0.0, 0.1, 0.9, 1.0]
                animation.duration = timeRange.duration.seconds
                animation.beginTime = timeRange.start.seconds
                animation.fillMode = .forwards
                animation.isRemovedOnCompletion = false
                lowerThirdLayer.add(animation, forKey: "lowerThirdFade")

                overlayLayer.addSublayer(lowerThirdLayer)
            }
        }

        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
    }

    internal func calculatePosition(_ position: OverlayPosition, elementSize: CGSize, parentSize: CGSize) -> CGRect {
        let margin: CGFloat = 40
        switch position {
        case .topLeft:
            return CGRect(x: margin, y: parentSize.height - elementSize.height - margin, width: elementSize.width, height: elementSize.height)
        case .topRight:
            return CGRect(x: parentSize.width - elementSize.width - margin, y: parentSize.height - elementSize.height - margin, width: elementSize.width, height: elementSize.height)
        case .bottomLeft:
            return CGRect(x: margin, y: margin, width: elementSize.width, height: elementSize.height)
        case .bottomRight:
            return CGRect(x: parentSize.width - elementSize.width - margin, y: margin, width: elementSize.width, height: elementSize.height)
        case .center:
            return CGRect(x: (parentSize.width - elementSize.width)/2, y: (parentSize.height - elementSize.height)/2, width: elementSize.width, height: elementSize.height)
        case .topCenter:
            return CGRect(x: (parentSize.width - elementSize.width)/2, y: parentSize.height - elementSize.height - margin, width: elementSize.width, height: elementSize.height)
        case .bottomCenter:
            return CGRect(x: (parentSize.width - elementSize.width)/2, y: margin, width: elementSize.width, height: elementSize.height)
        }
    }
}

// Helpers for NSImage and NSColor
extension NSImage {
    func layerContents(forContentsScale scale: CGFloat) -> Any? {
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b, a: CGFloat
        if hexSanitized.count == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if hexSanitized.count == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

public final class MockExportService: ExportService {
    // ... preserved for compatibility if needed, but we will switch to AVFoundationExportService
    public func exportProject(_ project: Project, scenes: [Scene], preset: ExportPreset, projectURL: URL) async throws -> ExportMetadata {
        let realService = AVFoundationExportService()
        return try await realService.exportProject(project, scenes: scenes, preset: preset, projectURL: projectURL)
    }
}
