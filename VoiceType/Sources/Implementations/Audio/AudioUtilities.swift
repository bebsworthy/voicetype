import Foundation
import AVFoundation
import VoiceTypeCore
import Accelerate

/// Utilities for audio processing and conversion
public struct AudioUtilities {
    /// Convert audio buffer to 16kHz mono PCM float32 format required by Whisper
    /// - Parameter buffer: Input audio buffer
    /// - Returns: Converted audio data
    public static func convertToWhisperFormat(_ buffer: AVAudioPCMBuffer) throws -> Data {
        guard let channelData = buffer.floatChannelData else {
            throw TranscriberError.invalidAudioData
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        // If already mono 16kHz, just return the data
        if buffer.format.sampleRate == 16000 && channelCount == 1 {
            let data = Data(bytes: channelData[0], count: frameLength * MemoryLayout<Float>.size)
            return data
        }

        // Convert to mono if needed
        var monoSamples = [Float](repeating: 0, count: frameLength)

        if channelCount == 1 {
            // Already mono
            monoSamples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        } else {
            // Mix down to mono
            for channel in 0..<channelCount {
                let channelSamples = UnsafeBufferPointer(start: channelData[channel], count: frameLength)
                for i in 0..<frameLength {
                    monoSamples[i] += channelSamples[i] / Float(channelCount)
                }
            }
        }

        // Resample to 16kHz if needed
        if buffer.format.sampleRate != 16000 {
            monoSamples = try resample(
                monoSamples,
                fromSampleRate: buffer.format.sampleRate,
                toSampleRate: 16000
            )
        }

        // Convert to Data
        return monoSamples.withUnsafeBytes { Data($0) }
    }

    /// Resample audio data to a different sample rate
    /// - Parameters:
    ///   - samples: Input samples
    ///   - fromSampleRate: Original sample rate
    ///   - toSampleRate: Target sample rate
    /// - Returns: Resampled audio samples
    public static func resample(_ samples: [Float], fromSampleRate: Double, toSampleRate: Double) throws -> [Float] {
        let ratio = toSampleRate / fromSampleRate
        let outputLength = Int(Double(samples.count) * ratio)
        var output = [Float](repeating: 0, count: outputLength)

        // Simple linear interpolation resampling
        // For production, consider using vDSP_vresamp or similar
        for i in 0..<outputLength {
            let sourceIndex = Double(i) / ratio
            let index = Int(sourceIndex)
            let fraction = Float(sourceIndex - Double(index))

            if index < samples.count - 1 {
                output[i] = samples[index] * (1 - fraction) + samples[index + 1] * fraction
            } else if index < samples.count {
                output[i] = samples[index]
            }
        }

        return output
    }

    /// Create an audio buffer from raw PCM data
    /// - Parameters:
    ///   - data: Raw PCM float32 data
    ///   - sampleRate: Sample rate of the audio
    /// - Returns: AVAudioPCMBuffer
    public static func createAudioBuffer(from data: Data, sampleRate: Double = 16000) throws -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        let frameCount = data.count / MemoryLayout<Float>.size

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            throw TranscriberError.invalidAudioData
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        data.withUnsafeBytes { rawBufferPointer in
            let floatPointer = rawBufferPointer.bindMemory(to: Float.self)
            if let channelData = buffer.floatChannelData {
                channelData[0].update(from: floatPointer.baseAddress!, count: frameCount)
            }
        }

        return buffer
    }

    /// Calculate RMS (Root Mean Square) level of audio data
    /// - Parameter audioData: Audio samples
    /// - Returns: RMS level (0.0 to 1.0)
    public static func calculateRMSLevel(_ audioData: [Float]) -> Float {
        guard !audioData.isEmpty else { return 0 }

        var rms: Float = 0
        vDSP_rmsqv(audioData, 1, &rms, vDSP_Length(audioData.count))

        return rms
    }

    /// Apply pre-emphasis filter to audio (commonly used in speech processing)
    /// - Parameters:
    ///   - samples: Input audio samples
    ///   - coefficient: Pre-emphasis coefficient (typically 0.97)
    /// - Returns: Filtered audio samples
    public static func applyPreEmphasis(_ samples: [Float], coefficient: Float = 0.97) -> [Float] {
        guard samples.count > 1 else { return samples }

        var output = [Float](repeating: 0, count: samples.count)
        output[0] = samples[0]

        for i in 1..<samples.count {
            output[i] = samples[i] - coefficient * samples[i - 1]
        }

        return output
    }

    /// Normalize audio to a specific peak level
    /// - Parameters:
    ///   - samples: Input audio samples
    ///   - targetPeak: Target peak level (default 0.95)
    /// - Returns: Normalized audio samples
    public static func normalize(_ samples: [Float], targetPeak: Float = 0.95) -> [Float] {
        guard !samples.isEmpty else { return samples }

        var maxValue: Float = 0
        vDSP_maxmgv(samples, 1, &maxValue, vDSP_Length(samples.count))

        guard maxValue > 0 else { return samples }

        let scale = targetPeak / maxValue
        var output = [Float](repeating: 0, count: samples.count)
        vDSP_vsmul(samples, 1, [scale], &output, 1, vDSP_Length(samples.count))

        return output
    }

    /// Apply a simple noise gate to audio
    /// - Parameters:
    ///   - samples: Input audio samples
    ///   - threshold: Gate threshold (default -40 dB)
    /// - Returns: Gated audio samples
    public static func applyNoiseGate(_ samples: [Float], threshold: Float = 0.01) -> [Float] {
        var output = samples

        for i in 0..<output.count {
            if abs(output[i]) < threshold {
                output[i] = 0
            }
        }

        return output
    }
}
