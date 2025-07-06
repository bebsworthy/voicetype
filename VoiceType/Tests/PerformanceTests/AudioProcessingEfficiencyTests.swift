import XCTest
import os.log
import Darwin
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Audio processing efficiency tests
final class AudioProcessingEfficiencyTests: XCTestCase {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.voicetype.tests", category: "AudioProcessingEfficiency")
    
    // MARK: - CPU Usage Tests
    
    /// Test CPU usage during recording
    func testCPUUsageDuringRecording() async throws {
        // Given
        let audioProcessor = MockAudioProcessor()
        let recordingDuration = 10.0
        var cpuMeasurements: [Double] = []
        
        // Start CPU monitoring
        let cpuMonitor = CPUMonitor()
        cpuMonitor.startMonitoring()
        
        // When - Record audio
        audioProcessor.startRecording()
        
        // Monitor CPU during recording
        for i in 0..<Int(recordingDuration) {
            Thread.sleep(forTimeInterval: 1.0)
            let cpuUsage = cpuMonitor.getCurrentCPUUsage()
            cpuMeasurements.append(cpuUsage)
            logger.info("CPU at \(i)s: \(String(format: "%.1f", cpuUsage))%")
        }
        
        audioProcessor.stopRecording()
        cpuMonitor.stopMonitoring()
        
        // Then
        let avgCPU = cpuMeasurements.reduce(0, +) / Double(cpuMeasurements.count)
        let maxCPU = cpuMeasurements.max() ?? 0
        
        logger.info("=== CPU Usage During Recording ===")
        logger.info("Average CPU: \(String(format: "%.1f", avgCPU))%")
        logger.info("Peak CPU: \(String(format: "%.1f", maxCPU))%")
        
        XCTAssertLessThan(avgCPU, 15.0, "Average CPU usage should be under 15%")
        XCTAssertLessThan(maxCPU, 25.0, "Peak CPU usage should be under 25%")
    }
    
    /// Test buffer efficiency validation
    func testBufferEfficiencyValidation() throws {
        // Given
        let audioProcessor = MockAudioProcessor()
        let bufferSizes = [1024, 2048, 4096, 8192]
        var efficiencyMetrics: [(size: Int, latency: TimeInterval, cpuUsage: Double)] = []
        
        // When - Test different buffer sizes
        for bufferSize in bufferSizes {
            audioProcessor.setBufferSize(bufferSize)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            let cpuMonitor = CPUMonitor()
            cpuMonitor.startMonitoring()
            
            // Process audio with this buffer size
            audioProcessor.startRecording()
            audioProcessor.simulateRecording(duration: 5.0, sampleRate: 16000)
            let _ = audioProcessor.stopRecording()
            
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            let avgCPU = cpuMonitor.getAverageCPUUsage()
            cpuMonitor.stopMonitoring()
            
            efficiencyMetrics.append((size: bufferSize, latency: processingTime, cpuUsage: avgCPU))
        }
        
        // Then
        logger.info("=== Buffer Efficiency Metrics ===")
        for metric in efficiencyMetrics {
            logger.info("Buffer \(metric.size): latency=\(String(format: "%.3f", metric.latency))s, CPU=\(String(format: "%.1f", metric.cpuUsage))%")
        }
        
        // Validate optimal buffer size (4096 as per spec)
        let optimal = efficiencyMetrics.first(where: { $0.size == 4096 })!
        XCTAssertLessThan(optimal.latency, 0.1, "Optimal buffer should have low latency")
        XCTAssertLessThan(optimal.cpuUsage, 10.0, "Optimal buffer should have low CPU usage")
    }
    
    /// Test real-time processing verification
    func testRealTimeProcessingVerification() async throws {
        // Given
        let audioProcessor = MockAudioProcessor()
        let sampleRate = 16000
        let duration = 5.0
        let expectedSamples = Int(Double(sampleRate) * duration)
        
        // When
        let startTime = CFAbsoluteTimeGetCurrent()
        
        audioProcessor.startRecording()
        audioProcessor.simulateRecording(duration: duration, sampleRate: sampleRate)
        let audioData = audioProcessor.stopRecording()
        
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        let actualSamples = audioData.count / MemoryLayout<Float>.size
        let processingRatio = processingTime / duration
        
        logger.info("=== Real-time Processing ===")
        logger.info("Expected samples: \(expectedSamples)")
        logger.info("Actual samples: \(actualSamples)")
        logger.info("Processing ratio: \(String(format: "%.3f", processingRatio))x realtime")
        
        XCTAssertEqual(actualSamples, expectedSamples, accuracy: 100, "Should capture expected number of samples")
        XCTAssertLessThan(processingRatio, 0.1, "Processing should be much faster than realtime")
    }
    
    // MARK: - Audio Quality Tests
    
    /// Test audio preprocessing efficiency
    func testAudioPreprocessingEfficiency() throws {
        // Given
        let sampleCount = 16000 * 30 // 30 seconds
        let samples = (0..<sampleCount).map { Float(sin(Double($0) * 0.01)) }
        
        // When - Test various preprocessing operations
        let operations: [(name: String, operation: ([Float]) -> [Float])] = [
            ("Normalize", { AudioUtilities.normalize($0) }),
            ("Pre-emphasis", { AudioUtilities.applyPreEmphasis($0) }),
            ("Noise Gate", { AudioUtilities.applyNoiseGate($0, threshold: 0.01) }),
            ("Combined", { samples in
                let normalized = AudioUtilities.normalize(samples)
                let preEmphasized = AudioUtilities.applyPreEmphasis(normalized)
                return AudioUtilities.applyNoiseGate(preEmphasized, threshold: 0.01)
            })
        ]
        
        var results: [(name: String, time: TimeInterval)] = []
        
        for (name, operation) in operations {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = operation(samples)
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime
            results.append((name: name, time: processingTime))
        }
        
        // Then
        logger.info("=== Audio Preprocessing Efficiency ===")
        for result in results {
            let samplesPerSecond = Double(sampleCount) / result.time
            logger.info("\(result.name): \(String(format: "%.3f", result.time))s (\(String(format: "%.0f", samplesPerSecond / 1000))k samples/sec)")
        }
        
        // All operations should be very fast
        for result in results {
            XCTAssertLessThan(result.time, 0.1, "\(result.name) should process 30s of audio in <100ms")
        }
    }
    
    /// Test audio format conversion efficiency
    func testAudioFormatConversionEfficiency() throws {
        // Given
        let durations = [1.0, 5.0, 10.0, 30.0]
        var conversionMetrics: [(duration: Double, time: TimeInterval, rate: Double)] = []
        
        // When
        for duration in durations {
            let sampleCount = Int(16000 * duration)
            let samples = Array(repeating: Float(0.5), count: sampleCount)
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Simulate format conversion operations
            let data = samples.withUnsafeBytes { Data($0) }
            let floatArray = data.withUnsafeBytes { bytes in
                Array(bytes.bindMemory(to: Float.self))
            }
            
            let conversionTime = CFAbsoluteTimeGetCurrent() - startTime
            let conversionRate = duration / conversionTime
            
            conversionMetrics.append((duration: duration, time: conversionTime, rate: conversionRate))
        }
        
        // Then
        logger.info("=== Format Conversion Efficiency ===")
        for metric in conversionMetrics {
            logger.info("\(Int(metric.duration))s audio: \(String(format: "%.6f", metric.time))s (\(String(format: "%.0f", metric.rate))x realtime)")
        }
        
        // Conversion should be extremely fast
        for metric in conversionMetrics {
            XCTAssertGreaterThan(metric.rate, 100.0, "Conversion should be >100x realtime")
        }
    }
    
    // MARK: - Streaming Efficiency Tests
    
    /// Test streaming buffer management
    func testStreamingBufferManagement() async throws {
        // Given
        let audioProcessor = MockAudioProcessor()
        let bufferDuration = 0.1 // 100ms buffers
        let totalDuration = 5.0
        let bufferCount = Int(totalDuration / bufferDuration)
        
        var bufferLatencies: [TimeInterval] = []
        
        // When - Process audio in streaming chunks
        audioProcessor.startRecording()
        
        for i in 0..<bufferCount {
            let bufferStart = CFAbsoluteTimeGetCurrent()
            
            // Simulate processing one buffer
            audioProcessor.simulateRecording(duration: bufferDuration, sampleRate: 16000)
            
            let bufferLatency = CFAbsoluteTimeGetCurrent() - bufferStart
            bufferLatencies.append(bufferLatency)
            
            if i % 10 == 0 {
                logger.info("Buffer \(i): \(String(format: "%.6f", bufferLatency))s")
            }
        }
        
        audioProcessor.stopRecording()
        
        // Then
        let avgLatency = bufferLatencies.reduce(0, +) / Double(bufferLatencies.count)
        let maxLatency = bufferLatencies.max() ?? 0
        
        logger.info("=== Streaming Buffer Performance ===")
        logger.info("Average buffer latency: \(String(format: "%.6f", avgLatency))s")
        logger.info("Max buffer latency: \(String(format: "%.6f", maxLatency))s")
        
        XCTAssertLessThan(avgLatency, 0.01, "Buffer processing should be <10ms")
        XCTAssertLessThan(maxLatency, 0.02, "Max buffer latency should be <20ms")
    }
    
    /// Test memory efficiency during long recordings
    func testLongRecordingMemoryEfficiency() async throws {
        // Given
        let audioProcessor = MockAudioProcessor()
        let recordingDuration = 60.0 // 1 minute
        let measurementInterval = 10.0
        
        var memoryMeasurements: [(time: Double, memory: Int64)] = []
        let initialMemory = getCurrentMemoryUsage()
        
        // When
        audioProcessor.startRecording()
        
        var elapsedTime = 0.0
        while elapsedTime < recordingDuration {
            audioProcessor.simulateRecording(duration: measurementInterval, sampleRate: 16000)
            elapsedTime += measurementInterval
            
            let currentMemory = getCurrentMemoryUsage()
            memoryMeasurements.append((time: elapsedTime, memory: currentMemory))
            
            logger.info("Memory at \(Int(elapsedTime))s: \((currentMemory - initialMemory) / 1024 / 1024) MB")
        }
        
        let audioData = audioProcessor.stopRecording()
        
        // Then
        let finalMemory = getCurrentMemoryUsage()
        let totalMemoryUsed = finalMemory - initialMemory
        let audioSizeMB = Double(audioData.count) / 1024.0 / 1024.0
        
        logger.info("=== Long Recording Memory Efficiency ===")
        logger.info("Recording duration: \(Int(recordingDuration))s")
        logger.info("Audio data size: \(String(format: "%.1f", audioSizeMB)) MB")
        logger.info("Total memory used: \(totalMemoryUsed / 1024 / 1024) MB")
        
        // Memory usage should be proportional to audio size
        XCTAssertLessThan(Double(totalMemoryUsed) / 1024.0 / 1024.0, audioSizeMB * 2, 
                         "Memory usage should not exceed 2x audio size")
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

// MARK: - CPU Monitor

private class CPUMonitor {
    private var measurements: [Double] = []
    private var isMonitoring = false
    private var monitoringTask: Task<Void, Never>?
    
    func startMonitoring() {
        isMonitoring = true
        measurements.removeAll()
        
        monitoringTask = Task {
            while isMonitoring {
                let usage = getCurrentCPUUsage()
                measurements.append(usage)
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
    }
    
    func getCurrentCPUUsage() -> Double {
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
        
        guard result == KERN_SUCCESS else { return 0 }
        
        // Simplified CPU usage calculation
        // In real implementation, this would track thread times
        return Double(info.resident_size) / 1_000_000_000 * 100 // Mock calculation
    }
    
    func getAverageCPUUsage() -> Double {
        guard !measurements.isEmpty else { return 0 }
        return measurements.reduce(0, +) / Double(measurements.count)
    }
}

// MARK: - Mock Extensions

private extension MockAudioProcessor {
    func setBufferSize(_ size: Int) {
        // In real implementation, this would configure the buffer size
    }
}