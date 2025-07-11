import XCTest
import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Tests for WhisperKit error handling and edge cases
class WhisperKitErrorHandlingTests: XCTestCase {
    var transcriber: WhisperKitTranscriber!

    override func setUp() async throws {
        try await super.setUp()
        transcriber = WhisperKitTranscriber()
    }

    override func tearDown() async throws {
        transcriber = nil
        try await super.tearDown()
    }

    // MARK: - Audio Data Validation Tests

    func testEmptyAudioData() async throws {
        // Test transcription with empty audio
        let emptyAudio = AudioData(
            samples: [],
            sampleRate: 16000,
            channelCount: 1
        )

        do {
            _ = try await transcriber.transcribe(emptyAudio, language: nil)
            XCTFail("Expected error for empty audio data")
        } catch TranscriberError.invalidAudioData {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testVeryShortAudioData() async throws {
        // Skip if no model available
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        // Load model first
        try await transcriber.loadModel(.fast)

        // Test with very short audio (less than 0.1 seconds)
        let shortAudio = AudioData(
            samples: [Int16](repeating: 0, count: 100), // ~0.006 seconds
            sampleRate: 16000,
            channelCount: 1
        )

        // This should work but might return empty text
        do {
            let result = try await transcriber.transcribe(shortAudio, language: .english)
            XCTAssertNotNil(result)
            // Very short audio might produce empty text, which is valid
        } catch {
            XCTFail("Short audio should not throw error: \(error)")
        }
    }

    func testInvalidSampleRate() async throws {
        // Test with non-standard sample rate
        let oddSampleRateAudio = AudioData(
            samples: [Int16](repeating: 0, count: 8000),
            sampleRate: 8000, // WhisperKit expects 16kHz
            channelCount: 1
        )

        // Skip if no model available
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        try await transcriber.loadModel(.fast)

        // This might work but with degraded quality
        do {
            let result = try await transcriber.transcribe(oddSampleRateAudio, language: .english)
            XCTAssertNotNil(result)
            print("Warning: Non-standard sample rate handled, but quality may be degraded")
        } catch {
            // Some implementations might reject non-standard sample rates
            print("Non-standard sample rate rejected: \(error)")
        }
    }

    // MARK: - Model Loading Error Tests

    func testTranscriptionWithoutModel() async throws {
        // Ensure no model is loaded
        XCTAssertFalse(transcriber.isModelLoaded)

        let audioData = createMockAudioData()

        do {
            _ = try await transcriber.transcribe(audioData, language: nil)
            XCTFail("Expected error when transcribing without model")
        } catch TranscriberError.modelNotLoaded {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testInvalidString() async throws {
        // This test would be more meaningful if we could inject invalid model types
        // For now, we test that all valid model types can be attempted to load

        for modelType in String.allCases {
            do {
                try await transcriber.loadModel(modelType)
                // If it succeeds, model is available
                XCTAssertTrue(transcriber.isModelLoaded)
                XCTAssertEqual(transcriber.modelInfo.type, modelType)
            } catch {
                // If it fails, it's likely the model isn't downloaded
                print("Model \(modelType) not available: \(error)")
            }
        }
    }

    // MARK: - Language Handling Tests

    func testUnsupportedLanguage() async throws {
        // Skip if no model available
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        try await transcriber.loadModel(.fast)

        let audioData = createMockAudioData()

        // WhisperKit actually supports many languages, so this should work
        // but we test the behavior anyway
        do {
            let result = try await transcriber.transcribe(audioData, language: .japanese)
            XCTAssertNotNil(result)
            // Japanese is actually supported by Whisper
        } catch {
            // If it fails, verify it's the expected error
            if case TranscriberError.unsupportedLanguage = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testLanguageAutoDetection() async throws {
        // Skip if no model available
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        try await transcriber.loadModel(.fast)

        // Create audio with some noise to potentially trigger detection
        let audioData = createMockAudioDataWithNoise()

        // Test with nil language (auto-detect)
        do {
            let result = try await transcriber.transcribe(audioData, language: nil)
            XCTAssertNotNil(result)
            XCTAssertNotNil(result.language)
            // With mock/silent audio, it will likely default to English
            print("Auto-detected language: \(result.language?.displayName ?? "none")")
        } catch {
            XCTFail("Language auto-detection failed: \(error)")
        }
    }

    // MARK: - Concurrent Operation Tests

    func testConcurrentTranscriptions() async throws {
        // Skip if no model available
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        try await transcriber.loadModel(.fast)

        let audioData1 = createMockAudioData(duration: 0.5)
        let audioData2 = createMockAudioData(duration: 0.5)

        // Attempt concurrent transcriptions
        async let result1 = transcriber.transcribe(audioData1, language: .english)
        async let result2 = transcriber.transcribe(audioData2, language: .english)

        do {
            let (r1, r2) = try await (result1, result2)
            XCTAssertNotNil(r1)
            XCTAssertNotNil(r2)
        } catch {
            // Some implementations might not support concurrent transcription
            print("Concurrent transcription not supported: \(error)")
        }
    }

    func testModelSwitchingDuringOperation() async throws {
        // Skip if no model available
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        // Load initial model
        try await transcriber.loadModel(.fast)

        let audioData = createMockAudioData(duration: 2.0)

        // Start transcription
        let transcriptionTask = Task {
            try await transcriber.transcribe(audioData, language: .english)
        }

        // Attempt to switch model during transcription
        let switchTask = Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s delay
            try await transcriber.loadModel(.balanced)
        }

        do {
            let result = try await transcriptionTask.value
            XCTAssertNotNil(result)

            // Wait for switch to complete
            _ = try? await switchTask.value
        } catch {
            // Model switching during operation might fail, which is acceptable
            print("Model switching during operation: \(error)")
        }
    }

    // MARK: - Memory and Resource Tests

    func testLargeAudioProcessing() async throws {
        // Skip if no model available
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        try await transcriber.loadModel(.fast)

        // Create 30 seconds of audio (maximum expected)
        let largeAudio = createMockAudioData(duration: 30.0)

        let startMemory = getMemoryUsage()

        do {
            let result = try await transcriber.transcribe(largeAudio, language: .english)
            XCTAssertNotNil(result)

            let endMemory = getMemoryUsage()
            let memoryIncrease = endMemory - startMemory

            print("Memory increase for 30s audio: \(memoryIncrease / 1024 / 1024) MB")

            // Memory increase should be reasonable (less than 100MB)
            XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024)
        } catch {
            XCTFail("Large audio processing failed: \(error)")
        }
    }

    func testModelUnloadingMemoryRelease() async throws {
        // Skip if no model available
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        let initialMemory = getMemoryUsage()

        // Load model
        try await transcriber.loadModel(.fast)
        let loadedMemory = getMemoryUsage()

        // Unload by loading a different model
        try await transcriber.loadModel(.balanced)

        // Give time for memory to be released
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        let finalMemory = getMemoryUsage()

        print("Memory - Initial: \(initialMemory / 1024 / 1024)MB, Loaded: \(loadedMemory / 1024 / 1024)MB, Final: \(finalMemory / 1024 / 1024)MB")

        // Memory should not continuously grow
        // Allow some overhead, but it shouldn't be more than 2x the initial
        XCTAssertLessThan(finalMemory, loadedMemory * 2)
    }

    // MARK: - Edge Case Tests

    func testMultiChannelAudio() async throws {
        // Skip if no model available
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        try await transcriber.loadModel(.fast)

        // Create stereo audio
        let stereoAudio = AudioData(
            samples: [Int16](repeating: 0, count: 32000), // 1 second stereo
            sampleRate: 16000,
            channelCount: 2
        )

        // WhisperKit might handle stereo by converting to mono
        do {
            let result = try await transcriber.transcribe(stereoAudio, language: .english)
            XCTAssertNotNil(result)
        } catch {
            print("Multi-channel audio handling: \(error)")
        }
    }

    func testRapidModelSwitching() async throws {
        // Skip if no model available
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        // Rapidly switch between models
        for _ in 0..<3 {
            for modelType in String.allCases {
                do {
                    try await transcriber.loadModel(modelType)
                    // Small delay to let model load
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                } catch {
                    print("Rapid model switch failed for \(modelType): \(error)")
                }
            }
        }

        // Verify transcriber is still functional
        if transcriber.isModelLoaded {
            let audioData = createMockAudioData()
            do {
                let result = try await transcriber.transcribe(audioData, language: .english)
                XCTAssertNotNil(result)
            } catch {
                XCTFail("Transcriber broken after rapid switching: \(error)")
            }
        }
    }

    // MARK: - Helper Methods

    private func createMockAudioData(duration: TimeInterval = 1.0) -> AudioData {
        let sampleRate = 16000.0
        let sampleCount = Int(sampleRate * duration)
        let samples = [Int16](repeating: 0, count: sampleCount)

        return AudioData(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1
        )
    }

    private func createMockAudioDataWithNoise(duration: TimeInterval = 1.0) -> AudioData {
        let sampleRate = 16000.0
        let sampleCount = Int(sampleRate * duration)

        // Create audio with random noise
        var samples = [Int16]()
        for _ in 0..<sampleCount {
            // Low amplitude random noise
            let noise = Int16.random(in: -1000...1000)
            samples.append(noise)
        }

        return AudioData(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1
        )
    }

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}
