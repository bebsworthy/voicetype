# WhisperKit Integration Feature Specification

## Overview

This feature replaces the current mock/placeholder transcription implementation with WhisperKit, a production-ready speech recognition framework optimized for Apple Silicon. WhisperKit provides complete speech-to-text functionality with support for multiple model sizes, real-time streaming, and offline operation.

## Architecture

### Technology Stack

- **Speech Recognition**: WhisperKit v0.9.0+ (Swift native, CoreML-based)
- **Model Management**: WhisperKit model downloading and caching
- **Audio Processing**: Integration with existing AVFoundationAudio
- **Streaming Support**: AudioStreamTranscriber for real-time feedback
- **Platform Requirements**: macOS 14.0+, iOS 17.0+

### Key Components

- **WhisperKitTranscriber**: New implementation of Transcriber protocol using WhisperKit
- **WhisperKitModelManager**: Handles WhisperKit model downloads and management
- **StreamingTranscriptionHandler**: Manages real-time transcription with progress updates
- **ModelMigration**: Converts existing model preferences to WhisperKit models

## Implementation Strategy

### Phase 1: Core Integration

1. **Add WhisperKit Dependency**
   - Add Swift Package dependency to project
   - Configure build settings for WhisperKit
   - Update minimum deployment target if needed

2. **Implement WhisperKitTranscriber**
   - Create new class conforming to Transcriber protocol
   - Map VoiceType ModelType to WhisperKit models
   - Handle model loading and initialization
   - Implement transcribe methods for AudioData

3. **Update TranscriberFactory**
   - Replace mock implementation with WhisperKitTranscriber
   - Maintain fallback to mock for testing

### Phase 2: Model Management

1. **WhisperKit Model Integration**
   - Map existing model types to WhisperKit variants:
     - `.fast` → WhisperKit tiny model
     - `.balanced` → WhisperKit base model  
     - `.accurate` → WhisperKit small model
   - Implement model download through WhisperKit

2. **Update ModelManager**
   - Detect and migrate existing CoreML models
   - Use WhisperKit's built-in model management
   - Update storage paths and model info

3. **Migration Strategy**
   - Check for existing downloaded models
   - Provide migration path or clean download
   - Update user preferences

### Phase 3: Advanced Features

1. **Streaming Transcription**
   - Implement AudioStreamTranscriber integration
   - Add real-time transcription callbacks
   - Update UI for streaming feedback

2. **Enhanced Features**
   - Add word-level timestamps
   - Implement confidence scores
   - Support language detection
   - Add Voice Activity Detection (VAD)

## Component Architecture

### WhisperKitTranscriber

```swift
public class WhisperKitTranscriber: Transcriber {
    private var whisperKit: WhisperKit?
    private var streamTranscriber: AudioStreamTranscriber?
    
    // Implement Transcriber protocol
    func transcribe(_ audio: AudioData, language: Language?) async throws -> TranscriptionResult
    func loadModel(_ type: ModelType) async throws
    
    // WhisperKit specific
    func transcribeWithStream(_ audio: AudioData, onPartialResult: @escaping (String) -> Void) async throws -> TranscriptionResult
}
```

### Model Mapping

| VoiceType Model | WhisperKit Model | Size | Notes |
|-----------------|------------------|------|-------|
| .fast | openai_whisper-tiny | ~39MB | Fastest, basic accuracy |
| .balanced | openai_whisper-base | ~74MB | Good balance |
| .accurate | openai_whisper-small | ~244MB | Best accuracy |

### Audio Data Flow

```
AVFoundationAudio → AudioData → WhisperKitTranscriber → WhisperKit → TranscriptionResult
                                        ↓
                              AudioStreamTranscriber (optional)
                                        ↓
                              Real-time callbacks
```

## Migration Plan

### From Current Implementation

1. **Preserve User Experience**
   - Maintain existing hotkey functionality
   - Keep current UI/UX unchanged initially
   - Ensure smooth transition

2. **Model Migration**
   - Detect existing CoreML models
   - Offer to download WhisperKit versions
   - Clean up old model files

3. **Settings Migration**
   - Map existing model preferences
   - Preserve language settings
   - Update configuration files

## Testing Strategy

### Unit Tests
- WhisperKitTranscriber implementation
- Model mapping and loading
- Audio data conversion
- Error handling

### Integration Tests
- End-to-end transcription flow
- Model switching
- Streaming transcription
- Performance benchmarks

### Performance Targets
- Model loading: < 2 seconds
- Transcription latency: < 500ms for 5s audio
- Memory usage: < 500MB with largest model
- Real-time factor: > 5x (5s audio in < 1s)

## Error Handling

### Model Loading Errors
- Model not found → Download automatically
- Insufficient space → Show storage dialog
- Corrupted model → Re-download

### Transcription Errors
- Audio too short → Minimum duration warning
- No speech detected → VAD feedback
- Language mismatch → Auto-detect option

## Security & Privacy

- All processing remains on-device
- No audio data sent to servers
- Model downloads over HTTPS
- Verify model checksums

## Future Enhancements

1. **Custom Models**
   - Support for fine-tuned models
   - Hugging Face model integration
   - User-provided model paths

2. **Advanced Features**
   - Speaker diarization (Pro version)
   - Punctuation restoration
   - Custom vocabulary support

3. **Platform Expansion**
   - iOS/iPadOS support
   - Apple Watch complications
   - Siri Shortcuts integration