# VoiceType Implementations

This directory contains concrete implementations of the core protocols defined in the VoiceType application.

## Structure

### Transcriber Implementations

- **CoreMLWhisper.swift**: Production implementation using CoreML Whisper models
  - Supports tiny, base, and small Whisper models
  - Converts audio to mel spectrograms (80x3000)
  - Handles multiple languages
  - Provides confidence scoring

- **MockTranscriber.swift**: Testing implementation with configurable behaviors
  - Success/failure scenarios
  - Delayed responses
  - Sequence behaviors
  - Full test tracking

### Supporting Files

- **TranscriberFactory.swift**: Factory pattern for creating transcriber instances
- **AudioUtilities.swift**: Audio processing utilities (in Core directory)

## Usage

### Basic Usage

```swift
// Create a CoreML Whisper transcriber
let transcriber = CoreMLWhisper(modelType: .tiny, modelPath: "/path/to/model.mlmodelc")

// Load the model
try await transcriber.loadModel()

// Transcribe audio
let audioData = Data(...) // 16kHz mono PCM float32
let result = try await transcriber.transcribe(audioData)

print("Text: \(result.text)")
print("Confidence: \(result.confidence)")
```

### Testing with Mock

```swift
// Create a mock transcriber
let mock = MockTranscriber(behavior: .success(text: "Hello, world!", confidence: 0.95))

// Use it like a real transcriber
let result = try await mock.transcribe(audioData)

// Check test state
print("Call count: \(mock.transcribeCallCount)")
print("History: \(mock.transcriptionHistory)")
```

### Using the Factory

```swift
// Create default transcriber
let transcriber = TranscriberFactory.createDefault()

// Create specific type
let whisper = TranscriberFactory.createCoreMLWhisper(model: .base)
let mock = TranscriberFactory.createMock(scenario: .slow)
```

## Model Requirements

The CoreML Whisper implementation requires converted Whisper models in CoreML format:

1. Download OpenAI Whisper models
2. Convert to CoreML using coremltools
3. Place in your app bundle or Documents directory
4. Reference by path when creating CoreMLWhisper instance

## Audio Format

All transcribers expect audio in the following format:
- Sample rate: 16 kHz
- Channels: Mono
- Format: PCM Float32
- Duration: Up to 30 seconds per chunk

Use the `AudioUtilities` class to convert audio to the required format.