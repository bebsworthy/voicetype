import Foundation
import VoiceTypeCore

/// Mock implementation of Transcriber for testing purposes
public class MockTranscriber: Transcriber {
    // MARK: - Configuration
    
    public enum MockBehavior {
        case success(text: String, confidence: Float = 0.95)
        case failure(TranscriberError)
        case delayed(text: String, delay: TimeInterval)
        case sequence([MockBehavior])
        
        var shouldFailModelLoading: Bool {
            switch self {
            case .failure(.modelLoadingFailed):
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Properties
    
    private var behavior: MockBehavior
    private var sequenceIndex = 0
    private let queue = DispatchQueue(label: "com.voicetype.mock.transcriber")
    
    public var isReady: Bool = true
    public var selectedLanguage: Language = .english
    public var supportedLanguages: [Language] = Language.allCases
    
    // Tracking for testing
    public private(set) var transcribeCallCount = 0
    public private(set) var lastAudioDataSize: Int?
    public private(set) var transcriptionHistory: [TranscriptionResult] = []
    
    public var modelInfo: ModelInfo {
        ModelInfo(
            type: .fast,
            version: "1.0-mock",
            path: URL(fileURLWithPath: "/mock/path"),
            sizeInBytes: 0,
            isLoaded: isReady,
            lastUsed: Date()
        )
    }
    
    public var isModelLoaded: Bool {
        return isReady
    }
    
    // MARK: - Initialization
    
    public init(behavior: MockBehavior = .success(text: "Hello, world!", confidence: 0.95)) {
        self.behavior = behavior
    }
    
    // MARK: - Configuration Methods
    
    /// Change the mock behavior
    public func setBehavior(_ behavior: MockBehavior) {
        queue.sync {
            self.behavior = behavior
            self.sequenceIndex = 0
        }
    }
    
    /// Reset all tracking counters
    public func reset() {
        queue.sync {
            self.transcribeCallCount = 0
            self.lastAudioDataSize = nil
            self.transcriptionHistory.removeAll()
            self.sequenceIndex = 0
        }
    }
    
    /// Simulate the model not being ready
    public func setReady(_ ready: Bool) {
        queue.sync {
            self.isReady = ready
        }
    }
    
    // MARK: - Transcriber Protocol
    
    public func transcribe(_ audio: AudioData, language: Language?) async throws -> TranscriptionResult {
        let audioData = Data(audio.samples.flatMap { [$0].withUnsafeBytes { Data($0) } })
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: TranscriberError.transcriptionFailed(reason: "Mock instance deallocated"))
                    return
                }
                
                // Update tracking
                self.transcribeCallCount += 1
                self.lastAudioDataSize = audioData.count
                
                // Check if ready
                guard self.isReady else {
                    continuation.resume(throwing: TranscriberError.modelNotLoaded)
                    return
                }
                
                // Check audio data
                guard audioData.count > 0 else {
                    continuation.resume(throwing: TranscriberError.invalidAudioData)
                    return
                }
                
                // Process based on behavior
                self.processBehavior(self.behavior, audioData: audioData) { result in
                    switch result {
                    case .success(let transcriptionResult):
                        self.transcriptionHistory.append(transcriptionResult)
                        continuation.resume(returning: transcriptionResult)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    public func loadModel(_ type: ModelType) async throws {
        // Simulate model loading
        isReady = true
    }
    
    // MARK: - Private Methods
    
    private func processBehavior(_ behavior: MockBehavior, audioData: Data, completion: @escaping (Result<TranscriptionResult, Error>) -> Void) {
        switch behavior {
        case .success(let text, let confidence):
            let segment = TranscriptionSegment(
                text: text,
                startTime: 0.0,
                endTime: 1.0,
                confidence: confidence
            )
            let result = TranscriptionResult(
                text: text,
                confidence: confidence,
                segments: [segment],
                language: selectedLanguage
            )
            completion(.success(result))
            
        case .failure(let error):
            completion(.failure(error))
            
        case .delayed(let text, let delay):
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else {
                    completion(.failure(TranscriberError.transcriptionFailed(reason: "Mock instance deallocated")))
                    return
                }
                
                let segment = TranscriptionSegment(
                    text: text,
                    startTime: 0.0,
                    endTime: delay,
                    confidence: 0.9
                )
                let result = TranscriptionResult(
                    text: text,
                    confidence: 0.9,
                    segments: [segment],
                    language: self.selectedLanguage
                )
                completion(.success(result))
            }
            
        case .sequence(let behaviors):
            if sequenceIndex < behaviors.count {
                let currentBehavior = behaviors[sequenceIndex]
                sequenceIndex = (sequenceIndex + 1) % behaviors.count
                processBehavior(currentBehavior, audioData: audioData, completion: completion)
            } else {
                completion(.failure(TranscriberError.transcriptionFailed(reason: "No more behaviors in sequence")))
            }
        }
    }
}

// MARK: - Convenience Extensions

public extension MockTranscriber {
    /// Common mock scenarios
    struct Scenarios {
        /// Successful transcription with high confidence
        public static let success = MockBehavior.success(text: "This is a successful transcription.", confidence: 0.98)
        
        /// Successful but low confidence
        public static let lowConfidence = MockBehavior.success(text: "Not sure about this...", confidence: 0.45)
        
        /// Model not loaded error
        public static let notLoaded = MockBehavior.failure(TranscriberError.modelNotLoaded)
        
        /// Invalid audio data error
        public static let invalidAudio = MockBehavior.failure(TranscriberError.invalidAudioData)
        
        /// Generic transcription failure
        public static let failed = MockBehavior.failure(TranscriberError.transcriptionFailed(reason: "Mock failure"))
        
        /// Slow response (2 seconds)
        public static let slow = MockBehavior.delayed(text: "This took a while...", delay: 2.0)
        
        /// Alternating success and failure
        public static let alternating = MockBehavior.sequence([
            .success(text: "First transcription", confidence: 0.95),
            .failure(TranscriberError.transcriptionFailed(reason: "Network error")),
            .success(text: "Third transcription", confidence: 0.92)
        ])
        
        /// Different languages sequence
        public static func multiLanguage() -> MockBehavior {
            return .sequence([
                .success(text: "Hello, how are you?", confidence: 0.96),
                .success(text: "Hola, ¿cómo estás?", confidence: 0.94),
                .success(text: "Bonjour, comment allez-vous?", confidence: 0.93),
                .success(text: "Hallo, wie geht es dir?", confidence: 0.95)
            ])
        }
        
        /// Simulates improving accuracy over time
        public static let learningCurve = MockBehavior.sequence([
            .success(text: "Helo word", confidence: 0.65),
            .success(text: "Hello word", confidence: 0.78),
            .success(text: "Hello world", confidence: 0.89),
            .success(text: "Hello, world!", confidence: 0.97)
        ])
    }
    
    /// Configure with a specific scenario
    convenience init(scenario: MockBehavior) {
        self.init(behavior: scenario)
    }
}