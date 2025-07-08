import Foundation

/// Protocol for managing application configuration.
public protocol ConfigurationManager {
    /// Gets a configuration value for a key.
    /// - Parameter key: The configuration key
    /// - Returns: The value if it exists, nil otherwise
    func getValue(for key: String) -> Any?

    /// Sets a configuration value for a key.
    /// - Parameters:
    ///   - value: The value to set
    ///   - key: The configuration key
    func setValue(_ value: Any?, for key: String)

    /// Gets a typed configuration value.
    /// - Parameters:
    ///   - type: The expected type
    ///   - key: The configuration key
    /// - Returns: The typed value if it exists and matches the type
    func getValue<T>(ofType type: T.Type, for key: String) -> T?

    /// Loads configuration from external sources.
    func loadConfiguration() async throws

    /// Saves current configuration.
    func saveConfiguration() async throws

    /// Resets configuration to defaults.
    func resetToDefaults()
}

/// Common configuration keys used throughout the application.
public enum ConfigurationKey {
    // Audio configuration
    public static let audioProcessor = "audio.processor"
    public static let audioPreprocessors = "audio.preprocessors"
    public static let sampleRate = "audio.sampleRate"
    public static let chunkDuration = "audio.chunkDuration"
    public static let bufferSize = "audio.bufferSize"

    // Transcription configuration
    public static let transcriptionProvider = "transcription.provider"
    public static let defaultModel = "transcription.defaultModel"
    public static let enableLanguageDetection = "transcription.enableLanguageDetection"
    public static let confidenceThreshold = "transcription.confidenceThreshold"
    public static let selectedLanguage = "transcription.selectedLanguage"

    // Text injection configuration
    public static let primaryInjectionMethod = "textInjection.primaryMethod"
    public static let fallbackMethods = "textInjection.fallbackMethods"
    public static let retryAttempts = "textInjection.retryAttempts"
    public static let insertionDelay = "textInjection.insertionDelay"
    public static let appSpecificInjectors = "textInjection.appSpecificInjectors"

    // UI configuration
    public static let globalHotkey = "ui.hotkey"
    public static let showOverlay = "ui.showOverlay"
    public static let menuBarIcon = "ui.menuBarIcon"
    public static let feedbackType = "ui.feedbackType"

    // Advanced configuration
    public static let enableDebugLogging = "advanced.enableDebugLogging"
    public static let performanceMonitoring = "advanced.performanceMonitoring"
    public static let maxConcurrentTranscriptions = "advanced.maxConcurrentTranscriptions"

    // User preferences
    public static let hasLaunchedBefore = "preferences.hasLaunchedBefore"
    public static let lastUpdateCheck = "preferences.lastUpdateCheck"
    public static let selectedAudioDevice = "preferences.audioDevice"
}
