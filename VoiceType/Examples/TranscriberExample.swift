import Foundation
import AVFoundation

/// Example usage of the CoreMLWhisper transcriber
@main
struct TranscriberExample {
    static func main() async {
        print("VoiceType Transcriber Example")
        print("============================\n")
        
        // Example 1: Using Mock Transcriber
        await runMockTranscriberExample()
        
        print("\n")
        
        // Example 2: Using CoreML Whisper (requires model file)
        await runCoreMLWhisperExample()
        
        print("\n")
        
        // Example 3: Processing audio from file
        await runAudioFileExample()
    }
    
    // MARK: - Mock Transcriber Example
    
    static func runMockTranscriberExample() async {
        print("1. Mock Transcriber Example")
        print("--------------------------")
        
        // Create mock transcriber
        let transcriber = TranscriberFactory.createMock(scenario: .success)
        
        // Create fake audio data
        let fakeAudioData = Data(repeating: 0, count: 16000 * 4) // 1 second of silence
        
        do {
            // Transcribe
            let result = try await transcriber.transcribe(fakeAudioData)
            
            print("Transcription: \(result.text)")
            print("Confidence: \(result.confidence)")
            print("Language: \(result.language.displayName)")
            
            // Test different scenarios
            let mockTranscriber = transcriber as! MockTranscriber
            
            // Low confidence scenario
            mockTranscriber.setBehavior(MockTranscriber.Scenarios.lowConfidence)
            let lowConfResult = try await transcriber.transcribe(fakeAudioData)
            print("\nLow confidence result: \(lowConfResult.text) (confidence: \(lowConfResult.confidence))")
            
            // Error scenario
            mockTranscriber.setBehavior(MockTranscriber.Scenarios.invalidAudio)
            do {
                _ = try await transcriber.transcribe(Data())
            } catch {
                print("Expected error: \(error.localizedDescription)")
            }
            
        } catch {
            print("Error: \(error)")
        }
    }
    
    // MARK: - CoreML Whisper Example
    
    static func runCoreMLWhisperExample() async {
        print("2. CoreML Whisper Example")
        print("-------------------------")
        
        // Check if model exists
        let modelPath = "/path/to/whisper-tiny.mlmodelc"
        
        guard FileManager.default.fileExists(atPath: modelPath) else {
            print("Model file not found at: \(modelPath)")
            print("Please download and convert a Whisper model to CoreML format")
            return
        }
        
        // Create CoreML transcriber
        let transcriber = CoreMLWhisper(modelType: .tiny, modelPath: modelPath)
        
        do {
            // Load model
            print("Loading model...")
            try await transcriber.loadModel()
            print("Model loaded successfully")
            
            // Create test audio (1 second of sine wave)
            let sampleRate: Double = 16000
            let frequency: Double = 440.0 // A4 note
            let duration: Double = 1.0
            
            let sampleCount = Int(sampleRate * duration)
            var audioSamples = [Float](repeating: 0, count: sampleCount)
            
            for i in 0..<sampleCount {
                let time = Double(i) / sampleRate
                audioSamples[i] = Float(sin(2.0 * .pi * frequency * time)) * 0.5
            }
            
            let audioData = audioSamples.withUnsafeBytes { Data($0) }
            
            // Transcribe
            print("Transcribing audio...")
            let result = try await transcriber.transcribe(audioData)
            
            print("Transcription: \(result.text)")
            print("Confidence: \(result.confidence)")
            print("Language: \(result.language.displayName)")
            
        } catch {
            print("Error: \(error)")
        }
    }
    
    // MARK: - Audio File Example
    
    static func runAudioFileExample() async {
        print("3. Audio File Processing Example")
        print("--------------------------------")
        
        let audioFilePath = "/path/to/audio/file.wav"
        
        guard FileManager.default.fileExists(atPath: audioFilePath) else {
            print("Audio file not found at: \(audioFilePath)")
            return
        }
        
        do {
            // Load audio file
            let audioFile = try AVAudioFile(forReading: URL(fileURLWithPath: audioFilePath))
            let format = audioFile.processingFormat
            let frameCount = AVAudioFrameCount(audioFile.length)
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                print("Failed to create audio buffer")
                return
            }
            
            try audioFile.read(into: buffer)
            
            // Convert to Whisper format
            let audioData = try AudioUtilities.convertToWhisperFormat(buffer)
            print("Audio loaded: \(audioData.count / 4) samples at 16kHz")
            
            // Create transcriber (using mock for this example)
            let transcriber = TranscriberFactory.createMock(scenario: .delayed(text: "Audio file transcription result", delay: 1.0))
            
            // Transcribe
            print("Transcribing...")
            let startTime = Date()
            let result = try await transcriber.transcribe(audioData)
            let processingTime = Date().timeIntervalSince(startTime)
            
            print("Transcription: \(result.text)")
            print("Processing time: \(String(format: "%.2f", processingTime)) seconds")
            
        } catch {
            print("Error: \(error)")
        }
    }
}

// MARK: - Helper Extensions

extension TranscriberExample {
    /// Demonstrate language selection
    static func demonstrateLanguageSelection() async {
        print("\nLanguage Selection Demo")
        print("-----------------------")
        
        let transcriber = TranscriberFactory.createMock()
        
        // List supported languages
        print("Supported languages:")
        for language in transcriber.supportedLanguages {
            print("  - \(language.displayName) (\(language.rawValue))")
        }
        
        // Change language
        transcriber.selectedLanguage = .spanish
        print("\nSelected language: \(transcriber.selectedLanguage.displayName)")
        
        // Transcribe with Spanish
        let audioData = Data(repeating: 0, count: 16000)
        
        if let mockTranscriber = transcriber as? MockTranscriber {
            mockTranscriber.setBehavior(.success(text: "Hola, ¿cómo estás?", confidence: 0.94))
        }
        
        do {
            let result = try await transcriber.transcribe(audioData)
            print("Spanish transcription: \(result.text)")
        } catch {
            print("Error: \(error)")
        }
    }
    
    /// Demonstrate batch processing
    static func demonstrateBatchProcessing() async {
        print("\nBatch Processing Demo")
        print("---------------------")
        
        let transcriber = TranscriberFactory.createMock(scenario: MockTranscriber.Scenarios.learningCurve)
        
        // Process multiple audio chunks
        let chunks = 4
        for i in 0..<chunks {
            let audioData = Data(repeating: UInt8(i), count: 16000)
            
            do {
                let result = try await transcriber.transcribe(audioData)
                print("Chunk \(i + 1): \(result.text) (confidence: \(result.confidence))")
            } catch {
                print("Chunk \(i + 1) error: \(error)")
            }
        }
    }
}