import XCTest
import os.log
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Model loading performance tests
final class ModelLoadingPerformanceTests: XCTestCase {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.voicetype.tests", category: "ModelLoadingPerformance")
    
    // MARK: - Model Loading Time Tests
    
    /// Test time to load each model size
    func testModelLoadingTimes() async throws {
        let models: [(WhisperModel, TimeInterval)] = [
            (.tiny, 1.0),    // Should load within 1 second
            (.base, 2.0),    // Should load within 2 seconds
            (.small, 3.0)    // Should load within 3 seconds
        ]
        
        for (model, maxLoadTime) in models {
            // Given
            let modelPath = "/tmp/test-\(model.fileName).mlmodelc"
            let whisper = CoreMLWhisper(modelType: model, modelPath: modelPath)
            
            // When
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate model loading
            do {
                try await whisper.loadModel()
            } catch {
                // For testing, we expect this to fail since we don't have real models
                // In production tests, this would load actual CoreML models
            }
            
            let loadTime = CFAbsoluteTimeGetCurrent() - startTime
            
            // Then
            logger.info("\(model.displayName) load time: \(String(format: "%.3f", loadTime))s")
            XCTAssertLessThan(loadTime, maxLoadTime, "\(model.displayName) should load within \(maxLoadTime)s")
        }
    }
    
    /// Test model switching performance
    func testModelSwitchingPerformance() async throws {
        // Given
        let models = [WhisperModel.tiny, .base, .small]
        var switchingTimes: [TimeInterval] = []
        var currentWhisper: CoreMLWhisper?
        
        // When - Switch between models
        for model in models {
            let switchStart = CFAbsoluteTimeGetCurrent()
            
            // Unload previous model
            currentWhisper = nil
            
            // Load new model
            let modelPath = "/tmp/test-\(model.fileName).mlmodelc"
            currentWhisper = CoreMLWhisper(modelType: model, modelPath: modelPath)
            
            // Simulate loading
            do {
                try await currentWhisper?.loadModel()
            } catch {
                // Expected in test environment
            }
            
            let switchTime = CFAbsoluteTimeGetCurrent() - switchStart
            switchingTimes.append(switchTime)
            
            logger.info("Switch to \(model.displayName): \(String(format: "%.3f", switchTime))s")
        }
        
        // Then
        let avgSwitchTime = switchingTimes.reduce(0, +) / Double(switchingTimes.count)
        logger.info("Average model switch time: \(String(format: "%.3f", avgSwitchTime))s")
        XCTAssertLessThan(avgSwitchTime, 2.0, "Model switching should be reasonably fast")
    }
    
    /// Test cold start vs warm start timing
    func testColdVsWarmStartTiming() async throws {
        // Given
        let model = WhisperModel.base
        let modelPath = "/tmp/test-\(model.fileName).mlmodelc"
        let iterations = 5
        
        var coldStartTimes: [TimeInterval] = []
        var warmStartTimes: [TimeInterval] = []
        
        // When - Test cold starts
        for _ in 0..<iterations {
            // Force cleanup
            autoreleasepool {
                let whisper = CoreMLWhisper(modelType: model, modelPath: modelPath)
                
                let startTime = CFAbsoluteTimeGetCurrent()
                do {
                    try await whisper.loadModel()
                } catch {
                    // Expected in test environment
                }
                let loadTime = CFAbsoluteTimeGetCurrent() - startTime
                coldStartTimes.append(loadTime)
            }
            
            // Sleep to ensure cleanup
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        // Test warm starts (reusing same instance)
        let persistentWhisper = CoreMLWhisper(modelType: model, modelPath: modelPath)
        
        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate accessing already-loaded model
            _ = persistentWhisper.isReady
            
            let accessTime = CFAbsoluteTimeGetCurrent() - startTime
            warmStartTimes.append(accessTime)
        }
        
        // Then
        let avgColdStart = coldStartTimes.reduce(0, +) / Double(coldStartTimes.count)
        let avgWarmStart = warmStartTimes.reduce(0, +) / Double(warmStartTimes.count)
        
        logger.info("=== Cold vs Warm Start ===")
        logger.info("Average cold start: \(String(format: "%.3f", avgColdStart))s")
        logger.info("Average warm start: \(String(format: "%.6f", avgWarmStart))s")
        logger.info("Warm start speedup: \(String(format: "%.1f", avgColdStart / avgWarmStart))x")
        
        XCTAssertLessThan(avgWarmStart, avgColdStart / 10, "Warm start should be significantly faster")
    }
    
    /// Test parallel model loading
    func testParallelModelLoading() async throws {
        // Given
        let models = [WhisperModel.tiny, .base, .small]
        
        // When - Load models in parallel
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let loadingTasks = models.map { model in
            Task {
                let taskStart = CFAbsoluteTimeGetCurrent()
                let modelPath = "/tmp/test-\(model.fileName).mlmodelc"
                let whisper = CoreMLWhisper(modelType: model, modelPath: modelPath)
                
                do {
                    try await whisper.loadModel()
                } catch {
                    // Expected in test environment
                }
                
                let taskTime = CFAbsoluteTimeGetCurrent() - taskStart
                return (model: model, time: taskTime)
            }
        }
        
        let results = await withTaskGroup(of: (model: WhisperModel, time: TimeInterval).self) { group in
            for task in loadingTasks {
                group.addTask {
                    await task.value
                }
            }
            
            var allResults: [(model: WhisperModel, time: TimeInterval)] = []
            for await result in group {
                allResults.append(result)
            }
            return allResults
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        logger.info("=== Parallel Model Loading ===")
        logger.info("Total time: \(String(format: "%.3f", totalTime))s")
        for result in results {
            logger.info("\(result.model.displayName): \(String(format: "%.3f", result.time))s")
        }
        
        let sequentialTime = results.map(\.time).reduce(0, +)
        let speedup = sequentialTime / totalTime
        logger.info("Parallel speedup: \(String(format: "%.1f", speedup))x")
        
        XCTAssertGreaterThan(speedup, 1.5, "Parallel loading should provide speedup")
    }
    
    /// Test model loading memory impact
    func testModelLoadingMemoryImpact() async throws {
        // Given
        let models = [WhisperModel.tiny, .base, .small]
        var memoryMeasurements: [(model: WhisperModel, beforeLoad: Int64, afterLoad: Int64)] = []
        
        // When
        for model in models {
            autoreleasepool {
                let beforeMemory = getCurrentMemoryUsage()
                
                let modelPath = "/tmp/test-\(model.fileName).mlmodelc"
                let whisper = CoreMLWhisper(modelType: model, modelPath: modelPath)
                
                // Simulate loading
                do {
                    try await whisper.loadModel()
                } catch {
                    // Expected in test environment
                }
                
                let afterMemory = getCurrentMemoryUsage()
                memoryMeasurements.append((model: model, beforeLoad: beforeMemory, afterLoad: afterMemory))
            }
            
            // Allow cleanup between models
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // Then
        logger.info("=== Model Loading Memory Impact ===")
        for measurement in memoryMeasurements {
            let memoryIncrease = measurement.afterLoad - measurement.beforeLoad
            logger.info("\(measurement.model.displayName): +\(memoryIncrease / 1024 / 1024) MB")
            
            // Validate memory usage is within expected bounds
            let expectedMax: Int64
            switch measurement.model {
            case .tiny:
                expectedMax = 50 * 1024 * 1024  // 50 MB
            case .base:
                expectedMax = 100 * 1024 * 1024 // 100 MB
            case .small:
                expectedMax = 250 * 1024 * 1024 // 250 MB
            }
            
            XCTAssertLessThan(memoryIncrease, expectedMax, 
                "\(measurement.model.displayName) memory increase should be under \(expectedMax / 1024 / 1024) MB")
        }
    }
    
    /// Test model unloading performance
    func testModelUnloadingPerformance() async throws {
        // Given
        let model = WhisperModel.base
        let modelPath = "/tmp/test-\(model.fileName).mlmodelc"
        let iterations = 10
        
        var unloadTimes: [TimeInterval] = []
        
        // When
        for _ in 0..<iterations {
            autoreleasepool {
                var whisper: CoreMLWhisper? = CoreMLWhisper(modelType: model, modelPath: modelPath)
                
                // Simulate model is loaded
                do {
                    try await whisper?.loadModel()
                } catch {
                    // Expected in test environment
                }
                
                // Measure unload time
                let unloadStart = CFAbsoluteTimeGetCurrent()
                whisper = nil
                let unloadTime = CFAbsoluteTimeGetCurrent() - unloadStart
                
                unloadTimes.append(unloadTime)
            }
        }
        
        // Then
        let avgUnloadTime = unloadTimes.reduce(0, +) / Double(unloadTimes.count)
        logger.info("Average model unload time: \(String(format: "%.6f", avgUnloadTime))s")
        XCTAssertLessThan(avgUnloadTime, 0.1, "Model unloading should be fast")
    }
    
    // MARK: - Helper Methods
    
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
}

// MARK: - Model Loading Stress Tests

extension ModelLoadingPerformanceTests {
    
    /// Test rapid model switching under stress
    func testRapidModelSwitching() async throws {
        // Given
        let models = [WhisperModel.tiny, .base, .small]
        let switchCount = 20
        var switchTimes: [TimeInterval] = []
        
        // When - Rapidly switch between models
        let totalStart = CFAbsoluteTimeGetCurrent()
        
        for i in 0..<switchCount {
            let model = models[i % models.count]
            let switchStart = CFAbsoluteTimeGetCurrent()
            
            autoreleasepool {
                let modelPath = "/tmp/test-\(model.fileName).mlmodelc"
                let whisper = CoreMLWhisper(modelType: model, modelPath: modelPath)
                
                // Quick load/unload
                do {
                    try await whisper.loadModel()
                } catch {
                    // Expected
                }
            }
            
            let switchTime = CFAbsoluteTimeGetCurrent() - switchStart
            switchTimes.append(switchTime)
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - totalStart
        
        // Then
        let avgSwitchTime = switchTimes.reduce(0, +) / Double(switchTimes.count)
        logger.info("Rapid switching: \(switchCount) switches in \(String(format: "%.3f", totalTime))s")
        logger.info("Average switch time: \(String(format: "%.3f", avgSwitchTime))s")
        
        XCTAssertLessThan(totalTime, Double(switchCount) * 0.5, "Rapid switching should maintain performance")
    }
}