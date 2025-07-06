import Foundation
import VoiceTypeCore

/// Factory for creating Transcriber instances
public struct TranscriberFactory {
    
    /// Available transcriber types
    public enum TranscriberType {
        case coreMLWhisper(model: WhisperModel, modelPath: String)
        case mock(behavior: MockTranscriber.MockBehavior)
    }
    
    /// Create a transcriber instance
    /// - Parameter type: The type of transcriber to create
    /// - Returns: A configured transcriber instance
    public static func create(type: TranscriberType) -> Transcriber {
        switch type {
        case .coreMLWhisper(let model, let modelPath):
            return CoreMLWhisper(modelType: model, modelPath: modelPath)
            
        case .mock(let behavior):
            return MockTranscriber(behavior: behavior)
        }
    }
    
    /// Create a CoreML Whisper transcriber with automatic model path resolution
    /// - Parameters:
    ///   - model: The Whisper model size to use
    ///   - modelDirectory: Directory containing the model files (optional)
    /// - Returns: A configured CoreMLWhisper instance
    public static func createCoreMLWhisper(
        model: WhisperModel,
        modelDirectory: String? = nil
    ) -> CoreMLWhisper {
        let modelPath: String
        
        if let directory = modelDirectory {
            modelPath = "\(directory)/\(model.fileName).mlmodelc"
        } else {
            // Default to bundle resources
            if let bundlePath = Bundle.main.path(forResource: model.fileName, ofType: "mlmodelc") {
                modelPath = bundlePath
            } else {
                // Fallback to Documents directory
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
                modelPath = "\(documentsPath)/Models/\(model.fileName).mlmodelc"
            }
        }
        
        return CoreMLWhisper(modelType: model, modelPath: modelPath)
    }
    
    /// Create a mock transcriber for testing
    /// - Parameter scenario: Pre-defined mock scenario
    /// - Returns: A configured MockTranscriber instance
    public static func createMock(scenario: MockTranscriber.MockBehavior = MockTranscriber.Scenarios.success) -> MockTranscriber {
        return MockTranscriber(behavior: scenario)
    }
    
    /// Get the default transcriber for the application
    /// - Returns: The default transcriber instance
    public static func createDefault() -> Transcriber {
        #if DEBUG
        // Use mock transcriber in debug builds for easier testing
        return createMock()
        #else
        // Use the smallest model by default for better performance
        return createCoreMLWhisper(model: .tiny)
        #endif
    }
}