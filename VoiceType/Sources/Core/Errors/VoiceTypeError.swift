import Foundation

/// Comprehensive error types for VoiceType operations.
public enum VoiceTypeError: LocalizedError {
    // MARK: - Audio Errors
    
    /// Microphone permission was denied by the user.
    case microphonePermissionDenied
    
    /// Failed to initialize the audio engine.
    case audioEngineInitializationFailed(String)
    
    /// Audio device was disconnected during recording.
    case audioDeviceDisconnected
    
    /// The audio format is not supported.
    case unsupportedAudioFormat(String)
    
    /// Recording was interrupted by system audio.
    case recordingInterrupted
    
    /// Failed to access the microphone.
    case microphoneAccessFailed(String)
    
    // MARK: - Model Errors
    
    /// The requested model file was not found.
    case modelNotFound(ModelType)
    
    /// Failed to load the ML model.
    case modelLoadingFailed(ModelType, String)
    
    /// Model file is corrupted or invalid.
    case modelCorrupted(ModelType)
    
    /// Insufficient memory to load the model.
    case insufficientMemoryForModel(ModelType)
    
    /// Model version is incompatible.
    case incompatibleModelVersion(String)
    
    /// No model is currently loaded.
    case noModelLoaded
    
    // MARK: - Transcription Errors
    
    /// Transcription failed with an error.
    case transcriptionFailed(String)
    
    /// Audio data is empty or invalid.
    case invalidAudioData
    
    /// Transcription confidence is below threshold.
    case lowConfidenceTranscription(Float)
    
    /// Language not supported by the current model.
    case unsupportedLanguage(Language)
    
    // MARK: - Text Injection Errors
    
    /// Accessibility permission was denied.
    case accessibilityPermissionDenied
    
    /// No application is currently focused.
    case noFocusedApplication
    
    /// The target application is not supported.
    case unsupportedApplication(String)
    
    /// Text injection failed.
    case injectionFailed(String)
    
    /// Clipboard operation failed.
    case clipboardOperationFailed
    
    // MARK: - Network/Download Errors
    
    /// Network connection is not available.
    case networkUnavailable
    
    /// Model download failed.
    case downloadFailed(ModelType, String)
    
    /// Download was cancelled by user.
    case downloadCancelled
    
    /// Checksum validation failed.
    case checksumMismatch(ModelType)
    
    // MARK: - Storage Errors
    
    /// Insufficient disk space for operation.
    case insufficientDiskSpace(Int64)
    
    /// Failed to create required directories.
    case directoryCreationFailed(String)
    
    /// File operation failed.
    case fileOperationFailed(String)
    
    // MARK: - Configuration Errors
    
    /// Configuration file is invalid.
    case invalidConfiguration(String)
    
    /// Required configuration is missing.
    case missingConfiguration(String)
    
    // MARK: - System Errors
    
    /// Operation timed out.
    case timeout(String)
    
    /// Operation was cancelled.
    case cancelled
    
    /// Unknown error occurred.
    case unknown(String)
    
    // MARK: - LocalizedError Implementation
    
    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access was denied. Please enable microphone permission in System Preferences."
            
        case .audioEngineInitializationFailed(let details):
            return "Failed to initialize audio engine: \(details)"
            
        case .audioDeviceDisconnected:
            return "Audio device was disconnected. Please reconnect and try again."
            
        case .unsupportedAudioFormat(let format):
            return "Audio format '\(format)' is not supported."
            
        case .recordingInterrupted:
            return "Recording was interrupted by another application."
            
        case .microphoneAccessFailed(let reason):
            return "Failed to access microphone: \(reason)"
            
        case .modelNotFound(let type):
            return "Model '\(type.displayName)' was not found. Please download it from settings."
            
        case .modelLoadingFailed(let type, let reason):
            return "Failed to load '\(type.displayName)' model: \(reason)"
            
        case .modelCorrupted(let type):
            return "Model '\(type.displayName)' appears to be corrupted. Please re-download."
            
        case .insufficientMemoryForModel(let type):
            return "Insufficient memory to load '\(type.displayName)'. Try using a smaller model."
            
        case .incompatibleModelVersion(let version):
            return "Model version '\(version)' is not compatible with this app version."
            
        case .noModelLoaded:
            return "No transcription model is loaded. Please select a model in settings."
            
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
            
        case .invalidAudioData:
            return "The recorded audio data is invalid or empty."
            
        case .lowConfidenceTranscription(let confidence):
            return "Transcription confidence (\(Int(confidence * 100))%) is too low. Please speak clearly."
            
        case .unsupportedLanguage(let language):
            return "Language '\(language.displayName)' is not supported by the current model."
            
        case .accessibilityPermissionDenied:
            return "Accessibility permission is required for text insertion. Enable it in System Preferences > Privacy & Security > Accessibility."
            
        case .noFocusedApplication:
            return "No application is currently focused. Click on a text field and try again."
            
        case .unsupportedApplication(let appName):
            return "Text insertion is not supported in '\(appName)'. Text has been copied to clipboard instead."
            
        case .injectionFailed(let reason):
            return "Failed to insert text: \(reason)"
            
        case .clipboardOperationFailed:
            return "Failed to copy text to clipboard."
            
        case .networkUnavailable:
            return "Network connection is not available. Please check your internet connection."
            
        case .downloadFailed(let type, let reason):
            return "Failed to download '\(type.displayName)' model: \(reason)"
            
        case .downloadCancelled:
            return "Download was cancelled."
            
        case .checksumMismatch(let type):
            return "Downloaded '\(type.displayName)' model is corrupted. Please try again."
            
        case .insufficientDiskSpace(let required):
            return "Insufficient disk space. Need \(required / 1024 / 1024) MB free."
            
        case .directoryCreationFailed(let path):
            return "Failed to create directory at: \(path)"
            
        case .fileOperationFailed(let operation):
            return "File operation failed: \(operation)"
            
        case .invalidConfiguration(let details):
            return "Invalid configuration: \(details)"
            
        case .missingConfiguration(let key):
            return "Missing required configuration: \(key)"
            
        case .timeout(let operation):
            return "Operation timed out: \(operation)"
            
        case .cancelled:
            return "Operation was cancelled."
            
        case .unknown(let details):
            return "An unknown error occurred: \(details)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Open System Preferences > Privacy & Security > Microphone and enable VoiceType."
            
        case .audioDeviceDisconnected:
            return "Reconnect your audio device or select a different microphone in settings."
            
        case .modelNotFound:
            return "Open Settings and download the required model."
            
        case .insufficientMemoryForModel:
            return "Close other applications or try using the 'Fast' model instead."
            
        case .accessibilityPermissionDenied:
            return "Open System Preferences > Privacy & Security > Accessibility and add VoiceType."
            
        case .unsupportedApplication:
            return "The text has been copied to your clipboard. Use ⌘V to paste."
            
        case .networkUnavailable:
            return "Check your internet connection and try again."
            
        case .insufficientDiskSpace:
            return "Free up disk space by removing unnecessary files."
            
        default:
            return nil
        }
    }
}