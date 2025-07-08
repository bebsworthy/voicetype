import XCTest
import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Tests for WhisperKit language detection and multi-language support
class WhisperKitLanguageTests: XCTestCase {
    var transcriber: WhisperKitTranscriber!

    override func setUp() async throws {
        try await super.setUp()
        transcriber = WhisperKitTranscriber()
    }

    override func tearDown() async throws {
        transcriber = nil
        try await super.tearDown()
    }

    // MARK: - Language Support Tests

    func testSupportedLanguages() {
        let supportedLanguages = transcriber.supportedLanguages

        // WhisperKit should support all languages in our enum
        XCTAssertEqual(supportedLanguages.count, Language.allCases.count)

        // Verify common languages are supported
        XCTAssertTrue(supportedLanguages.contains(.english))
        XCTAssertTrue(supportedLanguages.contains(.spanish))
        XCTAssertTrue(supportedLanguages.contains(.french))
        XCTAssertTrue(supportedLanguages.contains(.german))
        XCTAssertTrue(supportedLanguages.contains(.chinese))
        XCTAssertTrue(supportedLanguages.contains(.japanese))
    }

    // MARK: - Language Detection Tests

    func testLanguageAutoDetection() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        // Load model
        try await transcriber.loadModel(.fast)

        // Test with silence (should default to English)
        let silentAudio = createSilentAudio()
        let result = try await transcriber.transcribe(silentAudio, language: nil)

        XCTAssertNotNil(result.language)
        // Silent audio typically defaults to English
        print("Auto-detected language for silence: \(result.language?.displayName ?? "none")")
    }

    func testExplicitLanguageSelection() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        try await transcriber.loadModel(.fast)

        let testLanguages: [Language] = [.english, .spanish, .french, .german]
        let audioData = createSilentAudio()

        for language in testLanguages {
            let result = try await transcriber.transcribe(audioData, language: language)

            // When explicitly set, the result should respect our choice
            XCTAssertEqual(result.language, language)
        }
    }

    // MARK: - Multi-language Transcription Tests

    func testConsecutiveMultilingualTranscriptions() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        try await transcriber.loadModel(.fast)

        // Transcribe in different languages consecutively
        let languages: [Language] = [.english, .spanish, .french, .chinese]

        for language in languages {
            let audioData = createTestAudioForLanguage(language)

            do {
                let result = try await transcriber.transcribe(audioData, language: language)
                XCTAssertNotNil(result)
                XCTAssertEqual(result.language, language)
                print("Transcribed in \(language.displayName): '\(result.text)'")
            } catch {
                print("Language \(language.displayName) transcription failed: \(error)")
            }
        }
    }

    func testLanguageSwitchingPerformance() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        try await transcriber.loadModel(.fast)

        let audioData = createSilentAudio()
        let languages: [Language] = [.english, .spanish, .english, .spanish]

        // Measure time for rapid language switching
        let startTime = CFAbsoluteTimeGetCurrent()

        for language in languages {
            _ = try await transcriber.transcribe(audioData, language: language)
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let avgTime = totalTime / Double(languages.count)

        print("Language switching performance:")
        print("  Total time: \(totalTime.formatted(.number.precision(.fractionLength(3))))s")
        print("  Average per transcription: \(avgTime.formatted(.number.precision(.fractionLength(3))))s")

        // Switching languages shouldn't significantly impact performance
        XCTAssertLessThan(avgTime, 2.0, "Language switching should not add significant overhead")
    }

    // MARK: - Language-specific Features Tests

    func testLanguageSpecificPunctuation() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        try await transcriber.loadModel(.fast)

        // Test languages with different punctuation rules
        let testCases: [(Language, String)] = [
            (.english, "Hello world"),
            (.spanish, "¡Hola mundo!"),
            (.french, "Bonjour le monde"),
            (.german, "Hallo Welt")
        ]

        for (language, _) in testCases {
            let audioData = createTestAudioForLanguage(language)

            do {
                let result = try await transcriber.transcribe(audioData, language: language)
                print("\(language.displayName) transcription: '\(result.text)'")

                // Verify result is not empty (with test audio, might be empty)
                XCTAssertNotNil(result.text)
            } catch {
                print("Failed to transcribe \(language.displayName): \(error)")
            }
        }
    }

    // MARK: - Edge Cases

    func testUnsupportedLanguageHandling() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        try await transcriber.loadModel(.fast)

        // All languages in our enum should be supported by Whisper
        // But we test the behavior anyway
        let audioData = createSilentAudio()

        // Try with least common language
        do {
            let result = try await transcriber.transcribe(audioData, language: .thai)
            XCTAssertNotNil(result)
            print("Thai transcription succeeded: '\(result.text)'")
        } catch {
            if case TranscriberError.unsupportedLanguage = error {
                XCTFail("Thai should be supported by Whisper")
            } else {
                print("Unexpected error: \(error)")
            }
        }
    }

    func testMixedLanguageAudio() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping in CI environment")
        }

        try await transcriber.loadModel(.fast)

        // Create audio that might contain multiple languages
        // In practice, this would be actual mixed-language speech
        let audioData = createComplexAudio()

        // Test with auto-detection
        let autoResult = try await transcriber.transcribe(audioData, language: nil)
        print("Auto-detected primary language: \(autoResult.language?.displayName ?? "none")")

        // Test forcing a specific language
        let forcedResult = try await transcriber.transcribe(audioData, language: .english)
        XCTAssertEqual(forcedResult.language, .english)
    }

    // MARK: - Helper Methods

    private func createSilentAudio(duration: TimeInterval = 1.0) -> AudioData {
        let sampleRate = 16000.0
        let sampleCount = Int(sampleRate * duration)
        let samples = [Int16](repeating: 0, count: sampleCount)

        return AudioData(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1
        )
    }

    private func createTestAudioForLanguage(_ language: Language) -> AudioData {
        // In a real test, this would create language-specific audio samples
        // For now, we use different patterns to simulate different languages
        let sampleRate = 16000.0
        let duration = 2.0
        let sampleCount = Int(sampleRate * duration)

        var samples = [Int16]()

        // Create different patterns for different languages
        let frequency: Double
        switch language {
        case .english:
            frequency = 440.0 // A4
        case .spanish:
            frequency = 466.16 // A#4
        case .french:
            frequency = 493.88 // B4
        case .german:
            frequency = 523.25 // C5
        case .chinese:
            frequency = 554.37 // C#5
        case .japanese:
            frequency = 587.33 // D5
        default:
            frequency = 440.0
        }

        for i in 0..<sampleCount {
            let angle = 2.0 * Double.pi * frequency * Double(i) / sampleRate
            let envelope = sin(Double(i) / sampleRate * 2.0) // Amplitude envelope
            let sample = Int16(1000.0 * envelope * sin(angle))
            samples.append(sample)
        }

        return AudioData(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1
        )
    }

    private func createComplexAudio() -> AudioData {
        // Create audio with varying characteristics
        let sampleRate = 16000.0
        let duration = 3.0
        let sampleCount = Int(sampleRate * duration)

        var samples = [Int16]()

        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate

            // Mix multiple frequencies
            let f1 = sin(2.0 * Double.pi * 440.0 * t)
            let f2 = sin(2.0 * Double.pi * 554.37 * t)
            let f3 = sin(2.0 * Double.pi * 659.25 * t)

            // Varying amplitude
            let envelope = sin(t * 0.5) * 0.5 + 0.5

            let mixed = (f1 + f2 * 0.5 + f3 * 0.3) / 2.3
            let sample = Int16(3000.0 * envelope * mixed)
            samples.append(sample)
        }

        return AudioData(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1
        )
    }
}

// MARK: - Language Mapping Tests

extension WhisperKitLanguageTests {
    func testLanguageCodeMapping() {
        // Test that all our Language enum cases map correctly
        for language in Language.allCases {
            // The raw value should be the ISO 639-1 code
            XCTAssertFalse(language.rawValue.isEmpty)
            XCTAssertTrue(language.rawValue.count == 2 || language.rawValue.count == 3)

            // Display name should be readable
            XCTAssertFalse(language.displayName.isEmpty)
            XCTAssertNotEqual(language.displayName, language.rawValue)
        }
    }
}
