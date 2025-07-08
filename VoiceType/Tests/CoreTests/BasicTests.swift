import XCTest
@testable import VoiceTypeCore

final class BasicTests: XCTestCase {
    func testLanguageEnum() {
        // Test language creation
        let english = Language.english
        XCTAssertEqual(english.code, "en")
        XCTAssertEqual(english.displayName, "English")

        let spanish = Language.spanish
        XCTAssertEqual(spanish.code, "es")
        XCTAssertEqual(spanish.displayName, "Spanish")
    }

    func testModelType() {
        // Test model types
        let fast = ModelType.fast
        XCTAssertEqual(fast.displayName, "Fast (openai_whisper-tiny)")

        let balanced = ModelType.balanced
        XCTAssertEqual(balanced.displayName, "Balanced (openai_whisper-base)")

        let accurate = ModelType.accurate
        XCTAssertEqual(accurate.displayName, "Accurate (openai_whisper-small)")
    }

    func testRecordingState() {
        // Test recording states
        let idle = RecordingState.idle
        XCTAssertEqual(idle.description, "Ready")

        let recording = RecordingState.recording
        XCTAssertEqual(recording.description, "Recording...")

        let processing = RecordingState.processing
        XCTAssertEqual(processing.description, "Processing...")
    }

    func testAudioData() {
        // Test AudioData creation
        let samples: [Int16] = [0, 100, -100, 200, -200]
        let audioData = AudioData(
            samples: samples,
            sampleRate: 44100.0,
            channelCount: 1,
            timestamp: Date()
        )

        XCTAssertEqual(audioData.samples.count, 5)
        XCTAssertEqual(audioData.sampleRate, 44100.0)
        XCTAssertEqual(audioData.channelCount, 1)

        // Test duration calculation
        let expectedDuration = Double(samples.count) / 44100.0
        XCTAssertEqual(audioData.duration, expectedDuration, accuracy: 0.0001)
    }

    func testWhisperModel() {
        // Test Whisper model enum
        let tiny = WhisperModel.tiny
        XCTAssertEqual(tiny.rawValue, "tiny")
        XCTAssertEqual(tiny.toModelType, .fast)

        let base = WhisperModel.base
        XCTAssertEqual(base.rawValue, "base")
        XCTAssertEqual(base.toModelType, .balanced)

        let small = WhisperModel.small
        XCTAssertEqual(small.rawValue, "small")
        XCTAssertEqual(small.toModelType, .accurate)
    }
}
