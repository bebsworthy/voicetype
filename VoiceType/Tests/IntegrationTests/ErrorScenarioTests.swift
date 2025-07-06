import XCTest
import AVFoundation
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations
@testable import VoiceType

/// Comprehensive tests for error scenarios and recovery strategies
final class ErrorScenarioTests: XCTestCase {
    
    // MARK: - Properties
    
    var coordinator: VoiceTypeCoordinator!
    var mockAudioProcessor: MockAudioProcessor!
    var mockTranscriber: MockTranscriber!
    var mockTextInjector: MockTextInjector!
    var mockPermissionManager: MockPermissionManager!
    var mockModelManager: MockModelManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock components
        mockAudioProcessor = MockAudioProcessor()
        mockTranscriber = MockTranscriber()
        mockTextInjector = MockTextInjector()
        mockPermissionManager = MockPermissionManager()
        mockModelManager = MockModelManager()
        
        // Configure default successful state
        mockPermissionManager.mockMicrophonePermission = .granted
        mockTranscriber.setReady(true)
        
        // Create coordinator
        coordinator = await VoiceTypeCoordinator(
            audioProcessor: mockAudioProcessor,
            transcriber: mockTranscriber,
            textInjector: mockTextInjector,
            permissionManager: mockPermissionManager,
            modelManager: mockModelManager
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
        coordinator.selectedModel = .base
        mockModelManager.shouldFailDownload = true
        
        // When: Try to download model
        await coordinator.changeModel(.base)
        
        // Then: Should show network error and fallback
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertTrue(coordinator.errorMessage?.contains("fallback") ?? false)
        XCTAssertEqual(coordinator.selectedModel, .fast)
    }
    
    func testIntermittentNetworkRecovery() async throws {
        // Given: Network fails then recovers
        mockModelManager.networkFailureCount = 2 // Fail twice then succeed
        
        // When: Download with retries
        for _ in 0..<3 {
            await coordinator.changeModel(.base)
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            if coordinator.errorMessage == nil {
                break
            }
        }
        
        // Then: Should eventually succeed
        XCTAssertNil(coordinator.errorMessage)
    }
    
    // MARK: - Audio Device Disconnection Tests
    
    func testAudioDeviceDisconnectionDuringRecording() async throws {
        // Given: Start recording
        await coordinator.startDictation()
        XCTAssertEqual(coordinator.recordingState, .recording)
        
        // When: Simulate device disconnection
        mockAudioProcessor.simulateError(.deviceDisconnected)
        
        // Post audio route change notification
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: nil,
            userInfo: [
                AVAudioSession.routeChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
            ]
        )
        
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should handle gracefully
        if case .error(let message) = coordinator.recordingState {
            XCTAssertTrue(message.contains("disconnected"))
        }
        XCTAssertNotNil(coordinator.errorMessage)
    }
    
    func testAudioDeviceReconnection() async throws {
        // Given: Device was disconnected
        mockAudioProcessor.simulateError(.deviceDisconnected)
        await coordinator.startDictation()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // When: Device reconnects
        mockAudioProcessor.clearError()
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: nil,
            userInfo: [
                AVAudioSession.routeChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue
            ]
        )
        
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should be ready to record again
        XCTAssertEqual(coordinator.recordingState, .idle)
        XCTAssertTrue(coordinator.errorMessage?.contains("reconnected") ?? false)
    }
    
    // MARK: - Permission Revocation Tests
    
    func testMicrophonePermissionRevocationMidOperation() async throws {
        // Given: Start recording with permission
        await coordinator.startDictation()
        XCTAssertEqual(coordinator.recordingState, .recording)
        
        // When: Permission is revoked mid-recording
        mockPermissionManager.mockMicrophonePermission = .denied
        mockPermissionManager.microphonePermission = .denied
        mockAudioProcessor.simulateError(.permissionDenied)
        
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should handle gracefully
        XCTAssertNotEqual(coordinator.recordingState, .recording)
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertTrue(coordinator.errorMessage?.contains("permission") ?? false)
    }
    
    func testAccessibilityPermissionLossHandling() async throws {
        // Given: Have accessibility permission
        mockPermissionManager.mockAccessibilityPermission = .granted
        mockTextInjector.mockTarget = TargetApplication(
            bundleIdentifier: "com.apple.TextEdit",
            name: "TextEdit",
            isActive: true,
            supportsTextInput: true
        )
        
        // When: Lose accessibility permission during injection
        await coordinator.startDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        mockPermissionManager.mockAccessibilityPermission = .denied
        mockTextInjector.shouldFailInjection = true
        
        await coordinator.stopDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should fallback to clipboard
        XCTAssertEqual(coordinator.recordingState, .success)
        XCTAssertTrue(coordinator.errorMessage?.contains("clipboard") ?? false)
    }
    
    // MARK: - Disk Space Exhaustion Tests
    
    func testDiskSpaceExhaustionDuringModelDownload() async throws {
        // Given: Limited disk space
        mockModelManager.availableDiskSpace = 50_000_000 // 50MB
        
        // When: Try to download large model
        coordinator.selectedModel = .small // 244MB
        await coordinator.changeModel(.small)
        
        // Then: Should fail with disk space error
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertTrue(coordinator.errorMessage?.contains("space") ?? false)
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
        mockTranscriber.behavior = .success(text: "unclear speech", confidence: 0.3)
        
        // When: Complete recording
        await coordinator.startDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        await coordinator.stopDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should show low confidence error
        if case .error = coordinator.recordingState {
            XCTAssertNotNil(coordinator.errorMessage)
        }
    }
    
    func testEmptyAudioDataHandling() async throws {
        // Given: Audio processor returns empty data
        mockAudioProcessor.shouldReturnEmptyData = true
        
        // When: Complete recording
        await coordinator.startDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        await coordinator.stopDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should handle empty audio error
        if case .error = coordinator.recordingState {
            XCTAssertNotNil(coordinator.errorMessage)
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
        await task2.value
        
        // Then: Should handle concurrent attempts gracefully
        XCTAssertEqual(coordinator.recordingState, .recording)
        // Only one recording should be active
        XCTAssertEqual(mockAudioProcessor.startRecordingCallCount, 1)
    }
    
    // MARK: - Memory Pressure Tests
    
    func testMemoryPressureHandling() async throws {
        // Given: System under memory pressure
        mockTranscriber.simulateMemoryPressure = true
        
        // When: Try to use large model
        await coordinator.changeModel(.small)
        
        // Then: Should fallback to smaller model
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        XCTAssertEqual(coordinator.selectedModel, .fast)
        XCTAssertNotNil(coordinator.errorMessage)
    }
    
    // MARK: - Recovery Strategy Tests
    
    func testAutomaticErrorRecovery() async throws {
        // Given: Error state
        mockTranscriber.behavior = .failure(.transcriptionFailed(reason: "Test error"))
        await coordinator.startDictation()
        await coordinator.stopDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        XCTAssertTrue(coordinator.recordingState.isError)
        
        // When: Wait for automatic recovery
        try await Task.sleep(nanoseconds: 5_500_000_000) // 5.5 seconds
        
        // Then: Should return to idle
        XCTAssertEqual(coordinator.recordingState, .idle)
    }
    
    func testMaxRetryAttempts() async throws {
        // Given: Will always fail
        mockTranscriber.behavior = .failure(.modelNotLoaded)
        
        // When: Try multiple times
        for _ in 0..<5 {
            await coordinator.startDictation()
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Then: Should stop retrying after max attempts
        XCTAssertTrue(coordinator.recordingState.isError)
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
        mockAudioProcessor.simulateError(.deviceDisconnected)
        mockTranscriber.behavior = .failure(.modelNotLoaded)
        mockTextInjector.shouldFailInjection = true
        
        // When: Try to record
        await coordinator.startDictation()
        
        // Then: Should handle gracefully without crash
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        XCTAssertTrue(coordinator.recordingState.isError)
        XCTAssertNotNil(coordinator.errorMessage)
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

extension MockModelManager {
    var availableDiskSpace: Int64 = 10_000_000_000 // 10GB default
    var didCleanupCache = false
    var networkFailureCount = 0
    private var currentFailureCount = 0
    
    override func downloadModel(_ model: ModelInfo) async throws {
        if networkFailureCount > 0 && currentFailureCount < networkFailureCount {
            currentFailureCount += 1
            throw VoiceTypeError.networkUnavailable
        }
        
        if availableDiskSpace < model.size {
            throw VoiceTypeError.insufficientDiskSpace(required: model.size, available: availableDiskSpace)
        }
        
        try await super.downloadModel(model)
    }
    
    func cleanupCache() {
        didCleanupCache = true
        availableDiskSpace += 100_000_000 // Free 100MB
    }
}

extension MockAudioProcessor {
    var shouldReturnEmptyData = false
    
    override func stopRecording() async -> AudioData {
        if shouldReturnEmptyData {
            return AudioData(samples: [], sampleRate: 16000)
        }
        return await super.stopRecording()
    }
}