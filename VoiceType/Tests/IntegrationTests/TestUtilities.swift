import Foundation
import XCTest
import Darwin
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Test utilities and helpers for integration tests
public final class TestUtilities {
    
    // MARK: - Audio Test Data
    
    /// Generate test audio data with specified duration and characteristics
    public static func generateTestAudio(
        duration: TimeInterval,
        sampleRate: Double = 16000,
        frequency: Double = 440.0,
        amplitude: Float = 0.5
    ) -> AudioData {
        let sampleCount = Int(duration * sampleRate)
        var samples: [Int16] = []
        
        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            let value = amplitude * Float(sin(2.0 * .pi * frequency * time))
            let int16Value = Int16(value * Float(Int16.max))
            samples.append(int16Value)
        }
        
        return AudioData(samples: samples, sampleRate: sampleRate, channelCount: 1)
    }
    
    /// Load test audio file from bundle
    public static func loadTestAudioFile(named fileName: String) -> AudioData? {
        guard let url = Bundle(for: TestUtilities.self).url(forResource: fileName, withExtension: "wav") else {
            return nil
        }
        
        // In real implementation, would parse WAV file
        // For tests, return mock data
        return generateTestAudio(duration: 3.0)
    }
    
    /// Generate noisy audio data
    public static func generateNoisyAudio(
        duration: TimeInterval,
        noiseLevel: Float = 0.2
    ) -> AudioData {
        let cleanAudio = generateTestAudio(duration: duration)
        var noisySamples = cleanAudio.samples
        
        for i in 0..<noisySamples.count {
            let currentValue = Float(noisySamples[i]) / Float(Int16.max)
            let noise = Float.random(in: -noiseLevel...noiseLevel)
            let newValue = min(max(currentValue + noise, -1.0), 1.0)
            noisySamples[i] = Int16(newValue * Float(Int16.max))
        }
        
        return AudioData(samples: noisySamples, sampleRate: cleanAudio.sampleRate, channelCount: cleanAudio.channelCount)
    }
    
    // MARK: - Performance Measurement
    
    /// Measure execution time of an async operation
    public static func measureTime<T>(
        operation: () async throws -> T
    ) async throws -> (result: T, time: TimeInterval) {
        let start = Date()
        let result = try await operation()
        let elapsed = Date().timeIntervalSince(start)
        return (result, elapsed)
    }
    
    /// Performance metrics collector
    public class PerformanceCollector {
        private var metrics: [String: [TimeInterval]] = [:]
        
        public func record(metric: String, time: TimeInterval) {
            if metrics[metric] == nil {
                metrics[metric] = []
            }
            metrics[metric]?.append(time)
        }
        
        public func average(for metric: String) -> TimeInterval? {
            guard let times = metrics[metric], !times.isEmpty else { return nil }
            return times.reduce(0, +) / Double(times.count)
        }
        
        public func percentile(for metric: String, percentile: Double) -> TimeInterval? {
            guard let times = metrics[metric], !times.isEmpty else { return nil }
            let sorted = times.sorted()
            let index = Int(Double(sorted.count - 1) * percentile / 100.0)
            return sorted[index]
        }
        
        public func report() -> String {
            var report = "Performance Report:\n"
            for (metric, times) in metrics.sorted(by: { $0.key < $1.key }) {
                if let avg = average(for: metric),
                   let p50 = percentile(for: metric, percentile: 50),
                   let p95 = percentile(for: metric, percentile: 95) {
                    report += "\(metric):\n"
                    report += "  Average: \(String(format: "%.3f", avg))s\n"
                    report += "  P50: \(String(format: "%.3f", p50))s\n"
                    report += "  P95: \(String(format: "%.3f", p95))s\n"
                }
            }
            return report
        }
    }
    
    // MARK: - Mock Data Generators
    
    /// Generate mock transcription result
    public static func mockTranscriptionResult(
        text: String = "This is a test transcription",
        confidence: Float = 0.95,
        language: Language = .english
    ) -> TranscriptionResult {
        let words = text.split(separator: " ")
        let segments = words.enumerated().map { index, word in
            TranscriptionSegment(
                text: String(word),
                startTime: TimeInterval(index) * 0.5,
                endTime: TimeInterval(index + 1) * 0.5,
                confidence: confidence
            )
        }
        
        return TranscriptionResult(
            text: text,
            confidence: confidence,
            segments: segments,
            language: language
        )
    }
    
    /// Generate target application for testing
    public static func mockTargetApplication(
        bundleId: String = "com.test.app",
        name: String = "Test App",
        supportsInput: Bool = true
    ) -> TargetApplication {
        return TargetApplication(
            bundleIdentifier: bundleId,
            name: name,
            isActive: true,
            supportsTextInput: supportsInput,
            focusedElement: supportsInput ? TargetApplication.FocusedElement(
                role: "AXTextArea",
                title: "Main Text Field",
                value: ""
            ) : nil
        )
    }
    
    // MARK: - State Verification
    
    /// Wait for a condition to become true
    public static func waitFor(
        condition: @escaping () async -> Bool,
        timeout: TimeInterval = 5.0,
        interval: TimeInterval = 0.1
    ) async throws {
        let start = Date()
        
        while Date().timeIntervalSince(start) < timeout {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        
        throw TestError.timeout("Condition not met within \(timeout) seconds")
    }
    
    /// Wait for coordinator to reach specific state
    public static func waitForState(
        _ coordinator: VoiceTypeCoordinator,
        state: RecordingState,
        timeout: TimeInterval = 5.0
    ) async throws {
        try await waitFor(
            condition: { await coordinator.recordingState == state },
            timeout: timeout
        )
    }
    
    // MARK: - Memory Testing
    
    /// Track memory usage during operation
    public static func trackMemoryUsage<T>(
        during operation: () async throws -> T
    ) async throws -> (result: T, peakMemory: Int64) {
        let initialMemory = getMemoryUsage()
        var peakMemory = initialMemory
        
        let monitorTask = Task {
            while !Task.isCancelled {
                let current = getMemoryUsage()
                peakMemory = max(peakMemory, current)
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
        
        let result = try await operation()
        monitorTask.cancel()
        
        return (result, peakMemory - initialMemory)
    }
    
    private static func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    // MARK: - File System Helpers
    
    /// Create temporary directory for tests
    public static func createTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceTypeTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        
        return tempDir
    }
    
    /// Clean up test files
    public static func cleanupDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Network Simulation
    
    /// Simulate network conditions
    public class NetworkSimulator {
        public enum Condition {
            case normal
            case slow(latency: TimeInterval)
            case failure(after: TimeInterval)
            case intermittent(failureRate: Double)
        }
        
        private var condition: Condition = .normal
        private var requestCount = 0
        
        public func setCondition(_ condition: Condition) {
            self.condition = condition
            requestCount = 0
        }
        
        public func simulateRequest() async throws {
            requestCount += 1
            
            switch condition {
            case .normal:
                return
                
            case .slow(let latency):
                try await Task.sleep(nanoseconds: UInt64(latency * 1_000_000_000))
                
            case .failure(let after):
                try await Task.sleep(nanoseconds: UInt64(after * 1_000_000_000))
                throw VoiceTypeError.networkUnavailable
                
            case .intermittent(let failureRate):
                if Double.random(in: 0...1) < failureRate {
                    throw VoiceTypeError.networkUnavailable
                }
            }
        }
    }
}

// MARK: - Test Errors

enum TestError: LocalizedError {
    case timeout(String)
    case unexpectedState(String)
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .timeout(let message):
            return "Timeout: \(message)"
        case .unexpectedState(let message):
            return "Unexpected state: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        }
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {
    /// Assert async operation completes within timeout
    func assertCompletes<T>(
        within timeout: TimeInterval = 5.0,
        operation: () async throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await withTimeout(seconds: timeout) {
                try await operation()
            }
        } catch {
            XCTFail("Operation failed to complete: \(error)", file: file, line: line)
        }
    }
    
    /// Run async operation with timeout
    func withTimeout<T>(
        seconds: TimeInterval,
        operation: () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TestError.timeout("Operation timed out after \(seconds) seconds")
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Async Stream Test Helpers

extension AsyncStream where Element == Float {
    /// Create test audio level stream
    static func testAudioLevels(
        count: Int = 50,
        interval: TimeInterval = 0.1
    ) -> AsyncStream<Float> {
        AsyncStream { continuation in
            Task {
                for i in 0..<count {
                    let level = Float(i) / Float(count)
                    continuation.yield(level)
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
                continuation.finish()
            }
        }
    }
}

extension AsyncStream where Element == RecordingState {
    /// Create test state change stream
    static func testStateChanges(
        states: [RecordingState],
        interval: TimeInterval = 0.5
    ) -> AsyncStream<RecordingState> {
        AsyncStream { continuation in
            Task {
                for state in states {
                    continuation.yield(state)
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
                continuation.finish()
            }
        }
    }
}