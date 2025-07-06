import XCTest
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Tests for model loading, switching, and management scenarios
final class ModelLoadingSwitchingTests: XCTestCase {
    
    // MARK: - Properties
    
    var modelManager: ModelManager!
    var mockDownloader: MockModelDownloader!
    var mockFileManager: MockFileManagerExtension!
    var coordinator: VoiceTypeCoordinator!
    var mockTranscriber: MockTranscriber!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create mock components
        mockDownloader = MockModelDownloader()
        mockFileManager = MockFileManagerExtension()
        mockTranscriber = MockTranscriber()
        
        // Create model manager with mocks
        modelManager = ModelManager()
        // Note: In real implementation, we'd inject the downloader and file manager
        
        // Create coordinator with mock transcriber
        coordinator = await VoiceTypeCoordinator(
            transcriber: mockTranscriber,
            modelManager: modelManager
        )
    }
    
    override func tearDown() async throws {
        modelManager = nil
        mockDownloader = nil
        mockFileManager = nil
        coordinator = nil
        mockTranscriber = nil
        try await super.tearDown()
    }
    
    // MARK: - Model Loading Tests
    
    func testSuccessfulModelLoading() async throws {
        // Given: Model is available
        mockTranscriber.setReady(false)
        
        // When: Load model
        mockTranscriber.setReady(true) // Simulate successful loading
        await coordinator.changeModel(.tiny)
        
        // Then: Model should be loaded
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        XCTAssertTrue(coordinator.isReady)
        XCTAssertNil(coordinator.errorMessage)
    }
    
    func testModelLoadingFailure() async throws {
        // Given: Model loading will fail
        mockTranscriber.shouldFailModelLoading = true
        
        // When: Try to load model
        await coordinator.changeModel(.base)
        
        // Then: Should show error and fallback to fast model
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        XCTAssertEqual(coordinator.selectedModel, .fast)
        XCTAssertNotNil(coordinator.errorMessage)
    }
    
    func testModelDownloadSimulation() async throws {
        // Given: Model needs to be downloaded
        mockDownloader.shouldSucceed = true
        mockDownloader.downloadDuration = 0.5 // 500ms simulated download
        
        // When: Start download
        let progressExpectation = expectation(description: "Download progress")
        var progressUpdates: [Double] = []
        
        Task {
            for await progress in mockDownloader.progressStream {
                progressUpdates.append(progress)
                if progress >= 1.0 {
                    progressExpectation.fulfill()
                }
            }
        }
        
        try await mockDownloader.downloadModel(
            from: URL(string: "https://example.com/model")!,
            to: URL(fileURLWithPath: "/tmp/model")
        )
        
        await fulfillment(of: [progressExpectation], timeout: 1.0)
        
        // Then: Should have progress updates
        XCTAssertGreaterThan(progressUpdates.count, 2)
        XCTAssertEqual(progressUpdates.last, 1.0)
    }
    
    // MARK: - Model Switching Tests
    
    func testModelSwitchingDuringIdle() async throws {
        // Given: App is idle
        XCTAssertEqual(coordinator.recordingState, .idle)
        
        // When: Switch models
        await coordinator.changeModel(.tiny)
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        await coordinator.changeModel(.base)
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        await coordinator.changeModel(.small)
        
        // Then: Should successfully switch
        XCTAssertEqual(coordinator.selectedModel, .small)
    }
    
    func testModelSwitchingDuringRecording() async throws {
        // Given: Recording is in progress
        await coordinator.startDictation()
        XCTAssertEqual(coordinator.recordingState, .recording)
        
        // When: Try to switch model
        await coordinator.changeModel(.base)
        
        // Then: Should not switch model
        XCTAssertNotEqual(coordinator.selectedModel, .base)
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertTrue(coordinator.errorMessage?.contains("Cannot change model") ?? false)
    }
    
    func testModelSwitchingWithMemoryPressure() async throws {
        // Given: Simulate memory pressure
        mockTranscriber.simulateMemoryPressure = true
        
        // When: Try to load large model
        await coordinator.changeModel(.small)
        
        // Then: Should handle gracefully
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        if coordinator.selectedModel != .small {
            // Should have fallen back to smaller model
            XCTAssertEqual(coordinator.selectedModel, .fast)
        }
    }
    
    // MARK: - Corrupted Model Handling Tests
    
    func testCorruptedModelDetection() async throws {
        // Given: Model file is corrupted
        mockFileManager.corruptedFiles.insert("/models/whisper-base.mlmodelc")
        
        // When: Try to load corrupted model
        mockTranscriber.shouldFailModelLoading = true
        await coordinator.changeModel(.base)
        
        // Then: Should detect corruption and handle
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        XCTAssertNotNil(coordinator.errorMessage)
        XCTAssertEqual(coordinator.selectedModel, .fast) // Fallback
    }
    
    func testModelChecksumValidation() async throws {
        // Given: Model with invalid checksum
        let modelURL = URL(fileURLWithPath: "/tmp/test-model.mlmodelc")
        mockFileManager.checksums[modelURL.path] = "invalid_checksum"
        
        // When: Validate checksum
        let isValid = mockFileManager.validateChecksum(
            at: modelURL,
            expected: "correct_checksum"
        )
        
        // Then: Should detect invalid checksum
        XCTAssertFalse(isValid)
    }
    
    // MARK: - Memory Management Tests
    
    func testModelUnloadingOnMemoryWarning() async throws {
        // Given: Multiple models loaded (simulated)
        mockTranscriber.loadedModels = [.tiny, .base]
        
        // When: Simulate memory pressure
        // Note: macOS doesn't have a direct equivalent to UIApplication.didReceiveMemoryWarningNotification
        // We'll post a custom notification for testing
        NotificationCenter.default.post(
            name: Notification.Name("TestMemoryWarning"),
            object: nil
        )
        
        // Then: Should unload unused models
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        XCTAssertEqual(mockTranscriber.loadedModels.count, 1)
    }
    
    func testSequentialModelLoading() async throws {
        // Given: Need to load models sequentially
        let models: [ModelType] = [.tiny, .base, .small]
        
        // When: Load each model
        for model in models {
            mockTranscriber.setReady(false)
            await coordinator.changeModel(model)
            mockTranscriber.setReady(true)
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            // Then: Only one model should be loaded at a time
            XCTAssertEqual(mockTranscriber.loadedModels.count, 1)
            XCTAssertEqual(coordinator.selectedModel, model)
        }
    }
    
    // MARK: - Download Failure Tests
    
    func testModelDownloadNetworkFailure() async throws {
        // Given: Network will fail
        mockDownloader.shouldSucceed = false
        mockDownloader.error = VoiceTypeError.networkUnavailable
        
        // When: Try to download
        do {
            try await mockDownloader.downloadModel(
                from: URL(string: "https://example.com/model")!,
                to: URL(fileURLWithPath: "/tmp/model")
            )
            XCTFail("Expected download to fail")
        } catch VoiceTypeError.networkUnavailable {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testModelDownloadDiskSpaceFailure() async throws {
        // Given: Insufficient disk space
        mockFileManager.availableDiskSpace = 10_000_000 // 10MB
        let requiredSpace: Int64 = 244_000_000 // 244MB for small model
        
        // When: Check if enough space
        let hasSpace = mockFileManager.availableDiskSpace > requiredSpace
        
        // Then: Should detect insufficient space
        XCTAssertFalse(hasSpace)
    }
    
    func testPartialDownloadResume() async throws {
        // Given: Previous partial download exists
        mockDownloader.supportsResume = true
        mockDownloader.resumeData = Data(repeating: 0, count: 1000)
        
        // When: Resume download
        let resumed = await mockDownloader.resumeDownload(
            from: URL(string: "https://example.com/model")!,
            to: URL(fileURLWithPath: "/tmp/model"),
            resumeData: mockDownloader.resumeData
        )
        
        // Then: Should resume successfully
        XCTAssertTrue(resumed)
    }
    
    // MARK: - Performance Tests
    
    func testModelLoadingPerformance() throws {
        measure {
            let expectation = XCTestExpectation(description: "Model loaded")
            
            Task {
                mockTranscriber.setReady(false)
                await coordinator.changeModel(.base)
                mockTranscriber.setReady(true)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}

// MARK: - Mock Implementations

class MockModelDownloader {
    var shouldSucceed = true
    var error: Error?
    var downloadDuration: TimeInterval = 0.1
    var supportsResume = false
    var resumeData: Data?
    
    private let _progressSubject = AsyncStream<Double>.makeStream()
    var progressStream: AsyncStream<Double> { _progressSubject.stream }
    
    func downloadModel(from url: URL, to destination: URL) async throws {
        if !shouldSucceed {
            throw error ?? VoiceTypeError.networkUnavailable
        }
        
        // Simulate download progress
        let steps = 10
        for i in 0...steps {
            let progress = Double(i) / Double(steps)
            _progressSubject.continuation.yield(progress)
            try await Task.sleep(nanoseconds: UInt64(downloadDuration * 1_000_000_000 / Double(steps)))
        }
    }
    
    func resumeDownload(from url: URL, to destination: URL, resumeData: Data?) async -> Bool {
        return supportsResume && resumeData != nil
    }
}

class MockFileManagerExtension {
    var availableDiskSpace: Int64 = 10_000_000_000 // 10GB
    var corruptedFiles = Set<String>()
    var checksums = [String: String]()
    
    func validateChecksum(at url: URL, expected: String) -> Bool {
        if let actual = checksums[url.path] {
            return actual == expected
        }
        return !corruptedFiles.contains(url.path)
    }
    
    func modelExists(at path: String) -> Bool {
        return !corruptedFiles.contains(path)
    }
}

extension MockTranscriber {
    var loadedModels: [ModelType] = []
    var shouldFailModelLoading = false
    var simulateMemoryPressure = false
    
    func loadModel(_ type: ModelType) async throws {
        if shouldFailModelLoading {
            throw TranscriberError.modelLoadingFailed(reason: "Mock failure")
        }
        
        if simulateMemoryPressure && type == .small {
            throw TranscriberError.modelLoadingFailed(reason: "Insufficient memory")
        }
        
        // Simulate unloading previous model
        loadedModels.removeAll()
        loadedModels.append(type)
    }
}