import Foundation
@preconcurrency import CoreML
import Accelerate
import VoiceTypeCore
import AVFoundation

/// CoreML-based Whisper implementation for speech transcription
public class CoreMLWhisper: NSObject, Transcriber {
    // MARK: - Properties

    private var model: MLModel?
    private let modelName: String
    private let modelPath: String
    private let processingQueue = DispatchQueue(label: "com.voicetype.whisper", qos: .userInitiated)

    public private(set) var isReady: Bool = false
    public var selectedLanguage: Language = .english

    public var supportedLanguages: [Language] {
        Language.allCases
    }

    public var modelInfo: ModelInfo {
        ModelInfo(
            id: modelName,
            name: modelName,
            version: "1.0",
            path: URL(fileURLWithPath: modelPath),
            sizeInBytes: 100 * 1024 * 1024, // Default estimate
            isLoaded: isReady,
            lastUsed: Date()
        )
    }

    public var isModelLoaded: Bool {
        isReady
    }

    // Audio processing constants
    private let sampleRate: Double = 16000
    private let melBins = 80
    private let melFrames = 3000
    private let hopLength = 160
    private let chunkLength = 30 // seconds

    // MARK: - Initialization

    /// Initialize with a specific model name and path
    /// - Parameters:
    ///   - modelName: The model identifier
    ///   - modelPath: Path to the compiled CoreML model file
    public init(modelName: String, modelPath: String) {
        self.modelName = modelName
        self.modelPath = modelPath
        super.init()
    }

    /// Load the CoreML model
    public func loadModel() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: TranscriberError.modelLoadingFailed( "Instance deallocated"))
                    return
                }

                do {
                    let url = URL(fileURLWithPath: self.modelPath)
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        throw TranscriberError.modelLoadingFailed( "Model file not found at path: \(self.modelPath)")
                    }

                    let configuration = MLModelConfiguration()
                    configuration.computeUnits = .all

                    self.model = try MLModel(contentsOf: url, configuration: configuration)
                    self.isReady = true

                    continuation.resume()
                } catch {
                    self.isReady = false
                    continuation.resume(throwing: TranscriberError.modelLoadingFailed( error.localizedDescription))
                }
            }
        }
    }

    // MARK: - Transcriber Protocol

    public func transcribe(_ audio: AudioData, language: Language?) async throws -> TranscriptionResult {
        guard isReady, model != nil else {
            throw TranscriberError.modelNotLoaded
        }

        // Set the language if provided
        if let lang = language {
            selectedLanguage = lang
        }

        // Convert AudioData to Data format
        let audioData = audio.toData()

        // Process the audio
        return try await transcribeData(audioData)
    }

    public func loadModel(_ modelId: String) async throws {
        // Check if this matches our current model
        if modelId != modelName {
            // Would need to reinitialize with new model path
            throw TranscriberError.modelLoadingFailed("Cannot change model type after initialization")
        }

        // Load the current model
        try await loadModel()
    }

    private func transcribeData(_ audioData: Data) async throws -> TranscriptionResult {
        guard isReady, let model = model else {
            throw TranscriberError.modelNotLoaded
        }

        // Convert audio data to proper format
        let audioBuffer = try prepareAudioBuffer(from: audioData)

        // Convert to mel spectrogram
        let melSpectrogram = try await computeMelSpectrogram(from: audioBuffer)

        // Prepare input for CoreML model
        let modelInput = try prepareModelInput(melSpectrogram: melSpectrogram)

        // Run inference
        let output = try await runInference(with: modelInput, model: model)

        // Parse output
        let result = try parseOutput(output)

        return result
    }

    public func transcribe(_ audioData: Data) async throws -> TranscriptionResult {
        try await transcribeData(audioData)
    }

    // MARK: - Audio Processing

    private func prepareAudioBuffer(from audioData: Data) throws -> [Float] {
        // Convert Data to audio buffer
        // Input is 16-bit PCM data
        guard !audioData.isEmpty else {
            throw TranscriberError.invalidAudioData
        }

        let int16Count = audioData.count / MemoryLayout<Int16>.size
        var int16Buffer = [Int16](repeating: 0, count: int16Count)

        audioData.withUnsafeBytes { rawBufferPointer in
            let bufferPointer = rawBufferPointer.bindMemory(to: Int16.self)
            int16Buffer = Array(bufferPointer)
        }

        // Convert Int16 to normalized Float
        let audioBuffer = int16Buffer.map { Float($0) / Float(Int16.max) }

        return audioBuffer
    }

    private func computeMelSpectrogram(from audioBuffer: [Float]) async throws -> [[Float]] {
        try await withCheckedThrowingContinuation { continuation in
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: TranscriberError.transcriptionFailed(reason: "Instance deallocated"))
                    return
                }

                do {
                    // Pad or trim audio to exactly 30 seconds
                    let targetSamples = Int(self.sampleRate * Double(self.chunkLength))
                    var processedAudio = audioBuffer

                    if processedAudio.count < targetSamples {
                        // Pad with zeros
                        processedAudio.append(contentsOf: [Float](repeating: 0, count: targetSamples - processedAudio.count))
                    } else if processedAudio.count > targetSamples {
                        // Trim
                        processedAudio = Array(processedAudio.prefix(targetSamples))
                    }

                    // Compute STFT (Short-Time Fourier Transform)
                    let stft = try self.computeSTFT(audio: processedAudio)

                    // Convert to mel scale
                    let melSpectrogram = try self.stftToMelScale(stft: stft)

                    continuation.resume(returning: melSpectrogram)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func computeSTFT(audio: [Float]) throws -> [[Complex<Float>]] {
        let fftLength = 512
        let hopLength = self.hopLength
        let windowLength = fftLength

        // Create window (Hann window)
        var window = [Float](repeating: 0, count: windowLength)
        vDSP_hann_window(&window, vDSP_Length(windowLength), Int32(vDSP_HANN_NORM))

        // Calculate number of frames
        let numFrames = (audio.count - windowLength) / hopLength + 1

        // Setup FFT
        guard let fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftLength))), FFTRadix(kFFTRadix2)) else {
            throw TranscriberError.transcriptionFailed(reason: "Failed to create FFT setup")
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var stft = [[Complex<Float>]]()

        for i in 0..<numFrames {
            let start = i * hopLength
            let end = min(start + windowLength, audio.count)

            // Extract frame
            var frame = [Float](repeating: 0, count: fftLength)
            let frameLength = end - start
            if frameLength > 0 {
                frame[0..<frameLength] = audio[start..<end]
            }

            // Apply window
            vDSP_vmul(frame, 1, window, 1, &frame, 1, vDSP_Length(windowLength))

            // Perform FFT
            var realPart = [Float](repeating: 0, count: fftLength / 2)
            var imagPart = [Float](repeating: 0, count: fftLength / 2)

            frame.withUnsafeBufferPointer { framePtr in
                realPart.withUnsafeMutableBufferPointer { realPtr in
                    imagPart.withUnsafeMutableBufferPointer { imagPtr in
                        var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                        let framePtr = UnsafePointer<Float>(framePtr.baseAddress!)

                        // Convert interleaved complex to split complex
                        vDSP_ctoz(UnsafeRawPointer(framePtr).assumingMemoryBound(to: DSPComplex.self),
                                 2, &splitComplex, 1, vDSP_Length(fftLength / 2))

                        // Perform FFT
                        vDSP_fft_zrip(fftSetup, &splitComplex, 1,
                                     vDSP_Length(log2(Float(fftLength))), Int32(FFT_FORWARD))
                    }
                }
            }

            // Convert to complex numbers
            var frameSTFT = [Complex<Float>]()
            for j in 0..<(fftLength / 2 + 1) {
                let real = j < realPart.count ? realPart[j] : 0
                let imag = j < imagPart.count ? imagPart[j] : 0
                frameSTFT.append(Complex(real: real, imaginary: imag))
            }

            stft.append(frameSTFT)
        }

        return stft
    }

    private func stftToMelScale(stft: [[Complex<Float>]]) throws -> [[Float]] {
        let numMelBins = self.melBins
        let numFrames = min(stft.count, self.melFrames)
        let fftBins = stft.first?.count ?? 0

        // Create mel filterbank
        let melFilterbank = createMelFilterbank(
            numMelBins: numMelBins,
            numFFTBins: fftBins,
            sampleRate: Float(sampleRate)
        )

        var melSpectrogram = [[Float]](repeating: [Float](repeating: 0, count: numFrames), count: numMelBins)

        // Compute magnitude spectrogram
        for (frameIdx, frame) in stft.prefix(numFrames).enumerated() {
            var magnitudes = [Float](repeating: 0, count: fftBins)

            for (binIdx, complex) in frame.enumerated() {
                magnitudes[binIdx] = sqrt(complex.real * complex.real + complex.imaginary * complex.imaginary)
            }

            // Apply mel filterbank
            for melBin in 0..<numMelBins {
                var sum: Float = 0
                for fftBin in 0..<fftBins {
                    sum += magnitudes[fftBin] * melFilterbank[melBin][fftBin]
                }

                // Convert to log scale
                melSpectrogram[melBin][frameIdx] = log10(max(sum, 1e-10))
            }
        }

        // Normalize
        melSpectrogram = normalizeMelSpectrogram(melSpectrogram)

        return melSpectrogram
    }

    private func createMelFilterbank(numMelBins: Int, numFFTBins: Int, sampleRate: Float) -> [[Float]] {
        let lowFreq: Float = 0
        let highFreq = sampleRate / 2

        // Convert Hz to Mel
        func hzToMel(_ hz: Float) -> Float {
            2595 * log10(1 + hz / 700)
        }

        // Convert Mel to Hz
        func melToHz(_ mel: Float) -> Float {
            700 * (pow(10, mel / 2595) - 1)
        }

        let lowMel = hzToMel(lowFreq)
        let highMel = hzToMel(highFreq)

        // Equally spaced mel points
        var melPoints = [Float](repeating: 0, count: numMelBins + 2)
        let melStep = (highMel - lowMel) / Float(numMelBins + 1)
        for i in 0..<(numMelBins + 2) {
            melPoints[i] = lowMel + Float(i) * melStep
        }

        // Convert back to Hz
        let hzPoints = melPoints.map { melToHz($0) }

        // Convert to FFT bin numbers
        var binPoints = [Int](repeating: 0, count: numMelBins + 2)
        for i in 0..<(numMelBins + 2) {
            binPoints[i] = Int((Float(numFFTBins) * hzPoints[i]) / sampleRate)
        }

        // Create filterbank
        var filterbank = [[Float]](repeating: [Float](repeating: 0, count: numFFTBins), count: numMelBins)

        for m in 1...numMelBins {
            let leftBin = binPoints[m - 1]
            let centerBin = binPoints[m]
            let rightBin = binPoints[m + 1]

            for k in leftBin..<centerBin {
                if k < numFFTBins {
                    filterbank[m - 1][k] = Float(k - leftBin) / Float(centerBin - leftBin)
                }
            }

            for k in centerBin..<rightBin {
                if k < numFFTBins {
                    filterbank[m - 1][k] = Float(rightBin - k) / Float(rightBin - centerBin)
                }
            }
        }

        return filterbank
    }

    private func normalizeMelSpectrogram(_ melSpectrogram: [[Float]]) -> [[Float]] {
        var normalized = melSpectrogram

        // Calculate mean and std
        let totalElements = melSpectrogram.count * melSpectrogram[0].count
        var sum: Float = 0
        var sumSquared: Float = 0

        for row in melSpectrogram {
            for value in row {
                sum += value
                sumSquared += value * value
            }
        }

        let mean = sum / Float(totalElements)
        let variance = (sumSquared / Float(totalElements)) - (mean * mean)
        let std = sqrt(max(variance, 1e-10))

        // Normalize
        for i in 0..<normalized.count {
            for j in 0..<normalized[i].count {
                normalized[i][j] = (normalized[i][j] - mean) / std
            }
        }

        return normalized
    }

    // MARK: - Model Inference

    private func prepareModelInput(melSpectrogram: [[Float]]) throws -> MLFeatureProvider {
        // Flatten mel spectrogram to 1D array
        let flattenedMel = melSpectrogram.flatMap { $0 }

        // Create MLMultiArray
        let shape = [1, melBins, melFrames] as [NSNumber]
        guard let multiArray = try? MLMultiArray(shape: shape, dataType: .float32) else {
            throw TranscriberError.transcriptionFailed(reason: "Failed to create MLMultiArray")
        }

        // Fill the array
        for i in 0..<flattenedMel.count {
            multiArray[i] = NSNumber(value: flattenedMel[i])
        }

        // Create feature provider
        let featureProvider = CoreMLWhisperInput(melSpectrogram: multiArray, language: selectedLanguage)
        return featureProvider
    }

    private func runInference(with input: MLFeatureProvider, model: MLModel) async throws -> MLFeatureProvider {
        try await withCheckedThrowingContinuation { continuation in
            processingQueue.async {
                do {
                    let output = try model.prediction(from: input)
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: TranscriberError.transcriptionFailed(reason: error.localizedDescription))
                }
            }
        }
    }

    private func parseOutput(_ output: MLFeatureProvider) throws -> TranscriptionResult {
        // Extract text tokens from output
        guard let textTokens = output.featureValue(for: "output")?.multiArrayValue else {
            throw TranscriberError.transcriptionFailed(reason: "No output tokens found")
        }

        // Convert tokens to text
        let text = try decodeTokens(textTokens)

        // Calculate confidence (simplified - in reality, this would come from the model)
        let confidence = calculateConfidence(from: textTokens)

        // Create a single segment for the whole transcription
        let segment = TranscriptionSegment(
            text: text,
            startTime: 0.0,
            endTime: 5.0, // Default 5 second recording
            confidence: confidence
        )

        return TranscriptionResult(
            text: text,
            confidence: confidence,
            segments: [segment],
            language: selectedLanguage
        )
    }

    private func decodeTokens(_ tokens: MLMultiArray) throws -> String {
        // This is a simplified version - in reality, you'd need the tokenizer vocabulary
        // For now, return a placeholder that indicates the model ran
        var tokenIndices: [Int] = []

        for i in 0..<tokens.count {
            let value = tokens[i]
            let tokenId = value.intValue
            if tokenId > 0 { // Skip padding tokens
                tokenIndices.append(tokenId)
            }
        }

        // In a real implementation, you would:
        // 1. Load the tokenizer vocabulary
        // 2. Map token IDs to text
        // 3. Handle special tokens (BOS, EOS, etc.)

        return "Transcribed text would appear here (tokens: \(tokenIndices.count))"
    }

    private func calculateConfidence(from tokens: MLMultiArray) -> Float {
        // Simplified confidence calculation
        // In reality, this would be based on the model's probability outputs
        0.95
    }
}

// MARK: - Complex Number Support

private struct Complex<T: FloatingPoint> {
    let real: T
    let imaginary: T
}

// MARK: - MLFeatureProvider Implementation

private class CoreMLWhisperInput: NSObject, MLFeatureProvider {
    let melSpectrogram: MLMultiArray
    let language: Language

    init(melSpectrogram: MLMultiArray, language: Language) {
        self.melSpectrogram = melSpectrogram
        self.language = language
        super.init()
    }

    var featureNames: Set<String> {
        ["mel_spectrogram", "language_id"]
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "mel_spectrogram":
            return MLFeatureValue(multiArray: melSpectrogram)
        case "language_id":
            // Convert language to model's expected format
            let languageId = getLanguageId(for: language)
            if let languageArray = try? MLMultiArray(shape: [1], dataType: .int32) {
                languageArray[0] = NSNumber(value: languageId)
                return MLFeatureValue(multiArray: languageArray)
            }
        default:
            break
        }
        return nil
    }

    private func getLanguageId(for language: Language) -> Int {
        // Map languages to Whisper's language IDs
        switch language {
        case .english: return 0
        case .spanish: return 1
        case .french: return 2
        case .german: return 3
        case .italian: return 4
        case .portuguese: return 5
        case .dutch: return 6
        case .russian: return 7
        case .chinese: return 8
        case .japanese: return 9
        case .korean: return 10
        @unknown default: return 0 // Default to English
        }
    }
}
