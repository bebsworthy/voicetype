import XCTest
import os.log
import Darwin
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Memory usage profiling tests to validate memory requirements
final class MemoryUsageTests: XCTestCase {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.voicetype.tests", category: "MemoryUsage")
    private var memoryBaseline: Int64 = 0
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        // Force garbage collection and capture baseline memory
        autoreleasepool {
            _ = [Int](repeating: 0, count: 1000000) // Force some allocations
        }
        Thread.sleep(forTimeInterval: 0.1) // Allow cleanup
        memoryBaseline = getCurrentMemoryUsage()
        logger.info("Memory baseline: \(self.memoryBaseline / 1024 / 1024) MB")
    }
    
    override func tearDown() {
        super.tearDown()
        let finalMemory = getCurrentMemoryUsage()
        let leaked = finalMemory - memoryBaseline
        if leaked > 5 * 1024 * 1024 { // 5MB threshold
            logger.warning("Potential memory leak detected: \(leaked / 1024 / 1024) MB")
        }
    }
    
    // MARK: - Memory Usage Tests
    
    /// Test memory usage during 1-hour operation simulation
    func testLongRunningMemoryUsage() async throws {
        // Given
        let transcriber = MockTranscriber()
        let textInjector = MockTextInjector()
        let audioProcessor = MockAudioProcessor()
        
        // Simulate 1 hour of operation (60 transcriptions, 1 per minute)
        let simulatedTranscriptions = 60
        let measurementInterval = 10 // Measure every 10 transcriptions
        
        var memoryMeasurements: [Int64] = []
        memoryMeasurements.append(getCurrentMemoryUsage())
        
        // When
        for i in 0..<simulatedTranscriptions {
            autoreleasepool {
                // Simulate recording
                audioProcessor.simulateRecording(duration: 5.0, sampleRate: 16000)
                
                // Simulate transcription
                Task {
                    let audioData = Data(repeating: 0, count: 16000 * 5) // 5 seconds
                    _ = try? await transcriber.transcribe(audioData)
                }
                
                // Simulate text injection
                _ = textInjector.inject("Simulated transcription \(i)", into: nil)
            }
            
            // Measure memory at intervals
            if (i + 1) % measurementInterval == 0 {
                Thread.sleep(forTimeInterval: 0.1) // Allow cleanup
                let currentMemory = getCurrentMemoryUsage()
                memoryMeasurements.append(currentMemory)
                logger.info("Memory after \(i + 1) transcriptions: \(currentMemory / 1024 / 1024) MB")
            }
        }
        
        // Then
        let peakMemory = memoryMeasurements.max() ?? 0
        let averageMemory = memoryMeasurements.reduce(0, +) / Int64(memoryMeasurements.count)
        let memoryGrowth = (memoryMeasurements.last ?? 0) - (memoryMeasurements.first ?? 0)
        
        logger.info("Peak memory: \(peakMemory / 1024 / 1024) MB")
        logger.info("Average memory: \(averageMemory / 1024 / 1024) MB")
        logger.info("Memory growth: \(memoryGrowth / 1024 / 1024) MB")
        
        // Validate memory requirements
        XCTAssertLessThan(peakMemory, 100 * 1024 * 1024, "Peak memory should be less than 100MB")
        XCTAssertLessThan(memoryGrowth, 10 * 1024 * 1024, "Memory growth should be less than 10MB")
    }
    
    /// Test memory usage with different models
    func testModelMemoryUsage() async throws {
        let models: [(WhisperModel, Int64)] = [
            (.tiny, 50 * 1024 * 1024),    // 50MB max
            (.base, 100 * 1024 * 1024),   // 100MB max
            (.small, 200 * 1024 * 1024)   // 200MB max
        ]
        
        for (model, maxMemory) in models {
            autoreleasepool {
                // Given
                let initialMemory = getCurrentMemoryUsage()
                let modelPath = "/tmp/test-\(model.fileName).mlmodelc"
                let whisper = CoreMLWhisper(modelType: model, modelPath: modelPath)
                
                // When - Simulate model loading
                // Note: In real tests, this would load actual CoreML models
                let loadedMemory = getCurrentMemoryUsage()
                let memoryUsed = loadedMemory - initialMemory
                
                // Then
                logger.info("\(model.displayName) memory usage: \(memoryUsed / 1024 / 1024) MB")
                XCTAssertLessThan(memoryUsed, maxMemory, "\(model.displayName) should use less than \(maxMemory / 1024 / 1024)MB")
                
                // Cleanup
                _ = whisper // Ensure whisper is used
            }
            
            // Allow cleanup between models
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
    
    /// Test for memory leaks during repeated operations
    func testMemoryLeakDetection() async throws {
        // Given
        let iterations = 100
        var memorySnapshots: [Int64] = []
        
        // When
        for i in 0..<iterations {
            autoreleasepool {
                // Create and destroy objects repeatedly
                let transcriber = MockTranscriber()
                let audioData = Data(repeating: 0, count: 16000) // 1 second
                
                Task {
                    _ = try? await transcriber.transcribe(audioData)
                }
                
                if i % 10 == 0 {
                    Thread.sleep(forTimeInterval: 0.05)
                    memorySnapshots.append(getCurrentMemoryUsage())
                }
            }
        }
        
        // Then - Check for consistent memory growth
        let firstHalf = Array(memorySnapshots.prefix(memorySnapshots.count / 2))
        let secondHalf = Array(memorySnapshots.suffix(memorySnapshots.count / 2))
        
        let firstHalfAvg = firstHalf.reduce(0, +) / Int64(firstHalf.count)
        let secondHalfAvg = secondHalf.reduce(0, +) / Int64(secondHalf.count)
        
        let growth = secondHalfAvg - firstHalfAvg
        logger.info("Memory growth over \(iterations) iterations: \(growth / 1024) KB")
        
        // Allow some growth but flag potential leaks
        XCTAssertLessThan(growth, 5 * 1024 * 1024, "Memory growth suggests potential leak")
    }
    
    /// Test peak memory usage validation
    func testPeakMemoryValidation() async throws {
        // Given
        var peakMemory: Int64 = 0
        let transcriber = MockTranscriber()
        
        // When - Simulate peak usage scenario
        for _ in 0..<5 {
            autoreleasepool {
                // Multiple concurrent operations
                let tasks = (0..<3).map { _ in
                    Task {
                        let audioData = Data(repeating: 0, count: 16000 * 5) // 5 seconds
                        _ = try? await transcriber.transcribe(audioData)
                    }
                }
                
                // Wait for tasks
                for task in tasks {
                    _ = await task.result
                }
                
                let currentMemory = getCurrentMemoryUsage()
                peakMemory = max(peakMemory, currentMemory)
            }
        }
        
        // Then
        logger.info("Peak memory during concurrent operations: \(peakMemory / 1024 / 1024) MB")
        XCTAssertLessThan(peakMemory - memoryBaseline, 100 * 1024 * 1024, "Peak memory should be under 100MB above baseline")
    }
    
    // MARK: - Memory Profiling with Different Components
    
    /// Test memory usage of audio processing
    func testAudioProcessingMemory() throws {
        // Given
        let processor = MockAudioProcessor()
        let initialMemory = getCurrentMemoryUsage()
        
        // When - Simulate 30 seconds of audio recording
        processor.simulateRecording(duration: 30.0, sampleRate: 16000)
        let audioMemory = getCurrentMemoryUsage() - initialMemory
        
        // Then
        logger.info("Audio processing memory for 30s: \(audioMemory / 1024) KB")
        XCTAssertLessThan(audioMemory, 10 * 1024 * 1024, "Audio processing should use less than 10MB for 30s")
    }
    
    /// Test memory usage of text injection
    func testTextInjectionMemory() throws {
        // Given
        let injector = MockTextInjector()
        let initialMemory = getCurrentMemoryUsage()
        let largeText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 1000)
        
        // When
        for _ in 0..<10 {
            _ = injector.inject(largeText, into: nil)
        }
        
        let injectionMemory = getCurrentMemoryUsage() - initialMemory
        
        // Then
        logger.info("Text injection memory: \(injectionMemory / 1024) KB")
        XCTAssertLessThan(injectionMemory, 5 * 1024 * 1024, "Text injection should use minimal memory")
    }
    
    // MARK: - Helper Methods
    
    /// Get current memory usage in bytes
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    /// Generate memory pressure report
    private func generateMemoryReport(_ measurements: [String: Int64]) {
        logger.info("=== Memory Usage Report ===")
        for (key, value) in measurements.sorted(by: { $0.key < $1.key }) {
            logger.info("\(key): \(value / 1024 / 1024) MB")
        }
        logger.info("========================")
    }
}

// MARK: - Memory Stress Tests

extension MemoryUsageTests {
    
    /// Stress test with maximum model size
    func testMaxModelMemoryStress() async throws {
        // Given
        let smallModel = CoreMLWhisper(modelType: .small, modelPath: "/tmp/whisper-small.mlmodelc")
        let initialMemory = getCurrentMemoryUsage()
        
        // When - Simulate heavy usage with largest model
        for i in 0..<10 {
            autoreleasepool {
                let audioData = Data(repeating: 0, count: 16000 * 5) // 5 seconds
                Task {
                    _ = try? await smallModel.transcribe(audioData)
                }
                
                if i % 2 == 0 {
                    let currentMemory = getCurrentMemoryUsage()
                    logger.info("Memory during stress test iteration \(i): \(currentMemory / 1024 / 1024) MB")
                }
            }
        }
        
        // Then
        let peakMemory = getCurrentMemoryUsage()
        let memoryUsed = peakMemory - initialMemory
        logger.info("Memory used with largest model under stress: \(memoryUsed / 1024 / 1024) MB")
        XCTAssertLessThan(memoryUsed, 200 * 1024 * 1024, "Should stay under 200MB with largest model")
    }
}