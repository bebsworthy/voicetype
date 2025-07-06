# VoiceType Architecture Guide

## Overview

VoiceType follows a **protocol-first, dependency injection** architecture that ensures maximum testability, flexibility, and extensibility. The application is built using Swift and SwiftUI for macOS, with a clear separation between core business logic, implementations, and UI components.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        VoiceType App                         │
│                    (SwiftUI Application)                     │
├─────────────────────────────────────────────────────────────┤
│                    VoiceTypeCoordinator                      │
│              (Main State Management & Flow)                  │
├──────────────┬─────────────┬─────────────┬─────────────────┤
│              │             │             │                   │
│  AudioProcessor  Transcriber  TextInjector  PermissionManager│
│  (Protocol)      (Protocol)   (Protocol)    (Concrete)      │
├──────────────┴─────────────┴─────────────┴─────────────────┤
│                    Core Protocols Layer                      │
│           (No External Dependencies, Pure Swift)             │
├─────────────────────────────────────────────────────────────┤
│                  Concrete Implementations                    │
│  AVFoundationAudio  CoreMLWhisper  AccessibilityInjector   │
│                     MockTranscriber  ClipboardInjector      │
└─────────────────────────────────────────────────────────────┘
```

## Core Design Principles

### 1. Protocol-First Design

Every major component is defined as a protocol first, with concrete implementations provided separately:

```swift
// Core protocol definition
public protocol AudioProcessor {
    var isRecording: Bool { get }
    var audioLevelChanged: AsyncStream<Float> { get }
    var recordingStateChanged: AsyncStream<RecordingState> { get }
    
    func startRecording() async throws
    func stopRecording() async -> AudioData
}

// Concrete implementation
class AVFoundationAudio: AudioProcessor {
    // Implementation details...
}
```

**Benefits:**
- Easy testing with mock implementations
- Supports multiple implementations (e.g., different audio backends)
- Clear contracts between components
- Plugin system extensibility

### 2. Dependency Injection

The `VoiceTypeCoordinator` accepts all dependencies through its initializer:

```swift
public init(
    audioProcessor: AudioProcessor? = nil,
    transcriber: Transcriber? = nil,
    textInjector: TextInjector? = nil,
    permissionManager: PermissionManager? = nil,
    hotkeyManager: HotkeyManager? = nil,
    modelManager: ModelManager? = nil
)
```

This allows:
- Complete control over dependencies in tests
- Easy swapping of implementations
- Plugin system support
- Clear dependency graph

### 3. Async/Await and Modern Concurrency

VoiceType fully embraces Swift's modern concurrency features:

```swift
// Async streams for reactive updates
var audioLevelChanged: AsyncStream<Float> { get }

// Async functions for operations
func transcribe(_ audio: AudioData, language: Language?) async throws -> TranscriptionResult
```

### 4. State Management

The app uses a centralized state management approach through `VoiceTypeCoordinator`:

```swift
enum RecordingState {
    case idle
    case recording
    case processing
    case success
    case error(String)
}
```

State transitions are atomic and validated to prevent invalid states.

## Component Architecture

### Core Components

#### 1. **AudioProcessor**
- **Purpose**: Handles microphone access and audio recording
- **Key Protocol**: `AudioProcessor`
- **Implementations**: 
  - `AVFoundationAudio` (production)
  - `MockAudioProcessor` (testing)
- **Features**:
  - Automatic 5-second recording limit
  - Real-time audio level monitoring
  - Configurable audio format

#### 2. **Transcriber**
- **Purpose**: Converts audio to text using ML models
- **Key Protocol**: `Transcriber`
- **Implementations**:
  - `CoreMLWhisper` (production)
  - `MockTranscriber` (testing)
- **Features**:
  - Multiple model support (tiny, base, small)
  - Language detection and selection
  - Confidence scoring

#### 3. **TextInjector**
- **Purpose**: Inserts transcribed text into target applications
- **Key Protocol**: `TextInjector`
- **Implementations**:
  - `AccessibilityInjector` (primary)
  - `ClipboardInjector` (fallback)
  - `AppSpecificInjector` (custom per-app)
- **Features**:
  - Automatic fallback strategies
  - Application compatibility detection
  - Plugin support for custom injectors

#### 4. **VoiceTypeCoordinator**
- **Purpose**: Orchestrates the complete workflow
- **Responsibilities**:
  - State management
  - Error handling and recovery
  - Component lifecycle
  - Permission management
  - Hotkey handling

### Supporting Components

#### PermissionManager
Handles macOS permissions:
- Microphone access
- Accessibility permissions
- User guidance for permission setup

#### HotkeyManager
Global hotkey management:
- Configurable key combinations
- System-wide registration
- Conflict detection

#### ModelManager
ML model lifecycle:
- Model downloading
- Storage management
- Version control
- Progress tracking

## Data Flow

### Recording Flow

```
User Press Hotkey
       ↓
VoiceTypeCoordinator.startDictation()
       ↓
Check Permissions → Request if needed
       ↓
AudioProcessor.startRecording()
       ↓
Recording (max 5 seconds)
       ↓
User Release Hotkey or Auto-stop
       ↓
AudioProcessor.stopRecording() → AudioData
       ↓
Transcriber.transcribe(audioData) → TranscriptionResult
       ↓
TextInjector.inject(text) → Target App
       ↓
Success/Error State
```

### Error Recovery Flow

```
Error Detected
       ↓
Classify Error Type
       ↓
┌─────────────┬──────────────┬────────────────┐
│ Permission  │ Model Error  │ Injection Error│
│   Denied    │              │                │
└──────┬──────┴──────┬───────┴────────┬───────┘
       ↓             ↓                 ↓
  Show Guide    Try Fallback    Use Clipboard
                   Model           Fallback
```

## Module Structure

```
VoiceType/
├── Sources/
│   ├── Core/                    # Protocol definitions, models
│   │   ├── AudioProcessor.swift
│   │   ├── Transcriber.swift
│   │   ├── TextInjector.swift
│   │   ├── Models/
│   │   └── Errors/
│   │
│   ├── Implementations/         # Concrete implementations
│   │   ├── AVFoundationAudio.swift
│   │   ├── CoreMLWhisper.swift
│   │   ├── TextInjection/
│   │   └── ModelManagement/
│   │
│   ├── UI/                      # SwiftUI views
│   │   ├── MenuBar/
│   │   ├── Settings/
│   │   └── Onboarding/
│   │
│   └── VoiceType/              # App entry point
│       ├── VoiceTypeApp.swift
│       ├── AppDelegate.swift
│       └── Coordinator/
│
├── Tests/
│   ├── CoreTests/
│   ├── IntegrationTests/
│   └── PerformanceTests/
│
└── Package.swift               # SPM configuration
```

## Extension Points

### Plugin System

VoiceType supports plugins through the `VoiceTypePlugin` protocol:

```swift
public protocol VoiceTypePlugin {
    var name: String { get }
    var version: String { get }
    
    func register(with coordinator: PluginCoordinator)
    func initialize() async throws
}
```

Plugins can:
- Add custom audio processors
- Register new transcriber implementations
- Provide app-specific text injectors
- Add audio preprocessing steps

### Custom Implementations

To add a new implementation:

1. Implement the appropriate protocol
2. Register with the factory or coordinator
3. Configure dependency injection

Example:
```swift
class CustomTranscriber: Transcriber {
    // Your implementation
}

// Register in factory
TranscriberFactory.register(CustomTranscriber.self, for: .custom)
```

## Performance Considerations

### Memory Management
- Audio buffers are released immediately after processing
- Models are loaded on-demand and can be unloaded
- Weak references prevent retain cycles in async callbacks

### Concurrency
- All UI updates on main actor
- Audio processing on dedicated queues
- Parallel permission checks
- Atomic state transitions

### Optimization
- Cross-module optimization in release builds
- Lazy initialization of heavy components
- Efficient audio format conversion
- Model caching and reuse

## Security Considerations

### Permissions
- Minimal permission requests
- Clear user guidance
- Graceful degradation without permissions

### Data Privacy
- No audio stored permanently
- No network requests for transcription
- Local-only processing
- No user data collection

### Code Security
- Input validation on all public APIs
- Sandboxed execution
- No arbitrary code execution
- Signed and notarized distribution

## Testing Architecture

### Unit Tests
- Mock implementations for all protocols
- Isolated component testing
- Comprehensive error scenarios

### Integration Tests
- End-to-end workflow testing
- Permission handling
- Error recovery paths
- Multi-component interaction

### Performance Tests
- Audio processing efficiency
- Model loading times
- Memory usage tracking
- Latency measurements

## Best Practices

1. **Always use protocols** for new components
2. **Inject dependencies** rather than creating them
3. **Handle errors gracefully** with recovery strategies
4. **Keep UI logic minimal** - business logic in coordinator
5. **Test with mocks** before implementing real versions
6. **Document extension points** for plugin developers
7. **Monitor performance** with built-in metrics

## Future Architecture Considerations

### Planned Enhancements
- Multi-model ensemble support
- Streaming transcription
- Cloud model support (opt-in)
- Advanced audio preprocessing pipeline

### Scalability
- Plugin marketplace infrastructure
- Remote configuration
- A/B testing framework
- Analytics (opt-in)

### Platform Expansion
- iOS/iPadOS support (shared core)
- Windows/Linux versions
- Web-based configuration
- API for third-party apps