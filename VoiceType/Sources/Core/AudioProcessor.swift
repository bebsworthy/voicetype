//
//  AudioProcessor.swift
//  VoiceType
//
//  Core audio processing protocol for the VoiceType MVP
//

import Foundation

/// Protocol defining the interface for audio recording and processing functionality.
/// Implementations of this protocol handle microphone access, audio capture, and
/// basic preprocessing of audio data for transcription.
public protocol AudioProcessor {
    /// Indicates whether the processor is currently recording audio.
    var isRecording: Bool { get }

    /// Stream that emits audio level changes during recording (0.0 to 1.0).
    /// Used for visual feedback of recording levels.
    var audioLevelChanged: AsyncStream<Float> { get }

    /// Stream that emits recording state changes.
    /// Used to update UI and coordinate app state.
    var recordingStateChanged: AsyncStream<RecordingState> { get }

    /// Starts recording audio from the configured input device.
    /// - Throws: AudioError if microphone permission is denied or audio setup fails
    /// - Note: Recording will automatically stop after 5 seconds unless stopped manually
    func startRecording() async throws

    /// Stops recording and returns the captured audio data.
    /// - Returns: AudioData containing the recorded samples
    /// - Note: Safe to call even if recording has already stopped
    func stopRecording() async -> AudioData
}

/// Protocol for audio preprocessing plugins that can modify audio before transcription.
/// Examples include noise reduction, normalization, or format conversion.
public protocol AudioPreprocessor {
    /// Process raw audio data before it's sent to transcription.
    /// - Parameter audio: The raw audio data to process
    /// - Returns: Processed audio data ready for transcription
    func process(_ audio: AudioData) async -> AudioData
}

/// Configuration for audio processing
public struct AudioProcessorConfiguration {
    /// Sample rate for audio recording (Hz)
    public let sampleRate: Double

    /// Number of audio channels (1 for mono, 2 for stereo)
    public let channelCount: Int

    /// Audio format bit depth
    public let bitDepth: Int

    /// Buffer size in samples
    public let bufferSize: Int

    /// Maximum recording duration in seconds
    public let maxRecordingDuration: TimeInterval

    /// Default configuration for VoiceType MVP (16kHz mono)
    public static let voiceTypeMVP = AudioProcessorConfiguration(
        sampleRate: 16000,
        channelCount: 1,
        bitDepth: 16,
        bufferSize: 1024,
        maxRecordingDuration: 5.0
    )

    public init(sampleRate: Double, channelCount: Int, bitDepth: Int, bufferSize: Int, maxRecordingDuration: TimeInterval) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.bitDepth = bitDepth
        self.bufferSize = bufferSize
        self.maxRecordingDuration = maxRecordingDuration
    }
}

/// Errors that can occur during audio processing
public enum AudioProcessorError: LocalizedError {
    case permissionDenied
    case deviceNotAvailable
    case recordingInProgress
    case noActiveRecording
    case audioSessionError(String)
    case deviceDisconnected
    case systemError(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission denied. Please grant permission in System Preferences."
        case .deviceNotAvailable:
            return "No audio input device available."
        case .recordingInProgress:
            return "Recording is already in progress."
        case .noActiveRecording:
            return "No active recording to stop."
        case .audioSessionError(let message):
            return "Audio session error: \(message)"
        case .deviceDisconnected:
            return "Audio device was disconnected during recording."
        case .systemError(let message):
            return "System error: \(message)"
        }
    }
}
