import Foundation

/// Protocol defining the interface for speech-to-text transcription functionality.
/// Implementations handle loading ML models and converting audio to text.
public protocol Transcriber {
    /// Information about the currently loaded model.
    var modelInfo: ModelInfo { get }
    
    /// Languages supported by the current model.
    var supportedLanguages: [Language] { get }
    
    /// Whether a model is currently loaded and ready for transcription.
    var isModelLoaded: Bool { get }
    
    /// Transcribes audio data to text using the loaded ML model.
    /// - Parameters:
    ///   - audio: The audio data to transcribe (should be 16kHz mono PCM)
    ///   - language: Optional language hint for better accuracy. If nil, auto-detects.
    /// - Returns: TranscriptionResult containing the transcribed text and metadata
    /// - Throws: TranscriptionError if model is not loaded or transcription fails
    func transcribe(_ audio: AudioData, language: Language?) async throws -> TranscriptionResult
    
    /// Loads a specific model type for transcription.
    /// - Parameter type: The model type to load (fast, balanced, or accurate)
    /// - Throws: ModelError if model file is not found or loading fails
    /// - Note: Loading a new model will unload any previously loaded model
    func loadModel(_ type: ModelType) async throws
}

/// Errors that can occur during transcription
public enum TranscriberError: LocalizedError {
    case modelNotLoaded
    case invalidAudioData
    case transcriptionFailed(reason: String)
    case unsupportedLanguage(Language)
    case modelLoadingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model is loaded. Please load a model before transcribing."
        case .invalidAudioData:
            return "Invalid audio data provided. Ensure audio is 16kHz mono PCM format."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .unsupportedLanguage(let language):
            return "Language '\(language.displayName)' is not supported by the current model."
        case .modelLoadingFailed(let error):
            return "Failed to load model: \(error)"
        }
    }
}