# Getting Started with VoiceType Development

Welcome to VoiceType development! This guide will help you set up your development environment, build the project, and start contributing.

## Prerequisites

### System Requirements
- **macOS**: 12.0 (Monterey) or later
- **Xcode**: 15.0 or later (for Swift 5.9+)
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 2GB free space for models and development

### Required Tools
- **Swift**: 5.9 or later (included with Xcode)
- **Git**: For version control
- **SwiftFormat**: For code formatting (optional but recommended)

## Setting Up Your Development Environment

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/VoiceType.git
cd VoiceType
```

### 2. Install Development Tools

#### Install SwiftFormat (Optional)
```bash
brew install swiftformat
```

#### Install SwiftLint (Optional)
```bash
brew install swiftlint
```

### 3. Run Setup Script

VoiceType includes convenience scripts for common tasks:

```bash
./Scripts/setup.sh
```

This will:
- Check system requirements
- Install recommended tools
- Configure git hooks
- Download required models (fast model)

## Building from Source

### Using Swift Package Manager (Recommended)

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests
swift test

# Generate Xcode project (optional)
swift package generate-xcodeproj
```

### Using Xcode

1. Open `Package.swift` in Xcode
2. Select the "VoiceType" scheme
3. Choose your target device (Mac)
4. Press ⌘B to build

### Using Make

VoiceType includes a Makefile for common tasks:

```bash
# Build debug version
make build

# Build release version
make release

# Run tests
make test

# Clean build artifacts
make clean

# Format code
make format
```

## Running VoiceType

### From Command Line

```bash
# Run debug build
swift run VoiceType

# Run release build
.build/release/VoiceType
```

### From Xcode

1. Select the "VoiceType" scheme
2. Press ⌘R to run
3. The app will launch with console output in Xcode

### Debug vs Release

- **Debug**: Includes assertions, debug symbols, and verbose logging
- **Release**: Optimized for performance, minimal logging

## Project Structure

```
VoiceType/
├── Package.swift           # SPM manifest
├── Makefile               # Build shortcuts
├── Scripts/               # Development scripts
│   ├── setup.sh          # Initial setup
│   ├── build.sh          # Build helper
│   ├── test.sh           # Test runner
│   └── format.sh         # Code formatting
│
├── Sources/              # Source code
│   ├── Core/            # Core protocols and models
│   ├── Implementations/ # Concrete implementations
│   ├── UI/              # SwiftUI views
│   └── VoiceType/       # App entry point
│
├── Tests/               # Test suites
│   ├── CoreTests/
│   ├── IntegrationTests/
│   └── PerformanceTests/
│
├── Resources/           # App resources
│   ├── Assets/
│   └── Models/         # ML models
│
└── Documentation/       # Documentation
    └── DeveloperGuide/
```

## Development Workflow

### 1. Create a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Make Your Changes

Follow the coding guidelines:
- Use meaningful variable names
- Add documentation comments
- Write tests for new features
- Keep commits focused and atomic

### 3. Run Tests

```bash
# Run all tests
swift test

# Run specific test
swift test --filter TestClassName

# Run with coverage
swift test --enable-code-coverage
```

### 4. Format Your Code

```bash
# Format all Swift files
./Scripts/format.sh

# Or use make
make format
```

### 5. Build and Test

```bash
# Full build and test
make all

# Just build
make build

# Just test
make test
```

### 6. Debug Configuration

#### Enable Verbose Logging

```swift
// In AppDelegate.swift or VoiceTypeApp.swift
UserDefaults.standard.set(true, forKey: "VoiceTypeDebugLogging")
```

#### Console Output

View detailed logs in Console.app:
1. Open Console.app
2. Filter by "VoiceType"
3. Watch real-time logs

#### Xcode Debugging

Set breakpoints in key areas:
- `VoiceTypeCoordinator.startDictation()`
- `AudioProcessor.startRecording()`
- `Transcriber.transcribe()`
- `TextInjector.inject()`

## Common Development Tasks

### Adding a New Protocol Implementation

1. Create your implementation file:
```swift
// Sources/Implementations/MyCustomTranscriber.swift
import Foundation

class MyCustomTranscriber: Transcriber {
    // Implement all required protocol methods
}
```

2. Register with factory (if applicable):
```swift
// In TranscriberFactory.swift
static func createCustom() -> Transcriber {
    return MyCustomTranscriber()
}
```

3. Add tests:
```swift
// Tests/CoreTests/MyCustomTranscriberTests.swift
import XCTest
@testable import VoiceTypeCore

class MyCustomTranscriberTests: XCTestCase {
    // Write comprehensive tests
}
```

### Working with ML Models

1. **Download Models**:
```bash
# Use the model download script
./Scripts/download-models.sh
```

2. **Convert Models** (if needed):
```python
# Example: Convert Whisper to CoreML
python Scripts/convert-whisper-to-coreml.py \
    --model-size base \
    --output-dir Resources/Models/
```

3. **Test Model Loading**:
```swift
let modelPath = Bundle.main.path(forResource: "whisper-base", 
                                ofType: "mlmodelc")!
let transcriber = CoreMLWhisper(modelType: .base, 
                               modelPath: modelPath)
try await transcriber.loadModel()
```

### Debugging Tips

#### Audio Issues
```swift
// Enable audio debugging
AudioProcessor.enableDebugMode = true

// Check audio levels
audioProcessor.audioLevelChanged.sink { level in
    print("Audio level: \(level)")
}
```

#### Transcription Issues
```swift
// Enable transcription debugging
Transcriber.enableVerboseLogging = true

// Test with known audio
let testAudio = AudioData.silence(duration: 1.0)
let result = try await transcriber.transcribe(testAudio)
```

#### Permission Issues
```swift
// Check permission status
print("Microphone: \(permissionManager.microphonePermission)")
print("Accessibility: \(permissionManager.hasAccessibilityPermission())")

// Force permission prompts
await permissionManager.requestMicrophonePermission()
```

## Testing Guidelines

### Unit Tests
- Test each component in isolation
- Use mock implementations
- Cover edge cases and error conditions
- Aim for >80% code coverage

### Integration Tests
- Test component interactions
- Verify complete workflows
- Test error recovery paths
- Use real implementations where possible

### Performance Tests
- Measure critical operations
- Set baseline metrics
- Monitor for regressions
- Test with real-world data

### Running Tests

```bash
# All tests
swift test

# Specific test file
swift test --filter VoiceTypeCoordinatorTests

# With verbose output
swift test --verbose

# Generate coverage report
swift test --enable-code-coverage
xcrun llvm-cov report \
    .build/debug/VoiceTypePackageTests.xctest/Contents/MacOS/VoiceTypePackageTests \
    -instr-profile .build/debug/codecov/default.profdata
```

## Troubleshooting

### Common Issues

#### Build Failures

**Problem**: `Package.swift` manifest parse error
```bash
error: manifest parse error(s):
```
**Solution**: Ensure you have Swift 5.9+ installed

**Problem**: Missing dependencies
```bash
error: no such module 'AVFoundation'
```
**Solution**: Clean and rebuild
```bash
swift package clean
swift build
```

#### Runtime Issues

**Problem**: "No AI models available"
- Run `./Scripts/setup.sh` to download models
- Check `~/Library/Application Support/VoiceType/Models/`
- Verify model file permissions

**Problem**: "Microphone permission denied"
- Open System Preferences → Privacy & Security → Microphone
- Enable VoiceType
- Restart the app

**Problem**: "Text injection failed"
- Check Accessibility permissions
- Try clipboard fallback mode
- Verify target app is supported

### Debug Tools

#### Logging System

```swift
// Enable debug logging
Logger.setLevel(.debug)

// Custom log categories
Logger.log(.audio, "Starting recording")
Logger.log(.transcription, "Processing audio")
Logger.log(.injection, "Injecting text")
```

#### Performance Profiling

1. Open Xcode
2. Product → Profile (⌘I)
3. Choose instrument:
   - Time Profiler: CPU usage
   - Allocations: Memory usage
   - Energy Log: Power consumption

## Next Steps

Now that you have VoiceType running:

1. **Read the Architecture Guide**: Understand the system design
2. **Explore the API Reference**: Learn about available protocols and components
3. **Try the Examples**: See how components work together
4. **Contribute**: Pick an issue and start coding!

### Useful Resources

- [Architecture Guide](Architecture.md)
- [API Reference](APIReference.md)
- [Plugin Development](PluginDevelopment.md)
- [Contributing Guidelines](Contributing.md)

### Getting Help

- **GitHub Issues**: Bug reports and feature requests
- **Discussions**: General questions and ideas
- **Wiki**: Additional documentation and guides
- **Discord**: Real-time chat with developers

Happy coding! 🚀