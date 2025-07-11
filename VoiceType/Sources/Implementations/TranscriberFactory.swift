import Foundation
import VoiceTypeCore

/// Factory for creating Transcriber instances
public struct TranscriberFactory {
    /// Available transcriber types
    public enum TranscriberType {
        case whisperKit
        case coreMLWhisper(modelName: String, modelPath: String)
        case mock(behavior: MockTranscriber.MockBehavior)
    }

    /// Configuration for transcriber creation
    public struct Configuration {
        /// Whether to use mock transcriber for testing
        public var useMockForTesting: Bool = false

        /// Whether to enable WhisperKit (set to false to fallback to CoreML)
        public var useWhisperKit: Bool = true

        public init() {}
    }

    /// Thread-safe configuration storage using NSLock
    private static let configurationLock = NSLock()
    private static var _configuration = Configuration()

    private static var configuration: Configuration {
        get {
            configurationLock.lock()
            defer { configurationLock.unlock() }
            return _configuration
        }
        set {
            configurationLock.lock()
            defer { configurationLock.unlock() }
            _configuration = newValue
        }
    }

    /// Configure the factory behavior
    public static func configure(_ config: Configuration) {
        configuration = config
    }

    /// Create a transcriber instance
    /// - Parameter type: The type of transcriber to create
    /// - Returns: A configured transcriber instance
    public static func create(type: TranscriberType) -> Transcriber {
        switch type {
        case .whisperKit:
            return WhisperKitTranscriber()

        case .coreMLWhisper(let modelName, let modelPath):
            return CoreMLWhisper(modelName: modelName, modelPath: modelPath)

        case .mock(let behavior):
            return MockTranscriber(behavior: behavior)
        }
    }

    /// Create a WhisperKit transcriber
    /// - Returns: A configured WhisperKitTranscriber instance
    public static func createWhisperKit() -> WhisperKitTranscriber {
        WhisperKitTranscriber()
    }

    /// Create a CoreML Whisper transcriber with automatic model path resolution
    /// - Parameters:
    ///   - modelName: The model name to use
    ///   - modelDirectory: Directory containing the model files (optional)
    /// - Returns: A configured CoreMLWhisper instance
    public static func createCoreMLWhisper(
        modelName: String,
        modelDirectory: String? = nil
    ) -> CoreMLWhisper {
        let modelPath: String

        if let directory = modelDirectory {
            modelPath = "\(directory)/\(modelName).mlmodelc"
        } else {
            // Default to bundle resources
            if let bundlePath = Bundle.main.path(forResource: modelName, ofType: "mlmodelc") {
                modelPath = bundlePath
            } else {
                // Fallback to Documents directory
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
                modelPath = "\(documentsPath)/Models/\(modelName).mlmodelc"
            }
        }

        return CoreMLWhisper(modelName: modelName, modelPath: modelPath)
    }

    /// Create a mock transcriber for testing
    /// - Parameter scenario: Pre-defined mock scenario
    /// - Returns: A configured MockTranscriber instance
    public static func createMock(scenario: MockTranscriber.MockBehavior = MockTranscriber.Scenarios.success) -> MockTranscriber {
        MockTranscriber(behavior: scenario)
    }

    /// Get the default transcriber for the application
    /// - Returns: The default transcriber instance
    public static func createDefault() -> Transcriber {
        // Check if we should use mock for testing
        if configuration.useMockForTesting {
            return createMock()
        }

        #if DEBUG
        // In debug builds, check configuration
        if !configuration.useWhisperKit {
            // Fallback to CoreML implementation
            return createCoreMLWhisper(modelName: "whisper-tiny")
        }
        #endif

        // Use WhisperKit as the default
        if configuration.useWhisperKit {
            return createWhisperKit()
        } else {
            // Fallback to CoreML implementation
            return createCoreMLWhisper(modelName: "whisper-tiny")
        }
    }
}
