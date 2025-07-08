import Foundation

/// Protocol for creating VoiceType plugins that extend functionality.
/// Plugins can add new audio processors, transcribers, text injectors, or other features.
public protocol VoiceTypePlugin {
    /// The display name of the plugin.
    var name: String { get }

    /// The version string of the plugin (e.g., "1.0.0").
    var version: String { get }

    /// Registers the plugin's components with the main coordinator.
    /// - Parameter coordinator: The plugin coordinator to register components with
    func register(with coordinator: PluginCoordinator)

    /// Initializes the plugin and performs any necessary setup.
    /// - Throws: Any error that occurs during initialization
    func initialize() async throws
}

/// Coordinator that manages plugin registration and lifecycle.
public protocol PluginCoordinator {
    /// Registers a custom audio processor.
    /// - Parameter processor: The audio processor to register
    func registerAudioProcessor(_ processor: AudioProcessor)

    /// Registers a custom audio preprocessor.
    /// - Parameter preprocessor: The preprocessor to register
    func registerAudioPreprocessor(_ preprocessor: AudioPreprocessor)

    /// Registers a custom transcriber.
    /// - Parameter transcriber: The transcriber to register
    func registerTranscriber(_ transcriber: Transcriber)

    /// Registers a custom text injector.
    /// - Parameter injector: The text injector to register
    func registerTextInjector(_ injector: TextInjector)

    /// Registers an app-specific text injector for a bundle ID.
    /// - Parameters:
    ///   - injector: The text injector to register
    ///   - bundleId: The bundle ID of the target application
    func registerAppSpecificInjector(_ injector: TextInjector, for bundleId: String)
}
