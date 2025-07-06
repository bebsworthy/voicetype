# VoiceType Integration Tests

This directory contains comprehensive integration tests for the VoiceType MVP project. These tests verify the complete functionality of the application by testing the interaction between all components.

## Test Structure

### Test Categories

1. **End-to-End Workflow Tests** (`EndToEndWorkflowTests.swift`)
   - Complete dictation flow (hotkey → record → transcribe → inject)
   - Model switching during operation
   - Permission denial recovery flows
   - Error handling scenarios
   - State transition validation

2. **Target Application Compatibility Tests** (`TargetApplicationCompatibilityTests.swift`)
   - Test injection into different app types (TextEdit, Notes, Terminal, Safari, VS Code)
   - Fallback behavior validation
   - App-specific injector tests
   - Unsupported application handling

3. **Model Loading and Switching Tests** (`ModelLoadingSwitchingTests.swift`)
   - Model download simulation
   - Switching between models
   - Corrupted model handling
   - Memory management during switches
   - Disk space validation

4. **Error Scenario Tests** (`ErrorScenarioTests.swift`)
   - Network failures during download
   - Audio device disconnection
   - Permission revocation mid-operation
   - Disk space exhaustion
   - Concurrent operation handling
   - Memory pressure scenarios

5. **Test Utilities** (`TestUtilities.swift`)
   - Mock implementations for external dependencies
   - Test data generators
   - Performance measurement helpers
   - Memory tracking utilities
   - Network simulation tools

## Running Tests

### All Tests
```bash
swift test --filter VoiceTypePackageTests.IntegrationTests
```

### Specific Test Category
```bash
swift test --filter EndToEndWorkflowTests
swift test --filter TargetApplicationCompatibilityTests
swift test --filter ModelLoadingSwitchingTests
swift test --filter ErrorScenarioTests
```

### Single Test
```bash
swift test --filter testCompleteHappyPathWorkflow
```

## CI/CD Integration

The tests are designed to run in CI/CD pipelines with different configurations:

### Smoke Tests (Quick validation)
```bash
swift test --filter IntegrationTestSuite/testCompleteUserJourney
```

### Pull Request Tests
```bash
swift test --filter "EndToEndWorkflowTests|TargetApplicationCompatibilityTests"
```

### Pre-Release Tests (Comprehensive)
```bash
swift test --filter IntegrationTests
```

### Performance Tests
```bash
swift test --filter "testWorkflowPerformance|testInjectionPerformance|testModelLoadingPerformance"
```

## Test Plans

### GitHub Actions Configuration

```yaml
- name: Run Integration Tests
  run: |
    swift test \
      --filter IntegrationTests \
      --parallel \
      --enable-code-coverage
  env:
    CI: true
    TEST_ENVIRONMENT: ci
```

### Xcode Configuration

1. Open `VoiceType.xcodeproj`
2. Select the test target
3. Press `Cmd+U` to run all tests
4. Or use Test Navigator to run specific tests

## Performance Benchmarks

Expected performance targets:

- **Complete dictation flow**: < 5 seconds
- **Model loading**: < 2 seconds for embedded models
- **Text injection**: < 100ms
- **Memory usage**: < 100MB during operation
- **Concurrent operations**: Handle 20 rapid cycles without failure

## Mock Implementations

The test suite includes comprehensive mocks for all external dependencies:

- `MockAudioProcessor`: Simulates audio recording with configurable behaviors
- `MockTranscriber`: Provides predictable transcription results
- `MockTextInjector`: Simulates text injection without actual UI interaction
- `MockPermissionManager`: Controls permission states for testing
- `MockHotkeyManager`: Simulates hotkey registration and triggers
- `MockModelManager`: Manages model availability and download simulation

## Test Data

### Audio Samples
The test utilities can generate:
- Clean audio at various frequencies
- Noisy audio with configurable noise levels
- Empty audio data for error testing
- Long audio samples for performance testing

### Transcription Results
Mock transcriber can produce:
- Successful transcriptions with configurable confidence
- Failed transcriptions with specific error types
- Delayed results for timeout testing
- Sequences of different behaviors

## Debugging Failed Tests

### Enable Verbose Logging
```swift
// In test setup
TestUtilities.enableVerboseLogging = true
```

### Check Test Reports
Test results are saved to:
- Xcode: `DerivedData/.../Logs/Test/`
- CI: Check artifacts in GitHub Actions

### Common Issues

1. **Timeout Errors**
   - Increase timeout values in CI environment
   - Check `CICDTestConfiguration.Environment.timeoutMultiplier`

2. **Permission Errors**
   - Ensure mock permissions are properly configured
   - Check `MockPermissionManager` setup

3. **State Transition Failures**
   - Verify state machine logic in `VoiceTypeCoordinator`
   - Check async timing with `TestUtilities.waitForState`

## Contributing

When adding new integration tests:

1. Choose the appropriate test file based on functionality
2. Use existing mock implementations when possible
3. Add performance measurements for critical operations
4. Ensure tests can run in parallel without interference
5. Document any special requirements or setup

## Test Coverage

Current coverage targets:
- End-to-end workflows: > 90%
- Error handling: > 95%
- State transitions: 100%
- Component interactions: > 85%

Run coverage report:
```bash
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/VoiceTypePackageTests.xctest/Contents/MacOS/VoiceTypePackageTests
```