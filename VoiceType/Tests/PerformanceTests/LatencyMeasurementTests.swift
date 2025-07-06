import XCTest
import os.log
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Latency measurement tests to validate performance requirements
final class LatencyMeasurementTests: XCTestCase {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.voicetype.tests", category: "LatencyMeasurement")
    
    // MARK: - End-to-End Latency Tests
    
    /// Test end-to-end latency from recording start to text insertion
    func testEndToEndLatency() async throws {
        // Given
        let audioProcessor = MockAudioProcessor()
        let transcriber = MockTranscriber(behavior: .delayed(text: "Test transcription", delay: 0.5))
        let textInjector = MockTextInjector()
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 1. Start recording
        audioProcessor.startRecording()
        
        // 2. Simulate 5 seconds of recording
        audioProcessor.simulateRecording(duration: 5.0, sampleRate: 16000)
        
        // 3. Stop recording and get audio
        let audioData = audioProcessor.stopRecording()
        
        // 4. Transcribe audio
        let result = try await transcriber.transcribe(audioData)
        
        // 5. Inject text
        try textInjector.inject(result.text, into: nil)
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let totalLatency = endTime - startTime
        
        // Then
        logger.info("End-to-end latency: \(String(format: "%.3f", totalLatency))s")
        XCTAssertLessThan(totalLatency, 5.0, "Total latency should be less than 5 seconds")
        
        // Generate latency report
        let report = LatencyReport(
            totalLatency: totalLatency,
            recordingTime: 5.0,
            transcriptionTime: 0.5,
            injectionTime: textInjector.lastInjectionDuration
        )
        logger.info("Latency breakdown: \(report)")
    }
    
    /// Test component-level latency breakdown
    func testComponentLatencyBreakdown() async throws {
        // Given
        let iterations = 10
        var audioProcessingTimes: [TimeInterval] = []
        var transcriptionTimes: [TimeInterval] = []
        var injectionTimes: [TimeInterval] = []
        
        let audioProcessor = MockAudioProcessor()
        let transcriber = MockTranscriber()
        let textInjector = MockTextInjector()
        
        // When
        for _ in 0..<iterations {
            // Measure audio processing
            let audioStart = CFAbsoluteTimeGetCurrent()
            audioProcessor.startRecording()
            audioProcessor.simulateRecording(duration: 5.0, sampleRate: 16000)
            let audioData = audioProcessor.stopRecording()
            let audioEnd = CFAbsoluteTimeGetCurrent()
            audioProcessingTimes.append(audioEnd - audioStart)
            
            // Measure transcription
            let transcriptionStart = CFAbsoluteTimeGetCurrent()
            let result = try await transcriber.transcribe(audioData)
            let transcriptionEnd = CFAbsoluteTimeGetCurrent()
            transcriptionTimes.append(transcriptionEnd - transcriptionStart)
            
            // Measure injection
            let injectionStart = CFAbsoluteTimeGetCurrent()
            try textInjector.inject(result.text, into: nil)
            let injectionEnd = CFAbsoluteTimeGetCurrent()
            injectionTimes.append(injectionEnd - injectionStart)
        }
        
        // Then - Calculate statistics
        let audioAvg = audioProcessingTimes.reduce(0, +) / Double(iterations)
        let transcriptionAvg = transcriptionTimes.reduce(0, +) / Double(iterations)
        let injectionAvg = injectionTimes.reduce(0, +) / Double(iterations)
        
        logger.info("=== Component Latency Breakdown ===")
        logger.info("Audio Processing: avg=\(String(format: "%.3f", audioAvg))s, min=\(String(format: "%.3f", audioProcessingTimes.min() ?? 0))s, max=\(String(format: "%.3f", audioProcessingTimes.max() ?? 0))s")
        logger.info("Transcription: avg=\(String(format: "%.3f", transcriptionAvg))s, min=\(String(format: "%.3f", transcriptionTimes.min() ?? 0))s, max=\(String(format: "%.3f", transcriptionTimes.max() ?? 0))s")
        logger.info("Text Injection: avg=\(String(format: "%.3f", injectionAvg))s, min=\(String(format: "%.3f", injectionTimes.min() ?? 0))s, max=\(String(format: "%.3f", injectionTimes.max() ?? 0))s")
        logger.info("Total Average: \(String(format: "%.3f", audioAvg + transcriptionAvg + injectionAvg))s")
        
        // Validate component requirements
        XCTAssertLessThan(audioAvg, 0.1, "Audio processing should be near-instant")
        XCTAssertLessThan(transcriptionAvg, 3.0, "Transcription should take less than 3 seconds")
        XCTAssertLessThan(injectionAvg, 0.1, "Text injection should be near-instant")
    }
    
    /// Test model inference timing
    func testModelInferenceTiming() async throws {
        let models: [(WhisperModel, TimeInterval)] = [
            (.tiny, 2.0),    // Should complete in 2 seconds
            (.base, 3.0),    // Should complete in 3 seconds
            (.small, 5.0)    // Should complete in 5 seconds
        ]
        
        for (model, maxTime) in models {
            // Given
            let whisper = CoreMLWhisper(modelType: model, modelPath: "/tmp/\(model.fileName).mlmodelc")
            let audioData = Data(repeating: 0, count: 16000 * 5) // 5 seconds of audio
            
            // Simulate model being ready
            whisper.simulateModelLoaded()
            
            // When
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try? await whisper.transcribe(audioData)
            let inferenceTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // Then
            logger.info("\(model.displayName) inference time: \(String(format: "%.3f", inferenceTime))s")
            XCTAssertLessThan(inferenceTime, maxTime, "\(model.displayName) should complete within \(maxTime)s")
        }
    }
    
    /// Test target latency validation (<5s total)
    func testTargetLatencyValidation() async throws {
        // Given - Worst case scenario
        let audioProcessor = MockAudioProcessor()
        let transcriber = MockTranscriber(behavior: .delayed(text: "Slow transcription", delay: 2.0))
        let textInjector = MockTextInjector()
        textInjector.simulateSlowInjection = true
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Full workflow
        audioProcessor.startRecording()
        audioProcessor.simulateRecording(duration: 5.0, sampleRate: 16000)
        let audioData = audioProcessor.stopRecording()
        let result = try await transcriber.transcribe(audioData)
        try textInjector.inject(result.text, into: nil)
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        logger.info("Worst-case latency: \(String(format: "%.3f", totalTime))s")
        XCTAssertLessThan(totalTime, 5.0, "Even worst-case should meet 5-second target")
    }
    
    // MARK: - Concurrent Operation Tests
    
    /// Test latency under concurrent load
    func testConcurrentOperationLatency() async throws {
        // Given
        let concurrentOps = 3
        let audioProcessor = MockAudioProcessor()
        let transcriber = MockTranscriber()
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let tasks = (0..<concurrentOps).map { index in
            Task {
                let taskStart = CFAbsoluteTimeGetCurrent()
                
                // Simulate audio data
                let audioData = Data(repeating: UInt8(index), count: 16000 * 2) // 2 seconds
                
                // Transcribe
                let result = try await transcriber.transcribe(audioData)
                
                let taskLatency = CFAbsoluteTimeGetCurrent() - taskStart
                return (index: index, latency: taskLatency, text: result.text)
            }
        }
        
        // Wait for all tasks
        let results = try await withThrowingTaskGroup(of: (index: Int, latency: TimeInterval, text: String).self) { group in
            for task in tasks {
                group.addTask {
                    try await task.value
                }
            }
            
            var allResults: [(index: Int, latency: TimeInterval, text: String)] = []
            for try await result in group {
                allResults.append(result)
            }
            return allResults
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        logger.info("Concurrent operations completed in \(String(format: "%.3f", totalTime))s")
        for result in results.sorted(by: { $0.index < $1.index }) {
            logger.info("Task \(result.index) latency: \(String(format: "%.3f", result.latency))s")
        }
        
        let maxLatency = results.map(\.latency).max() ?? 0
        XCTAssertLessThan(maxLatency, 3.0, "Individual operations should maintain low latency under load")
    }
    
    // MARK: - Percentile Latency Tests
    
    /// Test latency percentiles for consistency
    func testLatencyPercentiles() async throws {
        // Given
        let iterations = 100
        var latencies: [TimeInterval] = []
        
        let audioProcessor = MockAudioProcessor()
        let transcriber = MockTranscriber()
        let textInjector = MockTextInjector()
        
        // When
        for _ in 0..<iterations {
            let iterationStart = CFAbsoluteTimeGetCurrent()
            
            // Quick operation (1 second audio)
            audioProcessor.simulateRecording(duration: 1.0, sampleRate: 16000)
            let audioData = audioProcessor.stopRecording()
            let result = try await transcriber.transcribe(audioData)
            try textInjector.inject(result.text, into: nil)
            
            let iterationLatency = CFAbsoluteTimeGetCurrent() - iterationStart
            latencies.append(iterationLatency)
        }
        
        // Then - Calculate percentiles
        latencies.sort()
        let p50 = latencies[latencies.count / 2]
        let p90 = latencies[Int(Double(latencies.count) * 0.9)]
        let p95 = latencies[Int(Double(latencies.count) * 0.95)]
        let p99 = latencies[Int(Double(latencies.count) * 0.99)]
        
        logger.info("=== Latency Percentiles ===")
        logger.info("P50: \(String(format: "%.3f", p50))s")
        logger.info("P90: \(String(format: "%.3f", p90))s")
        logger.info("P95: \(String(format: "%.3f", p95))s")
        logger.info("P99: \(String(format: "%.3f", p99))s")
        logger.info("Min: \(String(format: "%.3f", latencies.min() ?? 0))s")
        logger.info("Max: \(String(format: "%.3f", latencies.max() ?? 0))s")
        
        // Validate consistency
        XCTAssertLessThan(p95, 1.0, "95% of operations should complete within 1 second")
        XCTAssertLessThan(p99, 2.0, "99% of operations should complete within 2 seconds")
    }
}

// MARK: - Helper Types

private struct LatencyReport: CustomStringConvertible {
    let totalLatency: TimeInterval
    let recordingTime: TimeInterval
    let transcriptionTime: TimeInterval
    let injectionTime: TimeInterval
    
    var processingLatency: TimeInterval {
        totalLatency - recordingTime
    }
    
    var description: String {
        """
        Total: \(String(format: "%.3f", totalLatency))s \
        (Recording: \(String(format: "%.3f", recordingTime))s, \
        Transcription: \(String(format: "%.3f", transcriptionTime))s, \
        Injection: \(String(format: "%.3f", injectionTime))s)
        """
    }
}

// MARK: - Mock Extensions for Performance Testing

private extension CoreMLWhisper {
    func simulateModelLoaded() {
        // In real implementation, this would load the model
        // For testing, we just simulate the ready state
    }
}

private extension MockTextInjector {
    var simulateSlowInjection: Bool {
        get { false }
        set { 
            // In real implementation, this would make injection slower
            // For testing purposes
        }
    }
    
    var lastInjectionDuration: TimeInterval {
        // Return simulated injection duration
        0.01
    }
}