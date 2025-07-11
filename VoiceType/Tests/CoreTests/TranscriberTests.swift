import XCTest
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

final class TranscriberTests: XCTestCase {
    // MARK: - Mock Transcriber Tests

    func testMockTranscriberSuccess() async throws {
        // Given
        let transcriber = MockTranscriber(behavior: .success(text: "Test transcription", confidence: 0.95))
        let samples = Array(repeating: Int16(0), count: 16000) // 1 second of audio
        let audioData = AudioData(samples: samples, sampleRate: 16000, channelCount: 1)

        // When
        let result = try await transcriber.transcribe(audioData, language: nil)

        // Then
        XCTAssertEqual(result.text, "Test transcription")
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.language, .english)
        XCTAssertEqual(transcriber.transcribeCallCount, 1)
        XCTAssertEqual(transcriber.lastAudioDataSize, 16000 * MemoryLayout<Int16>.size)
    }

    func testMockTranscriberFailure() async {
        // Given
        let transcriber = MockTranscriber(behavior: .failure(.modelNotLoaded))
        let samples = Array(repeating: Int16(0), count: 16000)
        let audioData = AudioData(samples: samples, sampleRate: 16000, channelCount: 1)

        // When/Then
        do {
            _ = try await transcriber.transcribe(audioData, language: nil)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is TranscriberError)
            if let transcriberError = error as? TranscriberError {
                switch transcriberError {
                case .modelNotLoaded:
                    // Expected
                    break
                default:
                    XCTFail("Unexpected error type: \(transcriberError)")
                }
            }
        }
    }

    func testMockTranscriberDelayed() async throws {
        // Given
        let transcriber = MockTranscriber(behavior: .delayed(text: "Delayed result", delay: 0.1))
        let samples = Array(repeating: Int16(0), count: 16000)
        let audioData = AudioData(samples: samples, sampleRate: 16000, channelCount: 1)

        // When
        let startTime = Date()
        let result = try await transcriber.transcribe(audioData, language: nil)
        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertEqual(result.text, "Delayed result")
        XCTAssertGreaterThanOrEqual(elapsed, 0.1)
        XCTAssertLessThan(elapsed, 0.2) // Allow some tolerance
    }

    func testMockTranscriberSequence() async throws {
        // Given
        let behaviors: [MockTranscriber.MockBehavior] = [
            .success(text: "First", confidence: 0.9),
            .success(text: "Second", confidence: 0.8),
            .failure(.transcriptionFailed(reason: "Test failure"))
        ]
        let transcriber = MockTranscriber(behavior: .sequence(behaviors))
        let samples = Array(repeating: Int16(0), count: 16000)
        let audioData = AudioData(samples: samples, sampleRate: 16000, channelCount: 1)

        // When/Then
        // First call
        let result1 = try await transcriber.transcribe(audioData, language: nil)
        XCTAssertEqual(result1.text, "First")
        XCTAssertEqual(result1.confidence, 0.9)

        // Second call
        let result2 = try await transcriber.transcribe(audioData, language: nil)
        XCTAssertEqual(result2.text, "Second")
        XCTAssertEqual(result2.confidence, 0.8)

        // Third call should fail
        do {
            _ = try await transcriber.transcribe(audioData, language: nil)
            XCTFail("Expected error on third call")
        } catch {
            XCTAssertTrue(error is TranscriberError)
        }

        // Fourth call should cycle back to first
        let result4 = try await transcriber.transcribe(audioData, language: nil)
        XCTAssertEqual(result4.text, "First")
    }

    func testMockTranscriberNotReady() async {
        // Given
        let transcriber = MockTranscriber()
        transcriber.setReady(false)
        let samples = Array(repeating: Int16(0), count: 16000)
        let audioData = AudioData(samples: samples, sampleRate: 16000, channelCount: 1)

        // When/Then
        do {
            _ = try await transcriber.transcribe(audioData, language: nil)
            XCTFail("Expected error when not ready")
        } catch TranscriberError.modelNotLoaded {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMockTranscriberEmptyAudioData() async {
        // Given
        let transcriber = MockTranscriber()
        let emptyAudioData = AudioData.empty

        // When/Then
        do {
            _ = try await transcriber.transcribe(emptyAudioData, language: nil)
            XCTFail("Expected error for empty audio data")
        } catch TranscriberError.invalidAudioData {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Language Tests

    func testLanguageSelection() {
        // Given
        let transcriber = MockTranscriber()

        // When/Then
        XCTAssertEqual(transcriber.selectedLanguage, .english) // Default

        transcriber.selectedLanguage = .spanish
        XCTAssertEqual(transcriber.selectedLanguage, .spanish)

        // Verify all languages are supported
        XCTAssertEqual(transcriber.supportedLanguages.count, Language.allCases.count)
    }

    func testLanguageDisplayNames() {
        // Verify all languages have proper display names
        for language in Language.allCases {
            XCTAssertFalse(language.displayName.isEmpty)
            XCTAssertNotEqual(language.displayName, language.rawValue)
        }
    }

    // MARK: - CoreML Whisper Tests

    func testCoreMLWhisperInitialization() {
        // Given
        let modelPath = "/tmp/test-model.mlmodelc"

        // When
        let whisper = CoreMLWhisper(modelType: .tiny, modelPath: modelPath)

        // Then
        XCTAssertFalse(whisper.isModelLoaded) // Should not be ready until model is loaded
        XCTAssertEqual(whisper.supportedLanguages.count, Language.allCases.count)
    }

    func testCoreMLWhisperModelLoadingFailure() async {
        // Given
        let invalidPath = "/invalid/path/model.mlmodelc"
        let whisper = CoreMLWhisper(modelType: .base, modelPath: invalidPath)

        // When/Then
        do {
            try await whisper.loadModel()
            XCTFail("Expected model loading to fail")
        } catch TranscriberError.modelLoadingFailed(let reason) {
            XCTAssertTrue(reason.contains("not found"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCoreMLWhisperTranscribeWithoutModel() async {
        // Given
        let whisper = CoreMLWhisper(modelType: .small, modelPath: "/tmp/model.mlmodelc")
        let samples = Array(repeating: Int16(0), count: 16000)
        let audioData = AudioData(samples: samples, sampleRate: 16000, channelCount: 1)

        // When/Then
        do {
            _ = try await whisper.transcribe(audioData, language: nil)
            XCTFail("Expected error when model not loaded")
        } catch TranscriberError.modelNotLoaded {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - WhisperModel Tests

    func testWhisperModelProperties() {
        // Test Tiny model
        let tiny = WhisperModel.tiny
        XCTAssertEqual(tiny.fileName, "whisper-tiny")
        XCTAssertEqual(tiny.sizeInMB, 27)
        XCTAssertEqual(tiny.displayName, "Fast")
        XCTAssertEqual(tiny.targetLatency, "<2s")
        XCTAssertTrue(tiny.isEmbedded)
        XCTAssertEqual(tiny.minimumRAM, "4GB")
        XCTAssertEqual(tiny.toString, .fast)

        // Test Base model
        let base = WhisperModel.base
        XCTAssertEqual(base.fileName, "whisper-base")
        XCTAssertEqual(base.sizeInMB, 74)
        XCTAssertEqual(base.displayName, "Balanced")
        XCTAssertEqual(base.targetLatency, "<3s")
        XCTAssertFalse(base.isEmbedded)
        XCTAssertEqual(base.minimumRAM, "6GB")
        XCTAssertEqual(base.toString, .balanced)

        // Test Small model
        let small = WhisperModel.small
        XCTAssertEqual(small.fileName, "whisper-small")
        XCTAssertEqual(small.sizeInMB, 140)
        XCTAssertEqual(small.displayName, "Accurate")
        XCTAssertEqual(small.targetLatency, "<5s")
        XCTAssertFalse(small.isEmbedded)
        XCTAssertEqual(small.minimumRAM, "8GB")
        XCTAssertEqual(small.toString, .accurate)
    }

    // MARK: - Audio Utilities Tests

    func testAudioNormalization() {
        // Given
        let samples: [Float] = [0.1, -0.2, 0.5, -0.8, 0.3]

        // When
        let normalized = AudioUtilities.normalize(samples, targetPeak: 1.0)

        // Then
        let maxValue = normalized.max() ?? 0
        let minValue = normalized.min() ?? 0
        XCTAssertEqual(max(abs(maxValue), abs(minValue)), 1.0, accuracy: 0.001)
    }

    func testAudioRMSCalculation() {
        // Given
        let silence: [Float] = [0, 0, 0, 0, 0]
        let loud: [Float] = [1, 1, 1, 1, 1]
        let mixed: [Float] = [0.5, -0.5, 0.5, -0.5]

        // When/Then
        XCTAssertEqual(AudioUtilities.calculateRMSLevel(silence), 0.0)
        XCTAssertEqual(AudioUtilities.calculateRMSLevel(loud), 1.0, accuracy: 0.001)
        XCTAssertEqual(AudioUtilities.calculateRMSLevel(mixed), 0.5, accuracy: 0.001)
    }

    func testPreEmphasisFilter() {
        // Given
        let samples: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let coefficient: Float = 0.97

        // When
        let filtered = AudioUtilities.applyPreEmphasis(samples, coefficient: coefficient)

        // Then
        XCTAssertEqual(filtered[0], samples[0]) // First sample unchanged
        for i in 1..<samples.count {
            let expected = samples[i] - coefficient * samples[i - 1]
            XCTAssertEqual(filtered[i], expected, accuracy: 0.0001)
        }
    }

    func testNoiseGate() {
        // Given
        let samples: [Float] = [0.001, 0.1, 0.005, -0.2, 0.0001]
        let threshold: Float = 0.01

        // When
        let gated = AudioUtilities.applyNoiseGate(samples, threshold: threshold)

        // Then
        XCTAssertEqual(gated[0], 0) // Below threshold
        XCTAssertEqual(gated[1], 0.1) // Above threshold
        XCTAssertEqual(gated[2], 0) // Below threshold
        XCTAssertEqual(gated[3], -0.2) // Above threshold (absolute value)
        XCTAssertEqual(gated[4], 0) // Below threshold
    }

    // MARK: - Factory Tests

    func testTranscriberFactory() {
        // Test mock creation
        let mock = TranscriberFactory.create(type: .mock(behavior: .success(text: "Factory test", confidence: 0.9)))
        XCTAssertTrue(mock is MockTranscriber)

        // Test CoreML creation
        let coreML = TranscriberFactory.create(type: .coreMLWhisper(model: .tiny, modelPath: "/tmp/model.mlmodelc"))
        XCTAssertTrue(coreML is CoreMLWhisper)

        // Test convenience methods
        let mockConvenience = TranscriberFactory.createMock()
        XCTAssertTrue(mockConvenience is MockTranscriber)

        let coreMLConvenience = TranscriberFactory.createCoreMLWhisper(model: .base)
        XCTAssertTrue(coreMLConvenience is CoreMLWhisper)
    }
}

// MARK: - Performance Tests

extension TranscriberTests {
    func testMockTranscriberPerformance() {
        let transcriber = MockTranscriber(behavior: .success(text: "Performance test", confidence: 0.95))
        let samples = Array(repeating: Int16(0), count: 16000 * 30) // 30 seconds
        let audioData = AudioData(samples: samples, sampleRate: 16000, channelCount: 1)

        measure {
            let expectation = XCTestExpectation(description: "Transcription")

            Task {
                do {
                    _ = try await transcriber.transcribe(audioData, language: nil)
                    expectation.fulfill()
                } catch {
                    XCTFail("Transcription failed: \(error)")
                }
            }

            wait(for: [expectation], timeout: 1.0)
        }
    }

    func testAudioUtilitiesPerformance() {
        let sampleCount = 16000 * 30 // 30 seconds
        let samples = (0..<sampleCount).map { Float(sin(Double($0) * 0.01)) }

        measure {
            _ = AudioUtilities.normalize(samples)
            _ = AudioUtilities.applyPreEmphasis(samples)
            _ = AudioUtilities.calculateRMSLevel(samples)
        }
    }
}
