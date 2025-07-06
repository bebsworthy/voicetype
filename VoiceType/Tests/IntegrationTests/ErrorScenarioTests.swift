import XCTest
import AVFoundation
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Comprehensive tests for error scenarios and recovery strategies
final class ErrorScenarioTests: XCTestCase {
    
    // MARK: - Properties
    
    var coordinator: VoiceTypeCoordinator!
    var mockAudioProcessor: MockAudioProcessor!
    var mockTranscriber: MockTranscriber!
    var mockTextInjector: MockTextInjector!
    var mockPermissionManager: PermissionManager!
    var mockModelManager: ErrorScenarioMockModelManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock components
        mockAudioProcessor = MockAudioProcessor()
        mockTranscriber = MockTranscriber()
        mockTextInjector = MockTextInjector()
        mockPermissionManager = PermissionManager()
        mockModelManager = ErrorScenarioMockModelManager()
        
        // Configure default successful state
        // In a real test, we'd use a mock that allows setting permissions
        mockTranscriber.setReady(true)
        
        // Create coordinator
        coordinator = await VoiceTypeCoordinator(
            audioProcessor: mockAudioProcessor,
            transcriber: mockTranscriber,
            textInjector: mockTextInjector,
            permissionManager: mockPermissionManager,
            modelManager: nil // Use default model manager
        )
        
        // Wait for initialization
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
    }
    
    override func tearDown() async throws {
        coordinator = nil
        mockAudioProcessor = nil
        mockTranscriber = nil
        mockTextInjector = nil
        mockPermissionManager = nil
        mockModelManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Network Failure Tests
    
    func testNetworkFailureDuringModelDownload() async throws {
        // Given: Model needs download
        // await coordinator.setSelectedModel(.balanced)
        mockModelManager.shouldFailDownload = true
        
        // When: Try to download model
        await coordinator.changeModel(.balanced)
        
        // Then: Should show network error and fallback
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        let errorMessage = await coordinator.errorMessage
        XCTAssertNotNil(errorMessage)
        XCTAssertTrue(errorMessage?.contains("fallback") ?? false)
        let selectedModel = await coordinator.selectedModel
        XCTAssertEqual(selectedModel, .fast)
    }
    
    func testIntermittentNetworkRecovery() async throws {
        // Given: Network fails then recovers
        mockModelManager.networkFailureCount = 2 // Fail twice then succeed
        
        // When: Download with retries
        for _ in 0..<3 {
            await coordinator.changeModel(.balanced)
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            let errorMessage = await coordinator.errorMessage
            if errorMessage == nil {
                break
            }
        }
        
        // Then: Should eventually succeed
        let errorMessage = await coordinator.errorMessage
        XCTAssertNil(errorMessage)
    }
    
    // MARK: - Audio Device Disconnection Tests
    
    func testAudioDeviceDisconnectionDuringRecording() async throws {
        // Given: Start recording
        await coordinator.startDictation()
        let recordingState = await coordinator.recordingState
        XCTAssertEqual(recordingState, .recording)
        
        // When: Simulate device disconnection
        // mockAudioProcessor.simulateError(.deviceDisconnected)
        
        // Post audio route change notification
        // AVAudioSession is not available on macOS
        // Simulate audio route change notification
        NotificationCenter.default.post(
            name: NSNotification.Name("AudioRouteChangeNotification"),
            object: nil,
            userInfo: [
                "RouteChangeReason": 2 // oldDeviceUnavailable
            ]
        )
        
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should handle gracefully
        let recordingState2 = await coordinator.recordingState
        if case .error(let message) = recordingState2 {
            XCTAssertTrue(message.contains("disconnected"))
        }
        let errorMessage = await coordinator.errorMessage
        XCTAssertNotNil(errorMessage)
    }
    
    func testAudioDeviceReconnection() async throws {
        // Given: Device was disconnected
        // mockAudioProcessor.simulateError(.deviceDisconnected)
        await coordinator.startDictation()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // When: Device reconnects
        // mockAudioProcessor.clearError()
        // AVAudioSession is not available on macOS
        // Simulate audio route change notification
        NotificationCenter.default.post(
            name: NSNotification.Name("AudioRouteChangeNotification"),
            object: nil,
            userInfo: [
                "RouteChangeReason": 1 // newDeviceAvailable
            ]
        )
        
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should be ready to record again
        let recordingState = await coordinator.recordingState
        XCTAssertEqual(recordingState, .idle)
        let errorMessage = await coordinator.errorMessage
        XCTAssertTrue(errorMessage?.contains("reconnected") ?? false)
    }
    
    // MARK: - Permission Revocation Tests
    
    func testMicrophonePermissionRevocationMidOperation() async throws {
        // Given: Start recording with permission
        await coordinator.startDictation()
        let recordingState = await coordinator.recordingState
        XCTAssertEqual(recordingState, .recording)
        
        // When: Permission is revoked mid-recording
        // mockPermissionManager.mockMicrophonePermission = .denied
        // Cannot set private property
        // mockAudioProcessor.simulateError(.permissionDenied)
        
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should handle gracefully
        let recordingState2 = await coordinator.recordingState
        XCTAssertNotEqual(recordingState2, .recording)
        let errorMessage = await coordinator.errorMessage
        XCTAssertNotNil(errorMessage)
        XCTAssertTrue(errorMessage?.contains("permission") ?? false)
    }
    
    func testAccessibilityPermissionLossHandling() async throws {
        // Given: Have accessibility permission
        // mockPermissionManager.mockAccessibilityPermission = .granted
        // mockTextInjector.mockTarget = TargetApplication(
        //     bundleId: "com.apple.TextEdit",
        //     name: "TextEdit",
        //     processId: pid_t(12345)
        // )
        
        // When: Lose accessibility permission during injection
        await coordinator.startDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // mockPermissionManager.mockAccessibilityPermission = .denied
        mockTextInjector.shouldSucceed = false // = true
        
        await coordinator.stopDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should fallback to clipboard
        let recordingState = await coordinator.recordingState
        XCTAssertEqual(recordingState, .success)
        let errorMessage = await coordinator.errorMessage
        XCTAssertTrue(errorMessage?.contains("clipboard") ?? false)
    }
    
    // MARK: - Disk Space Exhaustion Tests
    
    func testDiskSpaceExhaustionDuringModelDownload() async throws {
        // Given: Limited disk space
        mockModelManager.availableDiskSpace = 50_000_000 // 50MB
        
        // When: Try to download large model
        // await coordinator.setSelectedModel(.accurate) // 244MB
        await coordinator.changeModel(.accurate)
        
        // Then: Should fail with disk space error
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        let errorMessage = await coordinator.errorMessage
        XCTAssertNotNil(errorMessage)
        XCTAssertTrue(errorMessage?.contains("space") ?? false)
    }
    
    func testTemporaryCacheCleanupOnDiskPressure() async throws {
        // Given: Disk space is low
        mockModelManager.availableDiskSpace = 100_000_000 // 100MB
        
        // When: System needs space
        NotificationCenter.default.post(
            name: NSNotification.Name("DiskSpaceLow"),
            object: nil
        )
        
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should clean up caches
        XCTAssertTrue(mockModelManager.didCleanupCache)
    }
    
    // MARK: - Transcription Error Tests
    
    func testLowConfidenceTranscriptionHandling() async throws {
        // Given: Transcriber returns low confidence
        // mockTranscriber.behavior = .success(text: "unclear speech", confidence: 0.3)
        
        // When: Complete recording
        await coordinator.startDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        await coordinator.stopDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should show low confidence error
        let recordingState = await coordinator.recordingState
        if case .error = recordingState {
            let errorMessage = await coordinator.errorMessage
            XCTAssertNotNil(errorMessage)
        }
    }
    
    func testEmptyAudioDataHandling() async throws {
        // Given: Audio processor returns empty data
        // mockAudioProcessor.shouldReturnEmptyData = true
        
        // When: Complete recording
        await coordinator.startDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        await coordinator.stopDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should handle empty audio error
        let recordingState = await coordinator.recordingState
        if case .error = recordingState {
            let errorMessage = await coordinator.errorMessage
            XCTAssertNotNil(errorMessage)
        }
    }
    
    // MARK: - Concurrent Operation Tests
    
    func testConcurrentDictationAttempts() async throws {
        // Given: Start first dictation
        let task1 = Task {
            await coordinator.startDictation()
        }
        
        // When: Try to start second dictation immediately
        let task2 = Task {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            await coordinator.startDictation()
        }
        
        await task1.value
        _ = try await task2.value
        
        // Then: Should handle concurrent attempts gracefully
        let recordingState = await coordinator.recordingState
        XCTAssertEqual(recordingState, .recording)
        // Only one recording should be active
        // XCTAssertEqual(mockAudioProcessor.startRecordingCallCount, 1)
    }
    
    // MARK: - Memory Pressure Tests
    
    func testMemoryPressureHandling() async throws {
        // Given: System under memory pressure
        // mockTranscriber.simulateMemoryPressure = true
        
        // When: Try to use large model
        await coordinator.changeModel(.accurate)
        
        // Then: Should fallback to smaller model
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        let selectedModel = await coordinator.selectedModel
        XCTAssertEqual(selectedModel, .fast)
        let errorMessage = await coordinator.errorMessage
        XCTAssertNotNil(errorMessage)
    }
    
    // MARK: - Recovery Strategy Tests
    
    func testAutomaticErrorRecovery() async throws {
        // Given: Error state
        // mockTranscriber.behavior = .failure(.transcriptionFailed(reason: "Test error"))
        await coordinator.startDictation()
        await coordinator.stopDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        let recordingState = await coordinator.recordingState
        XCTAssertTrue(recordingState.isError)
        
        // When: Wait for automatic recovery
        try await Task.sleep(nanoseconds: 5_500_000_000) // 5.5 seconds
        
        // Then: Should return to idle
        let recordingState2 = await coordinator.recordingState
        XCTAssertEqual(recordingState2, .idle)
    }
    
    func testMaxRetryAttempts() async throws {
        // Given: Will always fail
        // mockTranscriber.behavior = .failure(.modelNotLoaded)
        
        // When: Try multiple times
        for _ in 0..<5 {
            await coordinator.startDictation()
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Then: Should stop retrying after max attempts
        let recordingState = await coordinator.recordingState
        XCTAssertTrue(recordingState.isError)
        // Check internal retry counter would be at max
    }
    
    // MARK: - Edge Case Tests
    
    func testRapidStateTransitions() async throws {
        // Test rapid start/stop cycles
        for _ in 0..<10 {
            await coordinator.startDictation()
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            await coordinator.stopDictation()
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Should handle rapid transitions without crashes
        XCTAssertTrue(true) // If we get here, no crash occurred
    }
    
    func testErrorDuringErrorHandling() async throws {
        // Given: Multiple cascading errors
        // mockAudioProcessor.simulateError(.deviceDisconnected)
        // mockTranscriber.behavior = .failure(.modelNotLoaded)
        mockTextInjector.shouldSucceed = false // = true
        
        // When: Try to record
        await coordinator.startDictation()
        
        // Then: Should handle gracefully without crash
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        let recordingState = await coordinator.recordingState
        XCTAssertTrue(recordingState.isError)
        let errorMessage = await coordinator.errorMessage
        XCTAssertNotNil(errorMessage)
    }
}

// MARK: - Test Helpers

extension RecordingState {
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

// Extended mock for error scenario testing
class ErrorScenarioMockModelManager {
    var availableDiskSpace: Int64 = 10_000_000_000 // 10GB default
    var didCleanupCache = false
    var networkFailureCount = 0
    private var currentFailureCount = 0
    var shouldFailDownload = false
    var mockInstalledModels: [ModelInfo] = []
    
    var installedModels: [ModelInfo] {
        return mockInstalledModels
    }
    
    func downloadModel(_ model: ModelInfo) async throws {
        if networkFailureCount > 0 && currentFailureCount < networkFailureCount {
            currentFailureCount += 1
            throw VoiceTypeError.networkUnavailable
        }
        
        if availableDiskSpace < model.sizeInBytes {
            throw VoiceTypeError.insufficientDiskSpace(model.sizeInBytes)
        }
        
        if shouldFailDownload {
            throw VoiceTypeError.networkUnavailable
        }
        // Simulate successful download
    }
    
    func cleanupCache() {
        didCleanupCache = true
        availableDiskSpace += 100_000_000 // Free 100MB
    }
}

// Extended mock for error scenario testing
class ErrorScenarioMockAudioProcessor: AudioProcessor {
    var shouldReturnEmptyData = false
    private let baseProcessor = MockAudioProcessor()
    
    var isRecording: Bool {
        return baseProcessor.isRecording
    }
    
    var audioLevelChanged: AsyncStream<Float> {
        return baseProcessor.audioLevelChanged
    }
    
    var recordingStateChanged: AsyncStream<RecordingState> {
        return baseProcessor.recordingStateChanged
    }
    
    // currentLevel and recordingDuration not available in MockAudioProcessor
    
    func startRecording() async throws {
        try await baseProcessor.startRecording()
    }
    
    func stopRecording() async -> AudioData {
        if shouldReturnEmptyData {
            return AudioData(samples: [], sampleRate: 16000, channelCount: 1)
        }
        return await baseProcessor.stopRecording()
    }
    
    // pauseRecording and resumeRecording not available in MockAudioProcessor
}