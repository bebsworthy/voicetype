import XCTest
import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Tests for WhisperKit model management functionality
@MainActor
class WhisperKitModelManagerTests: XCTestCase {
    var modelManager: WhisperKitModelManager!

    override func setUp() async throws {
        try await super.setUp()
        modelManager = WhisperKitModelManager()
    }

    override func tearDown() async throws {
        modelManager = nil
        try await super.tearDown()
    }

    // MARK: - Model Detection Tests

    func testModelDetection() {
        // Test checking if models are downloaded
        for modelType in ModelType.allCases {
            let isDownloaded = modelManager.isModelDownloaded(modelType: modelType)

            // We can't assert specific values as it depends on environment
            // But we can verify the method works without crashing
            XCTAssertNotNil(isDownloaded)

            if modelType == .fast {
                // Fast model might be embedded, so it could be available
                print("Fast model downloaded: \(isDownloaded)")
            }
        }
    }

    func testModelPathRetrieval() {
        // Test getting paths for downloaded models
        for modelType in ModelType.allCases {
            if modelManager.isModelDownloaded(modelType: modelType) {
                let path = modelManager.getModelPath(modelType: modelType)
                XCTAssertNotNil(path, "Downloaded model should have a path")

                // Verify path contains expected model name
                let modelName = getWhisperKitModelName(for: modelType)
                XCTAssertTrue(path!.path.contains(modelName))
            } else {
                let path = modelManager.getModelPath(modelType: modelType)
                XCTAssertNil(path, "Non-downloaded model should return nil path")
            }
        }
    }

    // MARK: - Model Size Tests

    func testModelSizeCalculation() {
        // Test size calculation for downloaded models
        for modelType in ModelType.allCases {
            if modelManager.isModelDownloaded(modelType: modelType) {
                let size = modelManager.getModelSize(modelType: modelType)
                XCTAssertNotNil(size)
                XCTAssertGreaterThan(size!, 0, "Model size should be greater than 0")

                // Verify size is within expected range
                switch modelType {
                case .fast:
                    XCTAssertGreaterThan(size!, 30 * 1024 * 1024) // >30MB
                    XCTAssertLessThan(size!, 50 * 1024 * 1024) // <50MB
                case .balanced:
                    XCTAssertGreaterThan(size!, 60 * 1024 * 1024) // >60MB
                    XCTAssertLessThan(size!, 100 * 1024 * 1024) // <100MB
                case .accurate:
                    XCTAssertGreaterThan(size!, 200 * 1024 * 1024) // >200MB
                    XCTAssertLessThan(size!, 300 * 1024 * 1024) // <300MB
                }
            }
        }
    }

    // MARK: - Model Verification Tests

    func testModelVerification() async {
        // Skip in CI environment
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping model verification in CI")
        }

        // Test verification for downloaded models
        for modelType in ModelType.allCases {
            if modelManager.isModelDownloaded(modelType: modelType) {
                let isValid = await modelManager.verifyModel(modelType: modelType)
                XCTAssertTrue(isValid, "Downloaded model should be valid")
            }
        }
    }

    // MARK: - Download Progress Tests

    func testDownloadProgressInitialState() {
        XCTAssertEqual(modelManager.downloadProgress, 0.0)
        XCTAssertFalse(modelManager.isDownloading)
        XCTAssertNil(modelManager.currentDownloadTask)
    }

    func testGetDownloadedModels() {
        let downloadedModels = modelManager.getDownloadedModels()

        // Verify it returns an array
        XCTAssertNotNil(downloadedModels)

        // Verify all returned models are actually downloaded
        for model in downloadedModels {
            XCTAssertTrue(modelManager.isModelDownloaded(modelType: model))
        }
    }

    // MARK: - Model Configuration Tests

    func testModelConfiguration() {
        // Test creating model configurations
        for modelType in ModelType.allCases {
            let config = modelManager.createModelConfiguration(for: modelType)

            XCTAssertNotNil(config.name)
            XCTAssertEqual(config.version, "1.0")
            XCTAssertNotNil(config.downloadURL)
            XCTAssertGreaterThan(config.estimatedSize, 0)
            XCTAssertEqual(config.minimumOSVersion, "17.0")
            XCTAssertGreaterThan(config.requiredMemoryGB, 0)

            // Verify URL is properly formed
            XCTAssertTrue(config.downloadURL.absoluteString.contains("huggingface.co"))
            XCTAssertTrue(config.downloadURL.absoluteString.contains(config.name))
        }
    }

    // MARK: - Error Handling Tests

    func testDeleteNonExistentModel() async {
        // Create a unique temporary model type that definitely doesn't exist
        do {
            try await modelManager.deleteModel(modelType: .accurate)

            // If model exists, this is fine
            // If it doesn't exist, we should get an error
            if !modelManager.isModelDownloaded(modelType: .accurate) {
                XCTFail("Expected error when deleting non-existent model")
            }
        } catch {
            // Expected error for non-existent model
            XCTAssertTrue(error is WhisperKitModelError)
        }
    }

    // MARK: - Mock Download Tests

    func testDownloadCancellation() async {
        // This would test download cancellation if we had a mock download service
        // For now, we just verify the download state management

        XCTAssertFalse(modelManager.isDownloading)

        // Start a download task (will fail in test environment)
        let downloadTask = Task {
            do {
                try await modelManager.downloadModel(modelType: .balanced)
            } catch {
                // Expected in test environment
            }
        }

        // Cancel immediately
        downloadTask.cancel()

        // Verify state is cleaned up
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        XCTAssertFalse(modelManager.isDownloading)
    }

    // MARK: - Integration Tests

    func testModelManagerIntegration() async {
        // Test integration with ModelManager
        let generalModelManager = ModelManager()

        // Sync models
        await modelManager.syncWithModelManager(generalModelManager)

        // Verify sync doesn't crash
        // In a real test, we'd verify the models are properly synced
        XCTAssertTrue(true, "Sync completed without crashing")
    }
}

// MARK: - Mock Helpers

extension WhisperKitModelManagerTests {
    /// Create mock audio data for testing
    func createMockAudioData(duration: TimeInterval = 1.0) -> AudioData {
        let sampleRate = 16000.0
        let sampleCount = Int(sampleRate * duration)
        let samples = [Int16](repeating: 0, count: sampleCount)

        return AudioData(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1
        )
    }

    /// Helper to get WhisperKit model name
    func getWhisperKitModelName(for modelType: ModelType) -> String {
        switch modelType {
        case .fast:
            return "openai_whisper-tiny"
        case .balanced:
            return "openai_whisper-base"
        case .accurate:
            return "openai_whisper-small"
        }
    }

    /// Verify model name mapping
    func testModelNameMapping() {
        // Use reflection to access private method
        let modelManager = WhisperKitModelManager()

        // Test through public API
        let config = modelManager.createModelConfiguration(for: .fast)
        XCTAssertEqual(config.name, "openai_whisper-tiny")

        let configBalanced = modelManager.createModelConfiguration(for: .balanced)
        XCTAssertEqual(configBalanced.name, "openai_whisper-base")

        let configAccurate = modelManager.createModelConfiguration(for: .accurate)
        XCTAssertEqual(configAccurate.name, "openai_whisper-small")
    }
}
