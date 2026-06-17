import Foundation
import OSLog

public enum GenerationProfile: String, Codable {
    case limited = "Limited"
    case minimum = "Minimum"
    case recommended = "Recommended"
    case highQuality = "High Quality"
    case unknown = "Unknown"

    public var description: String {
        switch self {
        case .limited: return "Limited / small quantized clips only"
        case .minimum: return "Minimum realistic local generation"
        case .recommended: return "Good local creator experience"
        case .highQuality: return "High-quality local workflows"
        case .unknown: return "Unknown performance profile"
        }
    }
}

public struct HardwareProfile: Codable, Equatable {
    public let modelName: String
    public let isAppleSilicon: Bool
    public let totalMemoryGB: Int
    public let generationProfile: GenerationProfile
    public let isLocalModeReady: Bool

    public static var unknown: HardwareProfile {
        HardwareProfile(
            modelName: "Unknown Mac",
            isAppleSilicon: false,
            totalMemoryGB: 0,
            generationProfile: .unknown,
            isLocalModeReady: false
        )
    }
}

public protocol HardwareProfilerProtocol {
    func getHardwareProfile() async -> HardwareProfile
}

public final class HardwareProfiler: HardwareProfilerProtocol {
    private let logger = Logger(subsystem: "com.ai-studio-local.app", category: "Hardware")
    public init() {}

    public func getHardwareProfile() async -> HardwareProfile {
        NSLog("💻 HardwareProfiler: Getting hardware profile...")
        // Run on background thread to avoid blocking UI
        let result = await Task.detached(priority: .userInitiated) {
            NSLog("💻 HardwareProfiler: Background task started")
            let modelName = self.getDeviceModelName()
            NSLog("💻 HardwareProfiler: Model name: \(modelName)")
            let isAppleSilicon = self.checkAppleSilicon()
            NSLog("💻 HardwareProfiler: Apple Silicon: \(isAppleSilicon)")
            let memoryGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
            NSLog("💻 HardwareProfiler: Memory: \(memoryGB)GB")

            let profile: GenerationProfile
            if memoryGB >= 96 {
                profile = .highQuality
            } else if memoryGB >= 64 {
                profile = .recommended
            } else if memoryGB >= 32 {
                profile = .minimum
            } else if memoryGB >= 16 {
                profile = .limited
            } else {
                profile = .unknown
            }

            // Local mode is ready if it's Apple Silicon and has at least 16GB RAM
            let isReady = isAppleSilicon && memoryGB >= 16

            NSLog("💻 HardwareProfiler: Background task completed")
            return HardwareProfile(
                modelName: modelName,
                isAppleSilicon: isAppleSilicon,
                totalMemoryGB: memoryGB,
                generationProfile: profile,
                isLocalModeReady: isReady
            )
        }.value
        NSLog("💻 HardwareProfiler: Hardware profile obtained")
        return result
    }

    private func getDeviceModelName() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
    }

    private func checkAppleSilicon() -> Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }
}
