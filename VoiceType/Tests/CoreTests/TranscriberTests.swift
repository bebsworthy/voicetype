import XCTest
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

final class TranscriberTests: XCTestCase {
    
    // MARK: - Mock Transcriber Tests
    
    func testMockTranscriberSuccess() async throws {
        // Given
        let transcriber = MockTranscriber(behavior: .success(text: "Test transcription", confidence: 0.95))
        let audioData = Data(repeating: 0, count: 16000) // 1 second of audio
        
        // When
        let result = try await transcriber.transcribe(audioData)
        
        // Then
        XCTAssertEqual(result.text, "Test transcription")
        XCTAssertEqual(result.confidence, 0.95)
        XCTAssertEqual(result.language, .english)
        XCTAssertEqual(transcriber.transcribeCallCount, 1)
        XCTAssertEqual(transcriber.lastAudioDataSize, 16000)
    }
    
    func testMockTranscriberFailure() async {
        // Given
        let transcriber = MockTranscriber(behavior: .failure(.modelNotLoaded))
        let audioData = Data(repeating: 0, count: 16000)
        
        // When/Then
        do {
            _ = try await transcriber.transcribe(audioData)
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
        let audioData = Data(repeating: 0, count: 16000)
        
        // When
        let startTime = Date()
        let result = try await transcriber.transcribe(audioData)
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
        let audioData = Data(repeating: 0, count: 16000)
        
        // When/Then
        // First call
        let result1 = try await transcriber.transcribe(audioData)
        XCTAssertEqual(result1.text, "First")
        XCTAssertEqual(result1.confidence, 0.9)
        
        // Second call
        let result2 = try await transcriber.transcribe(audioData)
        XCTAssertEqual(result2.text, "Second")
        XCTAssertEqual(result2.confidence, 0.8)
        
        // Third call should fail
        do {
            _ = try await transcriber.transcribe(audioData)
            XCTFail("Expected error on third call")
        } catch {
            XCTAssertTrue(error is TranscriberError)
        }
        
        // Fourth call should cycle back to first
        let result4 = try await transcriber.transcribe(audioData)
        XCTAssertEqual(result4.text, "First")
    }
    
    func testMockTranscriberNotReady() async {
        // Given
        let transcriber = MockTranscriber()
        transcriber.setReady(false)
        let audioData = Data(repeating: 0, count: 16000)
        
        // When/Then
        do {
            _ = try await transcriber.transcribe(audioData)
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
        let emptyData = Data()
        
        // When/Then
        do {
            _ = try await transcriber.transcribe(emptyData)
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
        XCTAssertEqual(transcriber.supportedLanguages.count, TranscriptionLanguage.allCases.count)
    }
    
    func testLanguageDisplayNames() {
        // Verify all languages have proper display names
        for language in TranscriptionLanguage.allCases {
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
        XCTAssertFalse(whisper.isReady) // Should not be ready until model is loaded
        XCTAssertEqual(whisper.selectedLanguage, .english)
        XCTAssertEqual(whisper.supportedLanguages.count, TranscriptionLanguage.allCases.count)
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
        let audioData = Data(repeating: 0, count: 16000)
        
        // When/Then
        do {
            _ = try await whisper.transcribe(audioData)
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
        XCTAssertEqual(tiny.approximateSize, 39)
        XCTAssertEqual(tiny.parameters, "39M")
        XCTAssertEqual(tiny.relativeSpeed, 3)
        XCTAssertEqual(tiny.relativeAccuracy, 1)
        XCTAssertEqual(tiny.displayName, "Tiny (Fastest)")
        
        // Test Base model
        let base = WhisperModel.base
        XCTAssertEqual(base.fileName, "whisper-base")
        XCTAssertEqual(base.approximateSize, 74)
        XCTAssertEqual(base.parameters, "74M")
        XCTAssertEqual(base.relativeSpeed, 2)
        XCTAssertEqual(base.relativeAccuracy, 2)
        XCTAssertEqual(base.displayName, "Base (Balanced)")
        
        // Test Small model
        let small = WhisperModel.small
        XCTAssertEqual(small.fileName, "whisper-small")
        XCTAssertEqual(small.approximateSize, 244)
        XCTAssertEqual(small.parameters, "244M")
        XCTAssertEqual(small.relativeSpeed, 1)
        XCTAssertEqual(small.relativeAccuracy, 3)
        XCTAssertEqual(small.displayName, "Small (Most Accurate)")
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
        let audioData = Data(repeating: 0, count: 16000 * 30) // 30 seconds
        
        measure {
            let expectation = XCTestExpectation(description: "Transcription")
            
            Task {
                do {
                    _ = try await transcriber.transcribe(audioData)
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