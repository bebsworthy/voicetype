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

    func testString() {
        // Test model types
        let fast = "openai_whisper-tiny"
        XCTAssertEqual(fast.displayName, "Fast (openai_whisper-tiny)")

        let balanced = "openai_whisper-base"
        XCTAssertEqual(balanced.displayName, "Balanced (openai_whisper-base)")

        let accurate = "openai_whisper-small"
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
        XCTAssertEqual(tiny.toString, .fast)

        let base = WhisperModel.base
        XCTAssertEqual(base.rawValue, "base")
        XCTAssertEqual(base.toString, .balanced)

        let small = WhisperModel.small
        XCTAssertEqual(small.rawValue, "small")
        XCTAssertEqual(small.toString, .accurate)
    }
}
