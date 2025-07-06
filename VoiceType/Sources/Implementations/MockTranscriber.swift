import Foundation

/// Mock implementation of Transcriber for testing purposes
public class MockTranscriber: Transcriber {
    // MARK: - Configuration
    
    public enum MockBehavior {
        case success(text: String, confidence: Float = 0.95)
        case failure(TranscriberError)
        case delayed(text: String, delay: TimeInterval)
        case sequence([MockBehavior])
    }
    
    // MARK: - Properties
    
    private var behavior: MockBehavior
    private var sequenceIndex = 0
    private let queue = DispatchQueue(label: "com.voicetype.mock.transcriber")
    
    public var isReady: Bool = true
    public var selectedLanguage: TranscriptionLanguage = .english
    public var supportedLanguages: [TranscriptionLanguage] = TranscriptionLanguage.allCases
    
    // Tracking for testing
    public private(set) var transcribeCallCount = 0
    public private(set) var lastAudioDataSize: Int?
    public private(set) var transcriptionHistory: [TranscriptionResult] = []
    
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
    
    public func transcribe(_ audioData: Data) async throws -> TranscriptionResult {
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
    
    // MARK: - Private Methods
    
    private func processBehavior(_ behavior: MockBehavior, audioData: Data, completion: @escaping (Result<TranscriptionResult, Error>) -> Void) {
        switch behavior {
        case .success(let text, let confidence):
            let result = TranscriptionResult(
                text: text,
                confidence: confidence,
                language: selectedLanguage,
                metadata: [
                    "mock": true,
                    "audioDataSize": audioData.count
                ]
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
                
                let result = TranscriptionResult(
                    text: text,
                    confidence: 0.9,
                    language: self.selectedLanguage,
                    metadata: [
                        "mock": true,
                        "delayed": true,
                        "delay": delay
                    ]
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
        public static let notLoaded = MockBehavior.failure(.modelNotLoaded)
        
        /// Invalid audio data error
        public static let invalidAudio = MockBehavior.failure(.invalidAudioData)
        
        /// Generic transcription failure
        public static let failed = MockBehavior.failure(.transcriptionFailed(reason: "Mock failure"))
        
        /// Slow response (2 seconds)
        public static let slow = MockBehavior.delayed(text: "This took a while...", delay: 2.0)
        
        /// Alternating success and failure
        public static let alternating = MockBehavior.sequence([
            .success(text: "First transcription", confidence: 0.95),
            .failure(.transcriptionFailed(reason: "Network error")),
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