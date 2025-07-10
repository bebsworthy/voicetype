import Foundation
import VoiceTypeCore
import WhisperKit

/// Internal wrapper to handle WhisperKit result types without exposing them
struct WhisperKitResultWrapper {
    let text: String
    let segments: [WhisperKitSegment]
    let language: String?

    struct WhisperKitSegment {
        let text: String
        let start: Float
        let end: Float
        let avgLogprob: Float
    }

    /// Extract result data from WhisperKit results using reflection
    static func wrapResults(_ results: Any?) -> WhisperKitResultWrapper {
        // Use reflection to avoid naming the WhisperKit types directly
        guard let resultsArray = results as? [Any], !resultsArray.isEmpty else {
            return WhisperKitResultWrapper(text: "", segments: [], language: nil)
        }

        var allText = ""
        var allSegments: [WhisperKitSegment] = []
        var detectedLanguage: String?

        for result in resultsArray {
            let mirror = Mirror(reflecting: result)

            // Extract text
            if let text = mirror.descendant("text") as? String {
                allText += text + " "
            }

            // Extract language
            if detectedLanguage == nil,
               let language = mirror.descendant("language") as? String {
                detectedLanguage = language
            }

            // Extract segments
            if let segments = mirror.descendant("segments") as? [Any] {
                for segment in segments {
                    let segmentMirror = Mirror(reflecting: segment)

                    if let text = segmentMirror.descendant("text") as? String,
                       let start = segmentMirror.descendant("start") as? Float,
                       let end = segmentMirror.descendant("end") as? Float,
                       let avgLogprob = segmentMirror.descendant("avgLogprob") as? Float {
                        let wrappedSegment = WhisperKitSegment(
                            text: text,
                            start: start,
                            end: end,
                            avgLogprob: avgLogprob
                        )
                        allSegments.append(wrappedSegment)
                    }
                }
            }
        }

        return WhisperKitResultWrapper(
            text: allText.trimmingCharacters(in: .whitespacesAndNewlines),
            segments: allSegments,
            language: detectedLanguage
        )
    }
}

/// WhisperKit-based implementation of the Transcriber protocol for real speech recognition
public class WhisperKitTranscriber: Transcriber {
    // MARK: - Properties

    private var whisperKit: WhisperKit?
    private var currentModelType: ModelType?
    private var currentDynamicModelId: String?
    private let queue = DispatchQueue(label: "com.voicetype.whisperkit.transcriber")

    // MARK: - Transcriber Protocol Properties

    public var modelInfo: ModelInfo {
        guard let modelType = currentModelType else {
            return ModelInfo(
                type: .fast,
                version: "0.0",
                path: URL(fileURLWithPath: "/"),
                sizeInBytes: 0,
                isLoaded: false,
                lastUsed: nil
            )
        }

        return ModelInfo(
            type: modelType,
            version: "1.0",
            path: URL(fileURLWithPath: getModelPath(for: modelType)),
            sizeInBytes: getModelSize(for: modelType),
            isLoaded: whisperKit != nil,
            lastUsed: Date()
        )
    }

    public var supportedLanguages: [Language] {
        // WhisperKit supports all languages that Whisper supports
        Language.allCases
    }

    public var isModelLoaded: Bool {
        whisperKit != nil
    }

    // MARK: - Model Mapping

    /// Maps VoiceType ModelType to WhisperKit model names
    private func getWhisperKitModelName(for type: ModelType) -> String {
        switch type {
        case .fast:
            return "openai_whisper-tiny"
        case .balanced:
            return "openai_whisper-base"
        case .accurate:
            return "openai_whisper-small"
        }
    }

    /// Returns the approximate model size in bytes
    private func getModelSize(for type: ModelType) -> Int64 {
        switch type {
        case .fast:
            return 39 * 1024 * 1024 // ~39MB
        case .balanced:
            return 74 * 1024 * 1024 // ~74MB
        case .accurate:
            return 244 * 1024 * 1024 // ~244MB
        }
    }

    /// Returns the model path (this will be managed by WhisperKit)
    private func getModelPath(for type: ModelType) -> String {
        "~/Library/Application Support/WhisperKit/\(getWhisperKitModelName(for: type))"
    }

    // MARK: - Initialization

    public init() {
        // WhisperKit will be initialized when loading a model
    }

    // MARK: - Transcriber Protocol Methods

    public func transcribe(_ audio: AudioData, language: Language?) async throws -> VoiceTypeCore.TranscriptionResult {
        guard let whisperKit = whisperKit else {
            throw TranscriberError.modelNotLoaded
        }

        // Validate audio data
        guard !audio.samples.isEmpty else {
            throw TranscriberError.invalidAudioData
        }
        
        // Debug audio data
        print("🎤 WhisperKit Audio Debug:")
        print("   Samples: \(audio.samples.count)")
        print("   Duration: \(Double(audio.samples.count) / audio.sampleRate) seconds")
        print("   Sample Rate: \(audio.sampleRate) Hz")
        print("   Channels: \(audio.channelCount)")
        
        // Check audio levels
        let maxSample = audio.samples.map { abs($0) }.max() ?? 0
        let avgSample = audio.samples.reduce(Int32(0)) { $0 + Int32(abs($1)) } / Int32(max(audio.samples.count, 1))
        print("   Max Sample: \(maxSample) (out of \(Int16.max))")
        print("   Avg Sample: \(avgSample)")
        print("   Max Amplitude: \(Float(maxSample) / Float(Int16.max) * 100)%")
        
        if maxSample < 100 {
            print("⚠️ WARNING: Audio appears to be silent or very quiet!")
        }

        // Set decoding options
        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: language.map(mapLanguageToWhisperKit),
            temperature: 0.0,
            temperatureFallbackCount: 3,
            sampleLength: 224,
            usePrefillPrompt: true,
            usePrefillCache: true,
            detectLanguage: language == nil
        )

        // Convert Int16 samples to Float using the built-in normalized samples
        let floatArray = audio.normalizedSamples
        
        // Debug normalized samples
        let maxFloat = floatArray.map { abs($0) }.max() ?? 0
        print("   Normalized Max: \(maxFloat)")
        
        // WhisperKit expects 16kHz audio
        if audio.sampleRate != 16000 {
            print("⚠️ WARNING: WhisperKit expects 16kHz audio but got \(audio.sampleRate) Hz")
        }

        do {
            // Perform transcription
            let whisperKitResults = try await whisperKit.transcribe(
                audioArray: floatArray,
                decodeOptions: options
            )

            // Wrap the results to avoid type conflicts
            let wrappedResults = WhisperKitResultWrapper.wrapResults(whisperKitResults)
            return processWrappedResults(wrappedResults, requestedLanguage: language)
        } catch {
            throw TranscriberError.transcriptionFailed(reason: error.localizedDescription)
        }
    }

    public func loadModel(_ type: ModelType) async throws {
        // Unload current model if any
        if whisperKit != nil {
            whisperKit = nil
            currentModelType = nil
        }

        do {
            // Initialize WhisperKit with the specified model
            let modelName = getWhisperKitModelName(for: type)

            // Get the model path from WhisperKitModelManager
            let modelManager = await WhisperKitModelManager()
            
            // If model is already downloaded, use its path
            let modelFolder: String?
            if let modelPath = await modelManager.getModelPath(modelType: type) {
                // Use the model path directly - it already points to the model directory
                modelFolder = modelPath.path
                print("📁 Using existing model at: \(modelFolder ?? "nil")")
                
                // List contents to verify
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: modelFolder ?? "") {
                    print("📦 Model directory contents:")
                    for file in contents {
                        print("   - \(file)")
                    }
                }
            } else {
                // Let WhisperKit download it
                modelFolder = nil
                print("📥 Model not found locally, will download")
            }
            
            // Create WhisperKit configuration
            let computeOptions = ModelComputeOptions(
                audioEncoderCompute: .cpuAndGPU,
                textDecoderCompute: .cpuAndGPU
            )
            
            let config = WhisperKitConfig(
                model: modelName,
                downloadBase: nil, // Let WhisperKit use its defaults
                modelRepo: nil, // Let WhisperKit use its default repo
                modelFolder: modelFolder,
                computeOptions: computeOptions,
                verbose: true,  // Enable verbose logging
                logLevel: .debug,  // Enable debug logging
                prewarm: true,
                load: true,
                download: modelFolder == nil // Only download if we don't have a local path
            )

            // Initialize WhisperKit
            whisperKit = try await WhisperKit(config)
            currentModelType = type
        } catch {
            throw TranscriberError.modelLoadingFailed("Failed to load WhisperKit model: \(error.localizedDescription)")
        }
    }
    
    /// Load a dynamic WhisperKit model by ID
    public func loadDynamicModel(_ modelId: String) async throws {
        // Unload current model if any
        if whisperKit != nil {
            whisperKit = nil
            currentModelType = nil
            currentDynamicModelId = nil
        }

        do {
            // Get the model path from WhisperKitModelManager
            let modelManager = WhisperKitModelManager()
            
            // If model is already downloaded, use its path
            let modelFolder: String?
            if let modelPath = modelManager.getDynamicModelPath(modelId: modelId) {
                // Use the model path directly - it already points to the model directory
                modelFolder = modelPath.path
                print("📁 Using existing dynamic model at: \(modelFolder ?? "nil")")
                
                // List contents to verify
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: modelFolder ?? "") {
                    print("📦 Model directory contents:")
                    for file in contents {
                        print("   - \(file)")
                    }
                }
            } else {
                // Let WhisperKit download it
                modelFolder = nil
                print("📥 Dynamic model not found locally, will download")
            }
            
            // Create WhisperKit configuration
            let computeOptions = ModelComputeOptions(
                audioEncoderCompute: .cpuAndGPU,
                textDecoderCompute: .cpuAndGPU
            )
            
            let config = WhisperKitConfig(
                model: modelId,
                downloadBase: nil, // Let WhisperKit use its defaults
                modelRepo: nil, // Let WhisperKit use its default repo
                modelFolder: modelFolder,
                computeOptions: computeOptions,
                verbose: true,  // Enable verbose logging
                logLevel: .debug,  // Enable debug logging
                prewarm: true,
                load: true,
                download: modelFolder == nil // Only download if we don't have a local path
            )

            // Initialize WhisperKit
            whisperKit = try await WhisperKit(config)
            currentDynamicModelId = modelId
        } catch {
            throw TranscriberError.modelLoadingFailed("Failed to load WhisperKit model '\(modelId)': \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    /// Maps VoiceType Language to WhisperKit language code
    private func mapLanguageToWhisperKit(_ language: Language) -> String {
        // WhisperKit uses the same ISO 639-1 language codes
        language.rawValue
    }

    /// Process wrapped WhisperKit results into VoiceType TranscriptionResult
    private func processWrappedResults(_ wrapped: WhisperKitResultWrapper, requestedLanguage: Language?) -> VoiceTypeCore.TranscriptionResult {
        var allSegments: [VoiceTypeCore.TranscriptionSegment] = []
        var totalLogProb = 0.0
        var segmentCount = 0

        // Convert wrapped segments to VoiceType segments
        for segment in wrapped.segments {
            // Convert log probability to confidence (0-1 range)
            let confidence = Float(exp(segment.avgLogprob))

            let transcriptionSegment = VoiceTypeCore.TranscriptionSegment(
                text: segment.text,
                startTime: TimeInterval(segment.start),
                endTime: TimeInterval(segment.end),
                confidence: confidence
            )
            allSegments.append(transcriptionSegment)

            totalLogProb += Double(segment.avgLogprob)
            segmentCount += 1
        }

        // Calculate average confidence
        let avgLogProb = segmentCount > 0 ? totalLogProb / Double(segmentCount) : -1.0
        let averageConfidence = Float(exp(avgLogProb))

        // Determine language
        let detectedLanguage: Language
        if let requested = requestedLanguage {
            detectedLanguage = requested
        } else if let langCode = wrapped.language {
            // Try to map the language code to our Language enum
            detectedLanguage = Language.allCases.first { $0.rawValue == langCode } ?? .english
        } else {
            detectedLanguage = .english
        }

        return VoiceTypeCore.TranscriptionResult(
            text: wrapped.text,
            confidence: averageConfidence,
            segments: allSegments,
            language: detectedLanguage
        )
    }
}

// MARK: - WhisperKit Configuration Extension

extension WhisperKitTranscriber {
    /// Configuration options for WhisperKit
    public struct Configuration {
        /// Whether to use Voice Activity Detection
        public var useVAD: Bool = true

        /// Whether to enable real-time streaming
        public var enableStreaming: Bool = false

        /// Maximum audio length in seconds
        public var maxAudioLength: TimeInterval = 30.0

        /// Whether to use GPU acceleration
        public var useGPU: Bool = true

        public init() {}
    }

    /// Apply configuration to WhisperKit
    public func configure(_ configuration: Configuration) {
        // Store configuration for use when initializing WhisperKit
        // This will be used in future updates for streaming support
    }
}
