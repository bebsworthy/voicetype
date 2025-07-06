import XCTest
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

/// End-to-end workflow tests for complete dictation flow
final class EndToEndWorkflowTests: XCTestCase {
    
    // MARK: - Properties
    
    var coordinator: VoiceTypeCoordinator!
    var mockAudioProcessor: MockAudioProcessor!
    var mockTranscriber: MockTranscriber!
    var mockTextInjector: MockTextInjector!
    var mockPermissionManager: MockPermissionManager!
    var mockHotkeyManager: MockHotkeyManager!
    var mockModelManager: MockModelManager!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock components
        mockAudioProcessor = MockAudioProcessor()
        mockTranscriber = MockTranscriber()
        mockTextInjector = MockTextInjector()
        mockPermissionManager = MockPermissionManager()
        mockHotkeyManager = MockHotkeyManager()
        mockModelManager = MockModelManager()
        
        // Configure mock behaviors
        mockPermissionManager.mockMicrophonePermission = .granted
        mockPermissionManager.mockAccessibilityPermission = .granted
        mockTranscriber.behavior = .success(text: "Test transcription", confidence: 0.95)
        mockTranscriber.setReady(true)
        
        // Create coordinator with mocks
        coordinator = await VoiceTypeCoordinator(
            audioProcessor: mockAudioProcessor,
            transcriber: mockTranscriber,
            textInjector: mockTextInjector,
            permissionManager: mockPermissionManager,
            hotkeyManager: mockHotkeyManager,
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
        mockHotkeyManager = nil
        mockModelManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Complete Workflow Tests
    
    func testCompleteHappyPathWorkflow() async throws {
        // Given: App is ready, permissions granted
        mockTextInjector.mockTarget = TargetApplication(
            bundleIdentifier: "com.apple.TextEdit",
            name: "TextEdit",
            isActive: true,
            supportsTextInput: true
        )
        
        // When: Start dictation
        await coordinator.startDictation()
        
        // Then: Should be recording
        XCTAssertEqual(coordinator.recordingState, .recording)
        XCTAssertTrue(mockAudioProcessor.isRecording)
        
        // When: Stop dictation after some time
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms
        await coordinator.stopDictation()
        
        // Then: Should process and inject text
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms for processing
        
        XCTAssertEqual(coordinator.recordingState, .success)
        XCTAssertEqual(coordinator.lastTranscription, "Test transcription")
        XCTAssertEqual(mockTextInjector.lastInjectedText, "Test transcription")
        XCTAssertEqual(mockTextInjector.injectCallCount, 1)
    }
    
    func testHotkeyTriggeredWorkflow() async throws {
        // Given: Hotkey is registered
        let hotkeyExpectation = expectation(description: "Hotkey triggered")
        
        mockHotkeyManager.onRegisterHandler = { identifier, keyCombo, handler in
            // Simulate hotkey press
            Task {
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                handler()
                hotkeyExpectation.fulfill()
            }
        }
        
        // When: Register hotkey
        try mockHotkeyManager.registerHotkey(
            identifier: "test",
            keyCombo: "ctrl+shift+v"
        ) { }
        
        await fulfillment(of: [hotkeyExpectation], timeout: 1.0)
        
        // Then: Should start recording
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        XCTAssertEqual(coordinator.recordingState, .recording)
    }
    
    func testAutoStopAfterMaxDuration() async throws {
        // Given: Start recording
        await coordinator.startDictation()
        XCTAssertEqual(coordinator.recordingState, .recording)
        
        // When: Wait for auto-stop (5 seconds in real app, but mocked here)
        mockAudioProcessor.simulateAutoStop(after: 0.5) // 500ms for test
        
        // Then: Should automatically stop and process
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        XCTAssertNotEqual(coordinator.recordingState, .recording)
        XCTAssertFalse(mockAudioProcessor.isRecording)
    }
    
    // MARK: - Permission Denial Recovery Tests
    
    func testMicrophonePermissionDenialRecovery() async throws {
        // Given: Microphone permission denied
        mockPermissionManager.mockMicrophonePermission = .denied
        
        // When: Try to start dictation
        await coordinator.startDictation()
        
        // Then: Should show error
        XCTAssertEqual(coordinator.recordingState, .error("Microphone permission required"))
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertTrue(coordinator.errorMessage?.contains("Microphone permission") ?? false)
        
        // When: Grant permission and retry
        mockPermissionManager.mockMicrophonePermission = .granted
        await coordinator.requestPermissions()
        await coordinator.startDictation()
        
        // Then: Should work normally
        XCTAssertEqual(coordinator.recordingState, .recording)
    }
    
    func testAccessibilityPermissionFallback() async throws {
        // Given: Accessibility permission denied
        mockPermissionManager.mockAccessibilityPermission = .denied
        mockTextInjector.shouldFailInjection = true
        
        // When: Complete recording workflow
        await coordinator.startDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        await coordinator.stopDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should fallback to clipboard
        XCTAssertEqual(coordinator.recordingState, .success)
        XCTAssertTrue(coordinator.errorMessage?.contains("clipboard") ?? false)
        // Note: Can't test actual clipboard in unit tests
    }
    
    // MARK: - Error Handling Tests
    
    func testRecoveryFromAudioDeviceDisconnection() async throws {
        // Given: Start recording
        await coordinator.startDictation()
        XCTAssertEqual(coordinator.recordingState, .recording)
        
        // When: Simulate device disconnection
        mockAudioProcessor.simulateError(.deviceDisconnected)
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should show appropriate error
        if case .error(let message) = coordinator.recordingState {
            XCTAssertTrue(message.contains("disconnected"))
        } else {
            XCTFail("Expected error state")
        }
    }
    
    func testRecoveryFromTranscriptionFailure() async throws {
        // Given: Transcriber will fail
        mockTranscriber.behavior = .failure(.transcriptionFailed(reason: "Test failure"))
        
        // When: Complete recording
        await coordinator.startDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        await coordinator.stopDictation()
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Should show error
        if case .error = coordinator.recordingState {
            XCTAssertNotNil(coordinator.errorMessage)
        } else {
            XCTFail("Expected error state")
        }
    }
    
    func testNetworkFailureHandling() async throws {
        // Given: Model needs download but network fails
        mockModelManager.shouldFailDownload = true
        coordinator.selectedModel = .balanced // Not embedded
        
        // When: Try to load model
        await coordinator.changeModel(.balanced)
        
        // Then: Should fallback to fast model
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        XCTAssertEqual(coordinator.selectedModel, .fast)
        XCTAssertTrue(coordinator.errorMessage?.contains("fallback") ?? false)
    }
    
    // MARK: - State Transition Tests
    
    func testValidStateTransitions() async throws {
        // Test idle -> recording
        await coordinator.startDictation()
        XCTAssertEqual(coordinator.recordingState, .recording)
        
        // Test recording -> processing
        await coordinator.stopDictation()
        // Brief moment should be in processing
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        
        // Test processing -> success
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        XCTAssertEqual(coordinator.recordingState, .success)
        
        // Test success -> idle (after timeout)
        try await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
        XCTAssertEqual(coordinator.recordingState, .idle)
    }
    
    func testInvalidStateTransitions() async throws {
        // Given: In processing state
        await coordinator.startDictation()
        await coordinator.stopDictation()
        
        // When: Try to start recording while processing
        await coordinator.startDictation()
        
        // Then: Should not change state
        XCTAssertNotEqual(coordinator.recordingState, .recording)
    }
    
    // MARK: - Performance Tests
    
    func testWorkflowPerformance() throws {
        measure {
            let expectation = XCTestExpectation(description: "Workflow complete")
            
            Task {
                await coordinator.startDictation()
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                await coordinator.stopDictation()
                try await Task.sleep(nanoseconds: 200_000_000) // 200ms
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}

// MARK: - Mock Implementations

class MockPermissionManager: PermissionManager {
    var mockMicrophonePermission: PermissionState = .granted
    var mockAccessibilityPermission: PermissionState = .granted
    
    override func checkMicrophonePermission() {
        microphonePermission = mockMicrophonePermission
    }
    
    override func hasAccessibilityPermission() -> Bool {
        accessibilityPermission = mockAccessibilityPermission
        return mockAccessibilityPermission == .granted
    }
    
    override func requestMicrophonePermission() async -> Bool {
        microphonePermission = mockMicrophonePermission
        return mockMicrophonePermission == .granted
    }
}

// Simple mock that doesn't inherit from HotkeyManager to avoid property override issues
class MockHotkeyManager {
    var registeredHotkeys: [(identifier: String, keyCombo: String, handler: () -> Void)] = []
    var onRegisterHandler: ((String, String, @escaping () -> Void) -> Void)?
    
    func registerHotkey(identifier: String, keyCombo: String, action: @escaping () -> Void) throws {
        registeredHotkeys.append((identifier, keyCombo, action))
        onRegisterHandler?(identifier, keyCombo, action)
    }
    
    func unregisterHotkey(identifier: String) {
        registeredHotkeys.removeAll { $0.identifier == identifier }
    }
    
    func simulateHotkeyPress(identifier: String) {
        if let hotkey = registeredHotkeys.first(where: { $0.identifier == identifier }) {
            hotkey.handler()
        }
    }
}

// Simple mock that doesn't inherit from ModelManager to avoid async init issues
class MockModelManager {
    var mockInstalledModels: [ModelInfo] = [
        ModelInfo(
            type: .fast,
            version: "1.0",
            path: URL(fileURLWithPath: "/tmp/whisper-tiny.mlmodelc"),
            sizeInBytes: 39_000_000,
            isLoaded: true,
            lastUsed: Date()
        )
    ]
    var shouldFailDownload = false
    
    var installedModels: [ModelInfo] {
        return mockInstalledModels
    }
    
    func downloadModel(_ model: ModelInfo) async throws {
        if shouldFailDownload {
            throw VoiceTypeError.networkUnavailable
        }
        // Simulate successful download
    }
}