# VoiceType API Reference

## Core Protocols

VoiceType's architecture is built around several core protocols that define the contracts between components.

### AudioProcessor

The `AudioProcessor` protocol handles all audio recording functionality.

```swift
public protocol AudioProcessor {
    /// Indicates whether the processor is currently recording audio
    var isRecording: Bool { get }
    
    /// Stream that emits audio level changes during recording (0.0 to 1.0)
    var audioLevelChanged: AsyncStream<Float> { get }
    
    /// Stream that emits recording state changes
    var recordingStateChanged: AsyncStream<RecordingState> { get }
    
    /// Starts recording audio from the configured input device
    /// - Throws: AudioError if microphone permission is denied or audio setup fails
    /// - Note: Recording will automatically stop after 5 seconds unless stopped manually
    func startRecording() async throws
    
    /// Stops recording and returns the captured audio data
    /// - Returns: AudioData containing the recorded samples
    /// - Note: Safe to call even if recording has already stopped
    func stopRecording() async -> AudioData
}
```

#### Usage Example

```swift
let audioProcessor = AVFoundationAudio()

// Monitor audio levels
Task {
    for await level in audioProcessor.audioLevelChanged {
        print("Audio level: \(level)")
    }
}

// Start recording
try await audioProcessor.startRecording()

// Stop and get audio
let audioData = await audioProcessor.stopRecording()
```

### AudioPreprocessor

Optional protocol for audio preprocessing plugins.

```swift
public protocol AudioPreprocessor {
    /// Process raw audio data before it's sent to transcription
    /// - Parameter audio: The raw audio data to process
    /// - Returns: Processed audio data ready for transcription
    func process(_ audio: AudioData) async -> AudioData
}
```

#### Implementation Example

```swift
class NoiseReductionPreprocessor: AudioPreprocessor {
    func process(_ audio: AudioData) async -> AudioData {
        // Apply noise reduction algorithm
        let processed = applyNoiseReduction(to: audio)
        return processed
    }
}
```

### Transcriber

The `Transcriber` protocol defines speech-to-text functionality.

```swift
public protocol Transcriber {
    /// Information about the currently loaded model
    var modelInfo: ModelInfo { get }
    
    /// Languages supported by the current model
    var supportedLanguages: [Language] { get }
    
    /// Whether a model is currently loaded and ready for transcription
    var isModelLoaded: Bool { get }
    
    /// Transcribes audio data to text using the loaded ML model
    /// - Parameters:
    ///   - audio: The audio data to transcribe (should be 16kHz mono PCM)
    ///   - language: Optional language hint for better accuracy. If nil, auto-detects
    /// - Returns: TranscriptionResult containing the transcribed text and metadata
    /// - Throws: TranscriptionError if model is not loaded or transcription fails
    func transcribe(_ audio: AudioData, language: Language?) async throws -> TranscriptionResult
    
    /// Loads a specific model type for transcription
    /// - Parameter type: The model type to load (fast, balanced, or accurate)
    /// - Throws: ModelError if model file is not found or loading fails
    /// - Note: Loading a new model will unload any previously loaded model
    func loadModel(_ type: ModelType) async throws
}
```

#### Usage Example

```swift
let transcriber = CoreMLWhisper()

// Load model
try await transcriber.loadModel(.base)

// Transcribe audio
let result = try await transcriber.transcribe(audioData, language: .english)
print("Text: \(result.text)")
print("Confidence: \(result.confidence)")
```

### TextInjector

The `TextInjector` protocol handles inserting text into target applications.

```swift
public protocol TextInjector {
    /// Checks if this injector can insert text into the specified target application
    /// - Parameter target: The application to check compatibility with
    /// - Returns: true if injection is supported for this application
    func canInject(into target: TargetApplication) -> Bool
    
    /// Injects the transcribed text into the target application at the cursor position
    /// - Parameters:
    ///   - text: The text to insert
    ///   - target: The target application to insert into
    /// - Throws: InjectionError if insertion fails or is not supported
    func inject(_ text: String, into target: TargetApplication) async throws
    
    /// Gets the currently focused application that would receive text input
    /// - Returns: The target application if one is focused, nil otherwise
    func getFocusedTarget() async -> TargetApplication?
}
```

#### Usage Example

```swift
let injector = AccessibilityInjector()

// Get focused app
if let target = await injector.getFocusedTarget() {
    // Check compatibility
    if injector.canInject(into: target) {
        // Inject text
        try await injector.inject("Hello, world!", into: target)
    }
}
```

## Data Models

### AudioData

Represents audio samples for processing.

```swift
public struct AudioData {
    /// Raw audio samples as Float32 values
    public let samples: [Float]
    
    /// Sample rate in Hz (typically 16000)
    public let sampleRate: Double
    
    /// Number of audio channels (1 for mono, 2 for stereo)
    public let channelCount: Int
    
    /// Duration of the audio in seconds
    public var duration: TimeInterval {
        Double(samples.count) / (sampleRate * Double(channelCount))
    }
    
    /// Initialize with raw samples
    public init(samples: [Float], sampleRate: Double, channelCount: Int)
    
    /// Create from Data containing Float32 samples
    public init(data: Data, sampleRate: Double, channelCount: Int)
    
    /// Convert to Data for storage or transmission
    public func toData() -> Data
}
```

### TranscriptionResult

Result of speech-to-text transcription.

```swift
public struct TranscriptionResult {
    /// The transcribed text
    public let text: String
    
    /// Confidence score (0.0 to 1.0)
    public let confidence: Float
    
    /// Detected or specified language
    public let language: Language
    
    /// Processing time in seconds
    public let processingTime: TimeInterval
    
    /// Optional word-level timing information
    public let wordTimings: [WordTiming]?
    
    /// Model used for transcription
    public let model: ModelType
}

public struct WordTiming {
    public let word: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Float
}
```

### RecordingState

State machine for the recording process.

```swift
public enum RecordingState: Equatable {
    /// Ready to start recording
    case idle
    
    /// Currently recording audio
    case recording
    
    /// Processing audio (transcribing)
    case processing
    
    /// Successfully completed
    case success
    
    /// Error occurred
    case error(String)
}
```

### ModelType

Available AI model types.

```swift
public enum ModelType: String, CaseIterable {
    /// Fastest, least accurate (39M parameters)
    case tiny = "tiny"
    
    /// Good balance (74M parameters)
    case base = "base"
    
    /// Better accuracy (244M parameters)
    case small = "small"
    
    /// Display name for UI
    public var displayName: String { get }
    
    /// Whether model is embedded in app bundle
    public var isEmbedded: Bool { get }
    
    /// Approximate download size
    public var downloadSize: Int { get }
}
```

### Language

Supported languages for transcription.

```swift
public enum Language: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case russian = "ru"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    // ... more languages
    
    /// Human-readable name
    public var displayName: String { get }
    
    /// ISO 639-1 code
    public var code: String { get }
}
```

### TargetApplication

Information about the target application for text injection.

```swift
public struct TargetApplication: Equatable {
    /// Bundle identifier (e.g., "com.apple.TextEdit")
    public let bundleIdentifier: String
    
    /// Application name
    public let name: String
    
    /// Whether app is currently active
    public let isActive: Bool
    
    /// Process identifier
    public let processIdentifier: pid_t?
    
    /// Known application type
    public var appType: AppType? {
        AppType(bundleIdentifier: bundleIdentifier)
    }
}

public enum AppType {
    case textEditor
    case browser
    case terminal
    case chat
    case notes
    case ide
    case custom(String)
}
```

## Error Types

### VoiceTypeError

Central error type for the application.

```swift
public enum VoiceTypeError: LocalizedError {
    // Audio errors
    case microphonePermissionDenied
    case audioDeviceNotFound
    case audioDeviceDisconnected
    case audioSetupFailed(String)
    case invalidAudioData
    
    // Model errors
    case modelNotFound(ModelType)
    case modelLoadingFailed(String)
    case modelDownloadFailed(String)
    case insufficientStorage
    
    // Transcription errors
    case transcriptionFailed(String)
    case languageNotSupported(Language)
    case audioTooShort
    case audioTooLong
    case lowConfidenceTranscription(Float)
    
    // Injection errors
    case noFocusedApplication
    case unsupportedApplication(String)
    case injectionFailed(String)
    case accessibilityPermissionDenied
    
    // Network errors
    case networkUnavailable
    case serverError(Int)
    
    // General errors
    case unknown(String)
    
    public var errorDescription: String? { get }
    public var recoverySuggestion: String? { get }
}
```

## Factory Classes

### TranscriberFactory

Creates transcriber instances.

```swift
public enum TranscriberFactory {
    /// Create default production transcriber
    public static func createTranscriber() -> Transcriber
    
    /// Create CoreML Whisper transcriber
    public static func createCoreMLWhisper(
        modelType: ModelType = .base,
        modelPath: String? = nil
    ) -> Transcriber
    
    /// Create mock transcriber for testing
    public static func createMock(
        scenario: MockTranscriber.Scenario = .success
    ) -> MockTranscriber
}
```

### TextInjectorFactory

Creates text injector instances.

```swift
public class TextInjectorFactory {
    /// Create appropriate injector for current context
    public static func createInjector() -> TextInjector
    
    /// Create injector for specific application
    public static func createInjector(
        for app: TargetApplication
    ) -> TextInjector
    
    /// Register custom injector for bundle ID
    public static func registerCustomInjector(
        _ injector: TextInjector,
        for bundleId: String
    )
}
```

## Extension Points

### VoiceTypePlugin Protocol

For creating plugins that extend VoiceType functionality.

```swift
public protocol VoiceTypePlugin {
    /// The display name of the plugin
    var name: String { get }
    
    /// The version string of the plugin (e.g., "1.0.0")
    var version: String { get }
    
    /// Registers the plugin's components with the main coordinator
    /// - Parameter coordinator: The plugin coordinator to register components with
    func register(with coordinator: PluginCoordinator)
    
    /// Initializes the plugin and performs any necessary setup
    /// - Throws: Any error that occurs during initialization
    func initialize() async throws
}
```

### PluginCoordinator Protocol

Interface for plugins to register components.

```swift
public protocol PluginCoordinator {
    /// Registers a custom audio processor
    func registerAudioProcessor(_ processor: AudioProcessor)
    
    /// Registers a custom audio preprocessor
    func registerAudioPreprocessor(_ preprocessor: AudioPreprocessor)
    
    /// Registers a custom transcriber
    func registerTranscriber(_ transcriber: Transcriber)
    
    /// Registers a custom text injector
    func registerTextInjector(_ injector: TextInjector)
    
    /// Registers an app-specific text injector for a bundle ID
    func registerAppSpecificInjector(
        _ injector: TextInjector,
        for bundleId: String
    )
}
```

## Utility Classes

### AudioProcessorConfiguration

Configuration for audio recording.

```swift
public struct AudioProcessorConfiguration {
    /// Sample rate for audio recording (Hz)
    public let sampleRate: Double
    
    /// Number of audio channels (1 for mono, 2 for stereo)
    public let channelCount: Int
    
    /// Audio format bit depth
    public let bitDepth: Int
    
    /// Buffer size in samples
    public let bufferSize: Int
    
    /// Maximum recording duration in seconds
    public let maxRecordingDuration: TimeInterval
    
    /// Default configuration for VoiceType MVP (16kHz mono)
    public static let voiceTypeMVP = AudioProcessorConfiguration(
        sampleRate: 16000,
        channelCount: 1,
        bitDepth: 16,
        bufferSize: 1024,
        maxRecordingDuration: 5.0
    )
}
```

### ModelInfo

Information about a loaded ML model.

```swift
public struct ModelInfo {
    /// Model type (tiny, base, small)
    public let type: ModelType
    
    /// Model version string
    public let version: String
    
    /// Supported languages
    public let supportedLanguages: [Language]
    
    /// Model file size in bytes
    public let fileSize: Int64
    
    /// Whether model is embedded or downloaded
    public let isEmbedded: Bool
    
    /// Model capabilities
    public let capabilities: Set<ModelCapability>
}

public enum ModelCapability {
    case multiLanguage
    case punctuation
    case timestamps
    case wordLevelConfidence
    case speakerDiarization
}
```

### PerformanceMetrics

Runtime performance measurements.

```swift
public struct PerformanceMetrics {
    /// Audio recording duration
    public let recordingDuration: TimeInterval
    
    /// Time to load model
    public let modelLoadTime: TimeInterval?
    
    /// Time to transcribe audio
    public let transcriptionTime: TimeInterval
    
    /// Time to inject text
    public let injectionTime: TimeInterval?
    
    /// Total end-to-end time
    public let totalTime: TimeInterval
    
    /// Peak memory usage in bytes
    public let peakMemoryUsage: Int64
    
    /// Audio processing metrics
    public let audioMetrics: AudioMetrics
}

public struct AudioMetrics {
    /// Average audio level (0.0 to 1.0)
    public let averageLevel: Float
    
    /// Peak audio level
    public let peakLevel: Float
    
    /// Signal-to-noise ratio in dB
    public let signalToNoiseRatio: Float?
    
    /// Clipping detected
    public let hasClipping: Bool
}
```

## Async Streams

### Using AsyncStream for Reactive Updates

VoiceType uses Swift's AsyncStream for reactive updates:

```swift
// Monitor recording state changes
Task {
    for await state in coordinator.recordingStateChanged {
        switch state {
        case .idle:
            updateUI(state: "Ready")
        case .recording:
            updateUI(state: "Recording...")
        case .processing:
            updateUI(state: "Processing...")
        case .success:
            updateUI(state: "Complete!")
        case .error(let message):
            showError(message)
        }
    }
}

// Monitor audio levels
Task {
    for await level in audioProcessor.audioLevelChanged {
        audioLevelBar.value = level
    }
}
```

## Constants and Configuration

### UserDefaults Keys

```swift
public enum UserDefaultsKey {
    static let selectedModel = "selectedModel"
    static let selectedLanguage = "selectedLanguage"
    static let globalHotkey = "globalHotkey"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let enableDebugLogging = "VoiceTypeDebugLogging"
    static let audioInputDevice = "audioInputDevice"
    static let enableHapticFeedback = "enableHapticFeedback"
}
```

### Notification Names

```swift
public extension Notification.Name {
    static let voiceTypeDidStartRecording = Notification.Name("VoiceTypeDidStartRecording")
    static let voiceTypeDidCompleteTranscription = Notification.Name("VoiceTypeDidCompleteTranscription")
    static let voiceTypeModelDidChange = Notification.Name("VoiceTypeModelDidChange")
    static let voiceTypePermissionDidChange = Notification.Name("VoiceTypePermissionDidChange")
}
```

## Thread Safety

All public APIs in VoiceType are thread-safe and can be called from any queue. UI updates are automatically dispatched to the main actor:

```swift
@MainActor
public class VoiceTypeCoordinator: ObservableObject {
    // All @Published properties update on main thread
}

// Safe to call from any thread
Task.detached {
    await coordinator.startDictation()
}
```

## Memory Management

VoiceType uses ARC with careful attention to retain cycles:

```swift
// Weak self in closures
audioProcessor.audioLevelChanged
    .sink { [weak self] level in
        self?.updateLevel(level)
    }
    .store(in: &cancellables)

// Automatic cleanup
deinit {
    // Cancellables are automatically cancelled
    // Resources are released
}
```