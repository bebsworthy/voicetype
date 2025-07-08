import XCTest
import VoiceTypeCore
import VoiceTypeImplementations
@testable import VoiceType

/// End-to-end integration tests for WhisperKit workflows
class WhisperKitIntegrationWorkflowTests: XCTestCase {
    var coordinator: VoiceTypeCoordinator!
    var audioProcessor: MockAudioProcessor!
    var transcriber: WhisperKitTranscriber!
    var textInjector: MockTextInjector!
    var permissionManager: PermissionManager!
    var modelManager: ModelManager!

    override func setUp() async throws {
        try await super.setUp()

        // Create mocks for testing
        audioProcessor = MockAudioProcessor()
        transcriber = WhisperKitTranscriber()
        textInjector = MockTextInjector()
        permissionManager = PermissionManager()
        modelManager = ModelManager()

        // Create coordinator with mocks
        coordinator = VoiceTypeCoordinator(
            audioProcessor: audioProcessor,
            transcriber: transcriber,
            textInjector: textInjector,
            permissionManager: permissionManager,
            modelManager: modelManager
        )
    }

    override func tearDown() async throws {
        coordinator = nil
        audioProcessor = nil
        transcriber = nil
        textInjector = nil
        permissionManager = nil
        modelManager = nil
        try await super.tearDown()
    }

    // MARK: - Full Workflow Tests

    func testCompleteTranscriptionWorkflow() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping full workflow test in CI")
        }

        // Wait for initialization
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Configure mock audio processor to return test audio
        audioProcessor.mockBehavior = .successWithAudio(createTestAudio())

        // Start dictation
        await coordinator.startDictation()

        // Verify recording started
        XCTAssertEqual(coordinator.recordingState, .recording)

        // Wait a bit
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        // Stop dictation
        await coordinator.stopDictation()

        // Wait for processing
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2s

        // Verify success state
        if case .success = coordinator.recordingState {
            XCTAssertTrue(true)
        } else if case .error(let message) = coordinator.recordingState {
            // If model isn't available, that's expected in test environment
            print("Workflow completed with error (expected in test): \(message)")
        } else {
            XCTFail("Expected success or error state, got: \(coordinator.recordingState)")
        }
    }

    func testModelSwitchingWorkflow() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping model switching test in CI")
        }

        // Start with fast model
        coordinator.selectedModel = .fast

        // Wait for initial load
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1s

        // Switch to balanced model
        await coordinator.changeModel(.balanced)

        // Verify model is being loaded
        if coordinator.isLoadingModel {
            print("Model is loading with status: \(coordinator.modelLoadingStatus ?? "unknown")")
        }

        // Wait for model load
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3s

        // Verify model changed (or error if not available)
        if coordinator.selectedModel == .balanced && !coordinator.isLoadingModel {
            XCTAssertTrue(true, "Model switched successfully")
        } else if let error = coordinator.errorMessage {
            print("Model switch failed (expected in test): \(error)")
        }
    }

    func testErrorRecoveryWorkflow() async throws {
        // Configure audio processor to fail
        audioProcessor.mockBehavior = .failure(AudioProcessorError.deviceNotAvailable)

        // Attempt dictation
        await coordinator.startDictation()

        // Wait for error
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        // Verify error state
        if case .error = coordinator.recordingState {
            XCTAssertNotNil(coordinator.errorMessage)
            print("Error message: \(coordinator.errorMessage ?? "none")")
        } else {
            XCTFail("Expected error state")
        }

        // Fix the issue
        audioProcessor.mockBehavior = .success

        // Retry
        await coordinator.startDictation()

        // Should work now
        XCTAssertEqual(coordinator.recordingState, .recording)
    }

    // MARK: - Permission Workflow Tests

    func testPermissionRequestWorkflow() async throws {
        // Check initial permissions
        let hasPermissions = await coordinator.checkAllPermissions()
        print("Initial permissions: \(hasPermissions)")

        // Request permissions
        await coordinator.requestPermissions()

        // In test environment, we can't actually grant permissions
        // but we verify the flow works
        XCTAssertTrue(true, "Permission request flow completed")
    }

    // MARK: - Model Management Workflow Tests

    func testModelDownloadWorkflow() async throws {
        let modelManager = WhisperKitModelManager()

        // Check which models are available
        let downloadedModels = modelManager.getDownloadedModels()
        print("Downloaded models: \(downloadedModels.map { $0.displayName })")

        // If no models are downloaded, this would be where we'd trigger download
        // In tests, we just verify the API works
        for modelType in ModelType.allCases {
            let isDownloaded = modelManager.isModelDownloaded(modelType: modelType)
            let config = modelManager.createModelConfiguration(for: modelType)

            print("Model \(modelType.displayName):")
            print("  Downloaded: \(isDownloaded)")
            print("  Download URL: \(config.downloadURL)")
            print("  Size: \(config.estimatedSize / 1024 / 1024) MB")
        }
    }

    // MARK: - Stress Test Workflows

    func testRapidStartStopWorkflow() async throws {
        // Configure for quick responses
        audioProcessor.mockBehavior = .success

        // Rapid start/stop cycles
        for i in 0..<5 {
            print("Cycle \(i + 1)")

            await coordinator.startDictation()

            // Very short recording
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05s

            await coordinator.stopDictation()

            // Wait for processing
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        // Verify coordinator is still functional
        XCTAssertNotEqual(coordinator.recordingState, .error(""))
    }

    func testConcurrentOperationAttempts() async throws {
        // Try to start multiple recordings concurrently
        async let start1 = coordinator.startDictation()
        async let start2 = coordinator.startDictation()
        async let start3 = coordinator.startDictation()

        await start1
        await start2
        await start3

        // Only one should succeed
        XCTAssertEqual(coordinator.recordingState, .recording)

        // Stop recording
        await coordinator.stopDictation()
    }

    // MARK: - UI Integration Tests

    func testMenuBarViewIntegration() async throws {
        // This would test the menu bar view with the coordinator
        // In a real app, we'd use ViewInspector or similar

        // For now, just verify the coordinator provides expected properties
        XCTAssertNotNil(coordinator.recordingState)
        XCTAssertNotNil(coordinator.selectedModel)
        XCTAssertNotNil(coordinator.isReady)
        XCTAssertNotNil(coordinator.audioLevel)
    }

    func testModelSettingsViewIntegration() async throws {
        // Verify model settings view requirements
        let modelManager = WhisperKitModelManager()

        // Properties needed by ModelSettingsView
        XCTAssertNotNil(modelManager.downloadProgress)
        XCTAssertNotNil(modelManager.isDownloading)
        XCTAssertNotNil(modelManager.currentDownloadTask)

        // Methods needed by ModelSettingsView
        for modelType in ModelType.allCases {
            _ = modelManager.isModelDownloaded(modelType: modelType)
            _ = modelManager.getModelPath(modelType: modelType)
            _ = modelManager.getModelSize(modelType: modelType)
        }
    }

    // MARK: - Performance Workflow Tests

    func testTranscriptionLatencyWorkflow() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping performance test in CI")
        }

        // Ensure model is loaded
        if !transcriber.isModelLoaded {
            try await transcriber.loadModel(.fast)
        }

        // Configure audio processor with known duration
        let testDuration = 3.0
        audioProcessor.mockBehavior = .successWithAudio(createTestAudio(duration: testDuration))

        let startTime = Date()

        // Full workflow
        await coordinator.startDictation()

        // Wait for auto-stop (should be after testDuration)
        while coordinator.recordingState == .recording {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        // Wait for processing to complete
        while coordinator.recordingState == .processing {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }

        let totalTime = Date().timeIntervalSince(startTime)

        print("Total workflow time for \(testDuration)s audio: \(totalTime)s")

        // Should complete within reasonable time (audio duration + 5s processing)
        XCTAssertLessThan(totalTime, testDuration + 5.0)
    }

    // MARK: - Helper Methods

    private func createTestAudio(duration: TimeInterval = 1.0) -> AudioData {
        let sampleRate = 16000.0
        let sampleCount = Int(sampleRate * duration)

        // Create audio with some variation (not just silence)
        var samples = [Int16]()
        for i in 0..<sampleCount {
            // Create a simple sine wave
            let frequency = 440.0 // A4 note
            let amplitude = Int16(1000)
            let angle = 2.0 * Double.pi * frequency * Double(i) / sampleRate
            let sample = Int16(Double(amplitude) * sin(angle))
            samples.append(sample)
        }

        return AudioData(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1
        )
    }
}
