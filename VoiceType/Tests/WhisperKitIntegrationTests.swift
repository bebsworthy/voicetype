import XCTest
import VoiceTypeCore
import VoiceTypeImplementations
@testable import VoiceType

/// Integration tests for WhisperKit functionality
class WhisperKitIntegrationTests: XCTestCase {
    var transcriber: WhisperKitTranscriber!
    var modelManager: WhisperKitModelManager!

    override func setUp() async throws {
        try await super.setUp()
        transcriber = WhisperKitTranscriber()
        modelManager = WhisperKitModelManager()
    }

    override func tearDown() async throws {
        transcriber = nil
        modelManager = nil
        try await super.tearDown()
    }

    // MARK: - Model Loading Tests

    func testModelLoading() async throws {
        // Skip if running in CI without models
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping model loading test in CI environment")
        }

        // Test loading the fast model
        do {
            try await transcriber.loadModel(.fast)
            XCTAssertTrue(transcriber.isModelLoaded, "Model should be loaded")
            XCTAssertEqual(transcriber.modelInfo.type, .fast)
        } catch {
            XCTFail("Failed to load model: \(error)")
        }
    }

    func testModelInfo() async throws {
        // Test model info before loading
        let infoBeforeLoad = transcriber.modelInfo
        XCTAssertFalse(infoBeforeLoad.isLoaded)
        XCTAssertEqual(infoBeforeLoad.sizeInBytes, 0)

        // Skip actual loading in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            return
        }

        // Load model and check info
        try await transcriber.loadModel(.fast)
        let infoAfterLoad = transcriber.modelInfo
        XCTAssertTrue(infoAfterLoad.isLoaded)
        XCTAssertEqual(infoAfterLoad.type, .fast)
        XCTAssertGreaterThan(infoAfterLoad.sizeInBytes, 0)
    }

    // MARK: - Transcription Tests

    func testTranscriptionWithMockAudio() async throws {
        // Skip if no model available
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping transcription test in CI environment")
        }

        // Load model first
        try await transcriber.loadModel(.fast)

        // Create mock audio data (1 second of silence)
        let sampleRate = 16000.0
        let duration = 1.0
        let sampleCount = Int(sampleRate * duration)
        let samples = [Int16](repeating: 0, count: sampleCount)

        let audioData = AudioData(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1
        )

        // Test transcription
        do {
            let result = try await transcriber.transcribe(audioData, language: .english)
            XCTAssertNotNil(result)
            XCTAssertNotNil(result.text)
            XCTAssertGreaterThanOrEqual(result.confidence, 0.0)
            XCTAssertLessThanOrEqual(result.confidence, 1.0)
        } catch {
            XCTFail("Transcription failed: \(error)")
        }
    }

    func testTranscriptionWithoutModel() async throws {
        // Ensure no model is loaded
        XCTAssertFalse(transcriber.isModelLoaded)

        // Create mock audio
        let audioData = AudioData(
            samples: [Int16(0)],
            sampleRate: 16000,
            channelCount: 1
        )

        // Attempt transcription without model
        do {
            _ = try await transcriber.transcribe(audioData, language: nil)
            XCTFail("Expected transcription to fail without model")
        } catch TranscriberError.modelNotLoaded {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Model Management Tests

    func testModelDownloadCheck() {
        // Test checking if models are downloaded
        let isFastDownloaded = modelManager.isModelDownloaded(modelType: .fast)
        let isBalancedDownloaded = modelManager.isModelDownloaded(modelType: .balanced)
        let isAccurateDownloaded = modelManager.isModelDownloaded(modelType: .accurate)

        // Log results (don't assert as models may or may not be present)
        print("Fast model downloaded: \(isFastDownloaded)")
        print("Balanced model downloaded: \(isBalancedDownloaded)")
        print("Accurate model downloaded: \(isAccurateDownloaded)")
    }

    func testModelPaths() {
        // Test getting model paths
        if let fastPath = modelManager.getModelPath(modelType: .fast) {
            XCTAssertTrue(fastPath.path.contains("whisper-tiny"))
        }

        if let balancedPath = modelManager.getModelPath(modelType: .balanced) {
            XCTAssertTrue(balancedPath.path.contains("whisper-base"))
        }

        if let accuratePath = modelManager.getModelPath(modelType: .accurate) {
            XCTAssertTrue(accuratePath.path.contains("whisper-small"))
        }
    }

    // MARK: - Factory Tests

    func testTranscriberFactory() {
        // Test creating WhisperKit transcriber through factory
        let transcriber = TranscriberFactory.createWhisperKit()
        XCTAssertNotNil(transcriber)
        XCTAssertTrue(transcriber is WhisperKitTranscriber)

        // Test default creation uses WhisperKit
        TranscriberFactory.configure(TranscriberFactory.Configuration(useMockForTesting: false, useWhisperKit: true))
        let defaultTranscriber = TranscriberFactory.createDefault()
        XCTAssertTrue(defaultTranscriber is WhisperKitTranscriber)
    }

    func testFactoryConfiguration() {
        // Test mock configuration
        var config = TranscriberFactory.Configuration()
        config.useMockForTesting = true
        TranscriberFactory.configure(config)

        let mockTranscriber = TranscriberFactory.createDefault()
        XCTAssertTrue(mockTranscriber is MockTranscriber)

        // Test WhisperKit disabled
        config.useMockForTesting = false
        config.useWhisperKit = false
        TranscriberFactory.configure(config)

        let coreMLTranscriber = TranscriberFactory.createDefault()
        XCTAssertTrue(coreMLTranscriber is CoreMLWhisper)
    }
}

// MARK: - Performance Tests

extension WhisperKitIntegrationTests {
    func testTranscriptionPerformance() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping performance test in CI environment")
        }

        // Load model
        try await transcriber.loadModel(.fast)

        // Create 5 seconds of mock audio
        let sampleRate = 16000.0
        let duration = 5.0
        let samples = [Int16](repeating: 0, count: Int(sampleRate * duration))
        let audioData = AudioData(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1
        )

        // Measure transcription time
        let startTime = Date()
        _ = try await transcriber.transcribe(audioData, language: .english)
        let elapsedTime = Date().timeIntervalSince(startTime)

        print("Transcription took \(elapsedTime) seconds for \(duration) seconds of audio")

        // Fast model should process 5 seconds in under 2 seconds
        XCTAssertLessThan(elapsedTime, 2.0, "Transcription should be faster than real-time")
    }
}
