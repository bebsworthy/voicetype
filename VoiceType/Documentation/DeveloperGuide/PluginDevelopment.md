# VoiceType Plugin Development Guide

## Overview

VoiceType's plugin system allows developers to extend functionality without modifying the core application. Plugins can add custom audio processors, transcription models, text injection methods, and more.

## Plugin Architecture

```
┌─────────────────────────────────────────┐
│           VoiceType Core                │
│  ┌─────────────────────────────────┐   │
│  │      Plugin Coordinator         │   │
│  └────────────┬────────────────────┘   │
│               │                         │
│  ┌────────────▼────────────┐          │
│  │   Plugin Registry        │          │
│  └──────────────────────────┘          │
└───────────────┬─────────────────────────┘
                │
    ┌───────────▼───────────┐
    │    Your Plugin         │
    │  ┌─────────────────┐  │
    │  │ AudioProcessor  │  │
    │  │ Transcriber     │  │
    │  │ TextInjector    │  │
    │  └─────────────────┘  │
    └───────────────────────┘
```

## Creating Your First Plugin

### 1. Basic Plugin Structure

```swift
import Foundation
import VoiceTypeCore

public class MyVoiceTypePlugin: VoiceTypePlugin {
    public var name: String {
        "My Awesome Plugin"
    }
    
    public var version: String {
        "1.0.0"
    }
    
    public init() {}
    
    public func register(with coordinator: PluginCoordinator) {
        // Register your custom components here
        coordinator.registerTranscriber(MyCustomTranscriber())
        coordinator.registerAudioPreprocessor(MyNoiseFilter())
        coordinator.registerAppSpecificInjector(
            SlackInjector(),
            for: "com.tinyspeck.slackmacgap"
        )
    }
    
    public func initialize() async throws {
        // Perform any async initialization
        // Download models, check licenses, etc.
        print("Initializing \(name) v\(version)")
    }
}
```

### 2. Plugin Package Structure

```
MyVoiceTypePlugin/
├── Package.swift
├── Sources/
│   └── MyVoiceTypePlugin/
│       ├── MyVoiceTypePlugin.swift
│       ├── Processors/
│       │   └── MyNoiseFilter.swift
│       ├── Transcribers/
│       │   └── MyCustomTranscriber.swift
│       └── Injectors/
│           └── SlackInjector.swift
└── Tests/
    └── MyVoiceTypePluginTests/
        └── PluginTests.swift
```

### 3. Package.swift Configuration

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MyVoiceTypePlugin",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "MyVoiceTypePlugin",
            type: .dynamic,  // Dynamic library for plugin loading
            targets: ["MyVoiceTypePlugin"]
        )
    ],
    dependencies: [
        // VoiceType Core dependency
        .package(
            url: "https://github.com/VoiceType/VoiceTypeCore.git",
            from: "1.0.0"
        )
    ],
    targets: [
        .target(
            name: "MyVoiceTypePlugin",
            dependencies: [
                .product(name: "VoiceTypeCore", package: "VoiceTypeCore")
            ]
        ),
        .testTarget(
            name: "MyVoiceTypePluginTests",
            dependencies: ["MyVoiceTypePlugin"]
        )
    ]
)
```

## Component Types

### Custom Audio Processors

Create custom audio input sources:

```swift
public class USBMicrophoneProcessor: AudioProcessor {
    public var isRecording: Bool = false
    
    public var audioLevelChanged: AsyncStream<Float> {
        AsyncStream { continuation in
            // Set up audio level monitoring
            self.levelContinuation = continuation
        }
    }
    
    public var recordingStateChanged: AsyncStream<RecordingState> {
        AsyncStream { continuation in
            self.stateContinuation = continuation
        }
    }
    
    private var levelContinuation: AsyncStream<Float>.Continuation?
    private var stateContinuation: AsyncStream<RecordingState>.Continuation?
    
    public func startRecording() async throws {
        // Configure USB microphone
        guard let device = findUSBMicrophone() else {
            throw VoiceTypeError.audioDeviceNotFound
        }
        
        // Start capture session
        isRecording = true
        stateContinuation?.yield(.recording)
        
        // Start level monitoring
        startLevelMonitoring()
    }
    
    public func stopRecording() async -> AudioData {
        isRecording = false
        stateContinuation?.yield(.idle)
        
        // Return captured audio
        return AudioData(
            samples: capturedSamples,
            sampleRate: 48000,  // USB mic rate
            channelCount: 1
        )
    }
    
    private func findUSBMicrophone() -> AudioDevice? {
        // Implementation to find USB microphone
    }
    
    private func startLevelMonitoring() {
        // Monitor and report audio levels
    }
}
```

### Audio Preprocessors

Add audio enhancement or filtering:

```swift
public class NoiseReductionPreprocessor: AudioPreprocessor {
    private let noiseProfile: NoiseProfile
    
    public init() {
        self.noiseProfile = NoiseProfile.default
    }
    
    public func process(_ audio: AudioData) async -> AudioData {
        // Apply spectral subtraction for noise reduction
        let spectrum = await computeFFT(audio)
        let cleaned = await subtractNoise(spectrum, profile: noiseProfile)
        let processed = await computeIFFT(cleaned)
        
        return AudioData(
            samples: processed,
            sampleRate: audio.sampleRate,
            channelCount: audio.channelCount
        )
    }
    
    private func computeFFT(_ audio: AudioData) async -> FrequencyDomain {
        // Fast Fourier Transform implementation
    }
    
    private func subtractNoise(
        _ spectrum: FrequencyDomain,
        profile: NoiseProfile
    ) async -> FrequencyDomain {
        // Spectral subtraction algorithm
    }
    
    private func computeIFFT(_ spectrum: FrequencyDomain) async -> [Float] {
        // Inverse FFT to get time-domain signal
    }
}
```

### Custom Transcribers

Integrate alternative speech recognition engines:

```swift
public class GoogleCloudTranscriber: Transcriber {
    private let apiKey: String
    private var currentModel: ModelType = .base
    
    public var modelInfo: ModelInfo {
        ModelInfo(
            type: currentModel,
            version: "Google Cloud Speech v1",
            supportedLanguages: Language.allCases,
            fileSize: 0,  // Cloud-based
            isEmbedded: false,
            capabilities: [.multiLanguage, .punctuation, .timestamps]
        )
    }
    
    public var supportedLanguages: [Language] {
        Language.allCases
    }
    
    public var isModelLoaded: Bool {
        // Cloud API is always "loaded"
        return true
    }
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    public func transcribe(
        _ audio: AudioData,
        language: Language?
    ) async throws -> TranscriptionResult {
        // Prepare audio for Google Cloud
        let encodedAudio = encodeToFLAC(audio)
        
        // Create API request
        let request = SpeechRecognitionRequest(
            audio: encodedAudio,
            language: language?.code ?? "en-US",
            model: mapModelType(currentModel)
        )
        
        // Send to Google Cloud
        let response = try await sendRequest(request)
        
        // Parse response
        return TranscriptionResult(
            text: response.transcript,
            confidence: Float(response.confidence),
            language: language ?? .english,
            processingTime: response.processingTime,
            wordTimings: parseWordTimings(response.words),
            model: currentModel
        )
    }
    
    public func loadModel(_ type: ModelType) async throws {
        // For cloud API, just store the preference
        currentModel = type
    }
    
    private func encodeToFLAC(_ audio: AudioData) -> Data {
        // Convert to FLAC format for API
    }
    
    private func sendRequest(
        _ request: SpeechRecognitionRequest
    ) async throws -> SpeechResponse {
        // HTTP request to Google Cloud
    }
}
```

### App-Specific Text Injectors

Create custom injection logic for specific applications:

```swift
public class VSCodeInjector: TextInjector {
    public func canInject(into target: TargetApplication) -> Bool {
        // Check if target is VS Code
        return target.bundleIdentifier == "com.microsoft.VSCode"
    }
    
    public func inject(
        _ text: String,
        into target: TargetApplication
    ) async throws {
        // VS Code specific injection using its API
        if isVSCodeExtensionInstalled() {
            // Use VS Code extension API
            try await injectViaExtension(text)
        } else {
            // Fallback to keyboard simulation
            try await injectViaKeyboard(text)
        }
    }
    
    public func getFocusedTarget() async -> TargetApplication? {
        // Get the focused application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        
        return TargetApplication(
            bundleIdentifier: frontApp.bundleIdentifier ?? "",
            name: frontApp.localizedName ?? "",
            isActive: true,
            processIdentifier: frontApp.processIdentifier
        )
    }
    
    private func isVSCodeExtensionInstalled() -> Bool {
        // Check if companion extension is installed
    }
    
    private func injectViaExtension(_ text: String) async throws {
        // Communicate with VS Code extension
        let url = URL(string: "vscode://voicetype/inject")!
        let request = URLRequest(url: url)
        // ... send text via local server or URL scheme
    }
    
    private func injectViaKeyboard(_ text: String) async throws {
        // Simulate keyboard input
        let source = CGEventSource(stateID: .hidSystemState)
        
        for character in text {
            if let event = createKeyEvent(for: character, source: source) {
                event.post(tap: .cghidEventTap)
                // Small delay between characters
                try await Task.sleep(nanoseconds: 10_000_000)
            }
        }
    }
}
```

## Advanced Plugin Features

### Configuration and Settings

Allow users to configure your plugin:

```swift
public protocol PluginConfigurable {
    /// View for plugin settings
    associatedtype SettingsView: View
    
    /// Create settings view
    func makeSettingsView() -> SettingsView
    
    /// Save configuration
    func saveConfiguration(_ config: [String: Any]) throws
    
    /// Load configuration
    func loadConfiguration() throws -> [String: Any]
}

// Example implementation
extension MyVoiceTypePlugin: PluginConfigurable {
    public func makeSettingsView() -> some View {
        MyPluginSettingsView()
    }
    
    public func saveConfiguration(_ config: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: config)
        try data.write(to: configurationURL)
    }
    
    public func loadConfiguration() throws -> [String: Any] {
        let data = try Data(contentsOf: configurationURL)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    private var configurationURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoiceType/Plugins/MyPlugin/config.json")
    }
}
```

### Model Management

For plugins that include ML models:

```swift
public class CustomModelManager {
    private let modelDirectory: URL
    
    public init() {
        self.modelDirectory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VoiceType/Plugins/MyPlugin/Models")
    }
    
    public func downloadModel(
        _ model: CustomModel,
        progress: @escaping (Double) -> Void
    ) async throws {
        // Create model directory if needed
        try FileManager.default.createDirectory(
            at: modelDirectory,
            withIntermediateDirectories: true
        )
        
        // Download with progress
        let (data, _) = try await URLSession.shared.data(
            from: model.downloadURL,
            delegate: ProgressDelegate(onProgress: progress)
        )
        
        // Save model
        let modelPath = modelDirectory.appendingPathComponent(model.filename)
        try data.write(to: modelPath)
        
        // Verify checksum
        guard verifyChecksum(data, expected: model.checksum) else {
            throw PluginError.corruptedModel
        }
    }
    
    public func loadModel(_ model: CustomModel) throws -> MLModel {
        let modelPath = modelDirectory.appendingPathComponent(model.filename)
        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw PluginError.modelNotFound
        }
        
        return try MLModel(contentsOf: modelPath)
    }
    
    public func deleteModel(_ model: CustomModel) throws {
        let modelPath = modelDirectory.appendingPathComponent(model.filename)
        try FileManager.default.removeItem(at: modelPath)
    }
    
    public var availableModels: [CustomModel] {
        // List downloaded models
    }
}
```

### Plugin Lifecycle Hooks

Respond to app lifecycle events:

```swift
public protocol PluginLifecycle {
    /// Called when the app launches
    func applicationDidLaunch() async
    
    /// Called before the app terminates
    func applicationWillTerminate() async
    
    /// Called when the plugin is enabled
    func pluginDidEnable() async
    
    /// Called when the plugin is disabled
    func pluginDidDisable() async
    
    /// Called when memory pressure is detected
    func didReceiveMemoryWarning() async
}

extension MyVoiceTypePlugin: PluginLifecycle {
    public func applicationDidLaunch() async {
        // Start background services
        await startBackgroundServices()
    }
    
    public func applicationWillTerminate() async {
        // Clean up resources
        await stopBackgroundServices()
        await saveState()
    }
    
    public func pluginDidEnable() async {
        // Register components
        print("\(name) enabled")
    }
    
    public func pluginDidDisable() async {
        // Unregister components
        print("\(name) disabled")
    }
    
    public func didReceiveMemoryWarning() async {
        // Free up memory
        await clearCaches()
    }
}
```

## Testing Your Plugin

### Unit Tests

```swift
import XCTest
@testable import MyVoiceTypePlugin
import VoiceTypeCore

final class MyPluginTests: XCTestCase {
    var plugin: MyVoiceTypePlugin!
    var mockCoordinator: MockPluginCoordinator!
    
    override func setUp() {
        super.setUp()
        plugin = MyVoiceTypePlugin()
        mockCoordinator = MockPluginCoordinator()
    }
    
    func testPluginRegistration() {
        // Register plugin
        plugin.register(with: mockCoordinator)
        
        // Verify components were registered
        XCTAssertEqual(mockCoordinator.registeredTranscribers.count, 1)
        XCTAssertEqual(mockCoordinator.registeredPreprocessors.count, 1)
        XCTAssertEqual(mockCoordinator.appSpecificInjectors.count, 1)
    }
    
    func testCustomTranscriber() async throws {
        let transcriber = MyCustomTranscriber()
        
        // Create test audio
        let testAudio = AudioData.createTestTone(
            frequency: 440,
            duration: 1.0
        )
        
        // Test transcription
        let result = try await transcriber.transcribe(
            testAudio,
            language: .english
        )
        
        XCTAssertFalse(result.text.isEmpty)
        XCTAssertGreaterThan(result.confidence, 0.5)
    }
    
    func testNoiseReduction() async {
        let processor = NoiseReductionPreprocessor()
        
        // Create noisy audio
        let noisyAudio = AudioData.createNoisyAudio()
        
        // Process
        let cleaned = await processor.process(noisyAudio)
        
        // Verify noise reduction
        let noisyRMS = calculateRMS(noisyAudio.samples)
        let cleanRMS = calculateRMS(cleaned.samples)
        
        XCTAssertLessThan(cleanRMS, noisyRMS * 0.8)
    }
}
```

### Integration Tests

```swift
func testPluginIntegration() async throws {
    // Create real coordinator
    let coordinator = VoiceTypeCoordinator()
    
    // Register plugin
    plugin.register(with: coordinator)
    try await plugin.initialize()
    
    // Test complete workflow
    let audioData = loadTestAudioFile()
    
    // Process through plugin's preprocessor
    let processed = await plugin.noiseFilter.process(audioData)
    
    // Transcribe with plugin's transcriber
    let result = try await plugin.transcriber.transcribe(
        processed,
        language: .english
    )
    
    // Verify result
    XCTAssertEqual(result.text, expectedTranscription)
}
```

## Distribution

### Building Your Plugin

```bash
# Build for distribution
swift build -c release --arch arm64 --arch x86_64

# Create plugin bundle
mkdir -p MyPlugin.voicetypeplugin/Contents/MacOS
cp .build/apple/Products/Release/libMyVoiceTypePlugin.dylib \
   MyPlugin.voicetypeplugin/Contents/MacOS/

# Add Info.plist
cat > MyPlugin.voicetypeplugin/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.mycompany.voicetype.myplugin</string>
    <key>CFBundleName</key>
    <string>My VoiceType Plugin</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>VoiceTypePluginClass</key>
    <string>MyVoiceTypePlugin</string>
</dict>
</plist>
EOF
```

### Plugin Installation

Users install plugins by:

1. Downloading the `.voicetypeplugin` bundle
2. Double-clicking to install
3. VoiceType automatically loads and initializes the plugin

### Plugin Discovery

VoiceType looks for plugins in:

```
~/Library/Application Support/VoiceType/Plugins/
/Library/Application Support/VoiceType/Plugins/
/Applications/VoiceType.app/Contents/PlugIns/
```

## Best Practices

### Performance

1. **Async Operations**: Use async/await for all I/O operations
2. **Memory Management**: Release resources promptly
3. **Caching**: Cache expensive computations
4. **Streaming**: Process audio in chunks for long recordings

### Error Handling

```swift
public enum PluginError: LocalizedError {
    case initializationFailed(String)
    case modelNotFound
    case corruptedModel
    case incompatibleVersion
    case missingDependency(String)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let reason):
            return "Plugin initialization failed: \(reason)"
        case .modelNotFound:
            return "Required model not found"
        case .corruptedModel:
            return "Model file is corrupted"
        case .incompatibleVersion:
            return "Plugin requires newer VoiceType version"
        case .missingDependency(let dep):
            return "Missing dependency: \(dep)"
        }
    }
}
```

### Security

1. **Sandboxing**: Respect macOS sandbox restrictions
2. **Permissions**: Request only necessary permissions
3. **Data Privacy**: Don't collect user data without consent
4. **Code Signing**: Sign your plugin for distribution

### Compatibility

1. **Version Check**: Verify VoiceType version compatibility
2. **Graceful Degradation**: Handle missing features
3. **Migration**: Support upgrading from older versions
4. **Platform**: Consider universal binary for Apple Silicon

## Example Plugins

### 1. Language Learning Plugin

Adds pronunciation assessment:

```swift
public class LanguageLearningPlugin: VoiceTypePlugin {
    public var name: String { "Language Learning Assistant" }
    public var version: String { "1.0.0" }
    
    public func register(with coordinator: PluginCoordinator) {
        coordinator.registerTranscriber(
            PronunciationAssessmentTranscriber()
        )
        coordinator.registerAudioPreprocessor(
            SpeechClarityEnhancer()
        )
    }
}
```

### 2. Medical Dictation Plugin

Specialized medical terminology:

```swift
public class MedicalDictationPlugin: VoiceTypePlugin {
    public var name: String { "Medical Dictation Pro" }
    public var version: String { "2.0.0" }
    
    public func register(with coordinator: PluginCoordinator) {
        coordinator.registerTranscriber(
            MedicalTranscriber(
                vocabularyPath: "medical-terms.txt"
            )
        )
        coordinator.registerAppSpecificInjector(
            EMRInjector(),
            for: "com.epic.hyperspace"
        )
    }
}
```

### 3. Streaming Platform Plugin

Real-time captioning for streamers:

```swift
public class StreamingPlugin: VoiceTypePlugin {
    public var name: String { "VoiceType Streaming" }
    public var version: String { "1.0.0" }
    
    public func register(with coordinator: PluginCoordinator) {
        coordinator.registerTranscriber(
            RealTimeTranscriber()
        )
        coordinator.registerTextInjector(
            OBSCaptionInjector()
        )
    }
}
```

## Resources

- [Plugin API Documentation](https://docs.voicetype.io/plugins/api)
- [Example Plugins](https://github.com/VoiceType/plugin-examples)
- [Plugin Development Forum](https://forum.voicetype.io/plugins)
- [Submit Your Plugin](https://voicetype.io/developers/submit)