# Contributing to VoiceType

Thank you for your interest in contributing to VoiceType! This guide will help you get started with contributing to the project.

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct:

- **Be respectful**: Treat everyone with respect and kindness
- **Be constructive**: Provide helpful feedback and suggestions
- **Be inclusive**: Welcome newcomers and help them get started
- **Be professional**: Keep discussions focused on the project

## How to Contribute

### Reporting Issues

Found a bug or have a feature request? Here's how to report it effectively:

1. **Check existing issues** first to avoid duplicates
2. **Use issue templates** when available
3. **Provide clear descriptions** including:
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - System information (macOS version, hardware)
   - Error messages or logs
   - Screenshots if applicable

#### Bug Report Example

```markdown
## Description
VoiceType crashes when switching models during transcription.

## Steps to Reproduce
1. Start recording with Cmd+Shift+V
2. While recording, open settings
3. Change model from "Fast" to "Accurate"
4. App crashes immediately

## Expected Behavior
Model change should be queued until recording completes.

## System Information
- macOS: 14.0 (Sonoma)
- Mac: MacBook Pro M2
- VoiceType: 1.0.0
- Memory: 16GB

## Error Log
```
Thread 1: EXC_BAD_ACCESS (code=1, address=0x0)
```
```

### Suggesting Features

When proposing new features:

1. **Explain the problem** the feature solves
2. **Describe your solution** clearly
3. **Consider alternatives** you've thought about
4. **Show examples** if possible

#### Feature Request Example

```markdown
## Problem
Users need to dictate in multiple languages within the same session.

## Proposed Solution
Add a language switcher in the menu bar dropdown that allows
quick language changes without opening settings.

## Alternatives Considered
- Automatic language detection (may be less reliable)
- Keyboard shortcuts for each language (too many shortcuts)

## Mockup
[Include a simple sketch or description of the UI]
```

## Development Process

### 1. Fork and Clone

```bash
# Fork on GitHub, then:
git clone https://github.com/yourusername/VoiceType.git
cd VoiceType
git remote add upstream https://github.com/VoiceType/VoiceType.git
```

### 2. Create a Branch

```bash
# For features
git checkout -b feature/your-feature-name

# for Bug fixes
git checkout -b fix/issue-description

# For documentation
git checkout -b docs/what-you-are-documenting
```

### 3. Make Your Changes

Follow our coding standards:

#### Swift Style Guide

```swift
// MARK: - Good Examples

// Use descriptive names
func transcribeAudioData(_ data: AudioData) async throws -> String {
    // Implementation
}

// Group related functionality
extension VoiceTypeCoordinator {
    // MARK: - Public Methods
    
    public func startDictation() async {
        // Clear function with single responsibility
    }
    
    // MARK: - Private Methods
    
    private func validatePermissions() async -> Bool {
        // Helper methods should be private
    }
}

// Use guard for early returns
guard let model = currentModel else {
    throw VoiceTypeError.modelNotLoaded
}

// Prefer async/await over callbacks
func loadModel() async throws {
    // Modern concurrency
}

// MARK: - Bad Examples

// Avoid abbreviations
func trnscrbAud(_ d: Data) -> String { } // ❌

// Don't nest too deeply
if condition1 {
    if condition2 {
        if condition3 { // ❌ Too nested
            // ...
        }
    }
}

// Avoid force unwrapping
let value = optionalValue! // ❌ Dangerous
```

#### Documentation Standards

```swift
/// Transcribes audio data to text using the specified language model.
/// 
/// This method processes raw audio data through the loaded ML model to
/// produce a text transcription. The audio should be 16kHz mono PCM format.
///
/// - Parameters:
///   - audio: The audio data to transcribe, must be 16kHz mono PCM
///   - language: Optional language hint for better accuracy. If nil, auto-detects
/// - Returns: The transcribed text string
/// - Throws: 
///   - `TranscriptionError.modelNotLoaded` if no model is loaded
///   - `TranscriptionError.invalidAudioFormat` if audio format is incorrect
///   - `TranscriptionError.transcriptionFailed` if the model fails to process
/// 
/// - Note: This method may take several seconds for longer audio clips
/// - SeeAlso: `loadModel(_:)`, `AudioData`
public func transcribe(
    _ audio: AudioData,
    language: Language? = nil
) async throws -> String {
    // Implementation
}
```

### 4. Write Tests

Every contribution must include tests:

#### Unit Test Example

```swift
import XCTest
@testable import VoiceTypeCore

final class TranscriberTests: XCTestCase {
    var transcriber: MockTranscriber!
    
    override func setUp() {
        super.setUp()
        transcriber = MockTranscriber()
    }
    
    override func tearDown() {
        transcriber = nil
        super.tearDown()
    }
    
    func testSuccessfulTranscription() async throws {
        // Arrange
        let testAudio = AudioData.createTestTone(frequency: 440, duration: 1.0)
        transcriber.setBehavior(.success(text: "Hello, world!", confidence: 0.95))
        
        // Act
        let result = try await transcriber.transcribe(testAudio, language: .english)
        
        // Assert
        XCTAssertEqual(result.text, "Hello, world!")
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.language, .english)
    }
    
    func testTranscriptionWithLowConfidence() async throws {
        // Test edge cases
        transcriber.setBehavior(.success(text: "unclear", confidence: 0.3))
        
        let result = try await transcriber.transcribe(AudioData.empty, language: nil)
        
        XCTAssertLessThan(result.confidence, 0.5)
    }
    
    func testModelNotLoadedError() async {
        // Test error handling
        transcriber.setBehavior(.error(.modelNotLoaded))
        
        do {
            _ = try await transcriber.transcribe(AudioData.empty, language: nil)
            XCTFail("Expected error but succeeded")
        } catch VoiceTypeError.modelNotLoaded {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
```

#### Integration Test Example

```swift
func testCompleteWorkflow() async throws {
    // Create components
    let audioProcessor = MockAudioProcessor()
    let transcriber = MockTranscriber()
    let textInjector = MockTextInjector()
    
    let coordinator = VoiceTypeCoordinator(
        audioProcessor: audioProcessor,
        transcriber: transcriber,
        textInjector: textInjector
    )
    
    // Configure mocks
    audioProcessor.mockAudioData = AudioData.createSpeechSample("Hello, VoiceType!")
    transcriber.setBehavior(.success(text: "Hello, VoiceType!", confidence: 0.92))
    textInjector.mockTarget = TargetApplication.textEdit
    
    // Run workflow
    await coordinator.startDictation()
    
    // Wait for recording to complete
    try await Task.sleep(nanoseconds: 1_000_000_000)
    
    await coordinator.stopDictation()
    
    // Verify results
    XCTAssertEqual(coordinator.lastTranscription, "Hello, VoiceType!")
    XCTAssertEqual(textInjector.lastInjectedText, "Hello, VoiceType!")
    XCTAssertEqual(coordinator.recordingState, .success)
}
```

### 5. Update Documentation

If your changes affect the API or user experience:

1. Update relevant documentation
2. Add code examples
3. Update README if needed
4. Add to CHANGELOG

### 6. Submit Pull Request

#### Pre-submission Checklist

- [ ] Code follows style guidelines
- [ ] All tests pass (`swift test`)
- [ ] New tests added for new features
- [ ] Documentation updated
- [ ] Code is formatted (`make format`)
- [ ] No warnings in Xcode
- [ ] Commit messages are clear

#### PR Template

```markdown
## Description
Brief description of your changes.

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] My code follows the project's style guidelines
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
```

## Commit Message Guidelines

We follow the Conventional Commits specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: New feature
- **fix**: Bug fix
- **docs**: Documentation changes
- **style**: Code style changes (formatting, etc)
- **refactor**: Code refactoring
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Maintenance tasks

### Examples

```bash
# Feature
git commit -m "feat(transcriber): add support for Japanese language"

# Bug fix
git commit -m "fix(audio): prevent crash when microphone disconnects"

# Documentation
git commit -m "docs(api): update AudioProcessor protocol documentation"

# With body
git commit -m "feat(injector): add VS Code specific text injector

- Implements custom injector for VS Code
- Uses VS Code extension API when available
- Falls back to keyboard simulation
- Adds configuration for injection delay

Closes #123"
```

## Code Review Process

### For Contributors

1. **Be patient**: Reviews may take a few days
2. **Be responsive**: Address feedback promptly
3. **Be open**: Consider reviewer suggestions
4. **Be thorough**: Test reviewer-requested changes

### For Reviewers

1. **Be kind**: Remember there's a person behind the code
2. **Be specific**: Provide actionable feedback
3. **Be thorough**: Check code, tests, and documentation
4. **Be timely**: Try to review within 2-3 days

#### Review Checklist

- [ ] Code quality and style
- [ ] Test coverage and quality
- [ ] Documentation completeness
- [ ] Performance implications
- [ ] Security considerations
- [ ] Breaking changes
- [ ] Error handling

## Testing Requirements

### Coverage Goals

- **Unit Tests**: >80% coverage
- **Integration Tests**: Critical paths covered
- **Performance Tests**: No regressions

### Running Tests

```bash
# All tests
make test

# With coverage
swift test --enable-code-coverage

# Specific test
swift test --filter TranscriberTests

# Performance tests
swift test --filter Performance
```

### Writing Good Tests

1. **Test behavior, not implementation**
2. **Use descriptive test names**
3. **Follow AAA pattern** (Arrange, Act, Assert)
4. **Test edge cases**
5. **Keep tests isolated**
6. **Use mocks appropriately**

## Performance Guidelines

### Optimization Rules

1. **Measure first**: Profile before optimizing
2. **User-facing first**: Prioritize visible improvements
3. **Memory efficiency**: Minimize allocations
4. **Async operations**: Use async/await properly
5. **Lazy loading**: Load resources on demand

### Performance Testing

```swift
func testTranscriptionPerformance() throws {
    let audioData = AudioData.createLongSample(duration: 30.0)
    let transcriber = CoreMLWhisper()
    
    measure {
        let expectation = expectation(description: "Transcription")
        
        Task {
            _ = try await transcriber.transcribe(audioData, language: .english)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
}
```

## Security Guidelines

### Security Checklist

- [ ] No hardcoded credentials
- [ ] Input validation on all public APIs
- [ ] No arbitrary code execution
- [ ] Respect sandbox restrictions
- [ ] Secure data storage
- [ ] Privacy-preserving design

### Reporting Security Issues

**Do not** report security issues publicly. Instead:

1. Email security@voicetype.io
2. Include detailed description
3. Provide proof of concept if possible
4. Allow time for fix before disclosure

## Release Process

### Version Numbering

We use Semantic Versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

1. [ ] All tests pass
2. [ ] Documentation updated
3. [ ] CHANGELOG updated
4. [ ] Version bumped
5. [ ] Release notes drafted
6. [ ] Binary signed and notarized

## Getting Help

### Resources

- **Documentation**: Read the guides in `/Documentation`
- **Examples**: Check `/Examples` directory
- **Issues**: Search existing issues
- **Discussions**: Ask in GitHub Discussions

### Communication Channels

- **GitHub Issues**: Bugs and features
- **GitHub Discussions**: Questions and ideas
- **Discord**: Real-time chat
- **Email**: contact@voicetype.io

## Recognition

Contributors are recognized in:

- CONTRIBUTORS.md file
- Release notes
- Project website
- Annual contributor report

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see LICENSE file).

---

Thank you for contributing to VoiceType! Your efforts help make voice-to-text accessible to everyone. 🎙️✨