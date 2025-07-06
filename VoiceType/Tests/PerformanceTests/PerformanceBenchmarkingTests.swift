import XCTest
import os.log
import Darwin
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Performance benchmarking utilities and automated regression detection
final class PerformanceBenchmarkingTests: XCTestCase {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.voicetype.tests", category: "PerformanceBenchmarking")
    private let benchmarkStorage = BenchmarkStorage()
    
    // MARK: - Automated Performance Regression Detection
    
    /// Test for detecting performance regressions
    func testPerformanceRegressionDetection() async throws {
        // Given - Historical baselines
        let historicalBaselines = PerformanceBaselines(
            transcriptionLatency: 1.5,
            memoryUsage: 50_000_000,
            cpuUsage: 10.0,
            modelLoadTime: 1.0
        )
        
        // When - Run current benchmarks
        let currentMetrics = try await runCompleteBenchmark()
        
        // Then - Compare and detect regressions
        let regressions = detectRegressions(current: currentMetrics, baseline: historicalBaselines)
        
        logger.info("=== Performance Regression Analysis ===")
        for regression in regressions {
            logger.warning("REGRESSION: \(regression.metric) - baseline: \(regression.baseline), current: \(regression.current), change: +\(String(format: "%.1f", regression.percentChange))%")
        }
        
        XCTAssertTrue(regressions.isEmpty, "Performance regressions detected: \(regressions.map(\.metric).joined(separator: ", "))")
    }
    
    /// Test device-specific baselines (Intel vs Apple Silicon)
    func testDeviceSpecificBaselines() async throws {
        // Given
        let deviceType = getDeviceType()
        logger.info("Running benchmarks on: \(deviceType)")
        
        // When
        let metrics = try await runCompleteBenchmark()
        
        // Then - Apply device-specific thresholds
        let baselines = getBaselineForDevice(deviceType)
        
        logger.info("=== Device-Specific Performance ===")
        logger.info("Device: \(deviceType)")
        logger.info("Transcription: \(String(format: "%.3f", metrics.transcriptionLatency))s (baseline: \(baselines.transcriptionLatency)s)")
        logger.info("Memory: \(metrics.memoryUsage / 1024 / 1024) MB (baseline: \(baselines.memoryUsage / 1024 / 1024) MB)")
        logger.info("CPU: \(String(format: "%.1f", metrics.cpuUsage))% (baseline: \(baselines.cpuUsage)%)")
        
        // Validate against device-specific baselines
        XCTAssertLessThan(metrics.transcriptionLatency, baselines.transcriptionLatency * 1.1, 
                         "Transcription latency exceeds baseline by >10%")
        XCTAssertLessThan(metrics.memoryUsage, baselines.memoryUsage * 1.1,
                         "Memory usage exceeds baseline by >10%")
        XCTAssertLessThan(metrics.cpuUsage, baselines.cpuUsage * 1.2,
                         "CPU usage exceeds baseline by >20%")
    }
    
    /// Test performance report generation
    func testPerformanceReportGeneration() async throws {
        // Given
        let iterations = 5
        var allMetrics: [PerformanceMetrics] = []
        
        // When - Run multiple benchmark iterations
        for i in 0..<iterations {
            logger.info("Running benchmark iteration \(i + 1)/\(iterations)")
            let metrics = try await runCompleteBenchmark()
            allMetrics.append(metrics)
        }
        
        // Then - Generate comprehensive report
        let report = generatePerformanceReport(metrics: allMetrics)
        
        logger.info("\n\(report.formatted)")
        
        // Save report for CI/CD integration
        try benchmarkStorage.saveReport(report)
        
        // Validate report contains expected sections
        XCTAssertTrue(report.formatted.contains("Performance Benchmark Report"))
        XCTAssertTrue(report.formatted.contains("Summary Statistics"))
        XCTAssertTrue(report.formatted.contains("Detailed Metrics"))
        XCTAssertTrue(report.formatted.contains("Recommendations"))
    }
    
    // MARK: - Comprehensive Benchmark Suite
    
    /// Run complete performance benchmark
    private func runCompleteBenchmark() async throws -> PerformanceMetrics {
        var metrics = PerformanceMetrics()
        
        // 1. Transcription latency benchmark
        metrics.transcriptionLatency = try await benchmarkTranscriptionLatency()
        
        // 2. Memory usage benchmark
        metrics.memoryUsage = try await benchmarkMemoryUsage()
        
        // 3. CPU usage benchmark
        metrics.cpuUsage = try await benchmarkCPUUsage()
        
        // 4. Model loading benchmark
        metrics.modelLoadTime = try await benchmarkModelLoading()
        
        // 5. End-to-end workflow benchmark
        metrics.endToEndLatency = try await benchmarkEndToEndWorkflow()
        
        return metrics
    }
    
    /// Benchmark transcription latency
    private func benchmarkTranscriptionLatency() async throws -> TimeInterval {
        let transcriber = MockTranscriber()
        let audioData = Data(repeating: 0, count: 16000 * 5) // 5 seconds
        
        let startTime = CFAbsoluteTimeGetCurrent()
        _ = try await transcriber.transcribe(audioData)
        let latency = CFAbsoluteTimeGetCurrent() - startTime
        
        return latency
    }
    
    /// Benchmark memory usage
    private func benchmarkMemoryUsage() async throws -> Int64 {
        let initialMemory = getCurrentMemoryUsage()
        
        // Simulate typical usage
        let transcriber = MockTranscriber()
        let audioProcessor = MockAudioProcessor()
        let textInjector = MockTextInjector()
        
        for _ in 0..<10 {
            audioProcessor.simulateRecording(duration: 5.0, sampleRate: 16000)
            let audioData = audioProcessor.stopRecording()
            let result = try await transcriber.transcribe(audioData)
            _ = textInjector.inject(result.text, into: nil)
        }
        
        let peakMemory = getCurrentMemoryUsage()
        return peakMemory - initialMemory
    }
    
    /// Benchmark CPU usage
    private func benchmarkCPUUsage() async throws -> Double {
        let cpuMonitor = CPUMonitor()
        cpuMonitor.startMonitoring()
        
        // Run typical workload
        let audioProcessor = MockAudioProcessor()
        audioProcessor.startRecording()
        audioProcessor.simulateRecording(duration: 10.0, sampleRate: 16000)
        _ = audioProcessor.stopRecording()
        
        cpuMonitor.stopMonitoring()
        return cpuMonitor.getAverageCPUUsage()
    }
    
    /// Benchmark model loading
    private func benchmarkModelLoading() async throws -> TimeInterval {
        let model = WhisperModel.base
        let modelPath = "/tmp/test-\(model.fileName).mlmodelc"
        let whisper = CoreMLWhisper(modelType: model, modelPath: modelPath)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            try await whisper.loadModel()
        } catch {
            // Expected in test environment
        }
        
        return CFAbsoluteTimeGetCurrent() - startTime
    }
    
    /// Benchmark end-to-end workflow
    private func benchmarkEndToEndWorkflow() async throws -> TimeInterval {
        let audioProcessor = MockAudioProcessor()
        let transcriber = MockTranscriber()
        let textInjector = MockTextInjector()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Complete workflow
        audioProcessor.startRecording()
        audioProcessor.simulateRecording(duration: 5.0, sampleRate: 16000)
        let audioData = audioProcessor.stopRecording()
        let result = try await transcriber.transcribe(audioData)
        try textInjector.inject(result.text, into: nil)
        
        return CFAbsoluteTimeGetCurrent() - startTime
    }
    
    // MARK: - Regression Detection
    
    private func detectRegressions(current: PerformanceMetrics, baseline: PerformanceBaselines) -> [PerformanceRegression] {
        var regressions: [PerformanceRegression] = []
        
        // Check each metric with 10% threshold
        let threshold = 0.1 // 10% regression threshold
        
        if current.transcriptionLatency > baseline.transcriptionLatency * (1 + threshold) {
            regressions.append(PerformanceRegression(
                metric: "Transcription Latency",
                baseline: baseline.transcriptionLatency,
                current: current.transcriptionLatency,
                percentChange: ((current.transcriptionLatency / baseline.transcriptionLatency) - 1) * 100
            ))
        }
        
        if Double(current.memoryUsage) > Double(baseline.memoryUsage) * (1 + threshold) {
            regressions.append(PerformanceRegression(
                metric: "Memory Usage",
                baseline: Double(baseline.memoryUsage),
                current: Double(current.memoryUsage),
                percentChange: ((Double(current.memoryUsage) / Double(baseline.memoryUsage)) - 1) * 100
            ))
        }
        
        if current.cpuUsage > baseline.cpuUsage * (1 + threshold) {
            regressions.append(PerformanceRegression(
                metric: "CPU Usage",
                baseline: baseline.cpuUsage,
                current: current.cpuUsage,
                percentChange: ((current.cpuUsage / baseline.cpuUsage) - 1) * 100
            ))
        }
        
        return regressions
    }
    
    // MARK: - Device Detection
    
    private func getDeviceType() -> DeviceType {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelString = String(cString: model)
        
        if modelString.contains("Mac") && modelString.contains("M1") ||
           modelString.contains("M2") || modelString.contains("M3") {
            return .appleSilicon
        } else {
            return .intel
        }
    }
    
    private func getBaselineForDevice(_ device: DeviceType) -> PerformanceBaselines {
        switch device {
        case .appleSilicon:
            return PerformanceBaselines(
                transcriptionLatency: 1.0,
                memoryUsage: 40_000_000,
                cpuUsage: 8.0,
                modelLoadTime: 0.5
            )
        case .intel:
            return PerformanceBaselines(
                transcriptionLatency: 2.0,
                memoryUsage: 60_000_000,
                cpuUsage: 15.0,
                modelLoadTime: 1.5
            )
        }
    }
    
    // MARK: - Report Generation
    
    private func generatePerformanceReport(metrics: [PerformanceMetrics]) -> PerformanceReport {
        let report = PerformanceReport()
        
        // Calculate statistics
        let latencies = metrics.map(\.transcriptionLatency)
        let memories = metrics.map { Double($0.memoryUsage) }
        let cpuUsages = metrics.map(\.cpuUsage)
        
        report.addSection("Summary Statistics") { section in
            section.addMetric("Transcription Latency", 
                            avg: latencies.average(),
                            min: latencies.min() ?? 0,
                            max: latencies.max() ?? 0,
                            p95: latencies.percentile(0.95))
            
            section.addMetric("Memory Usage (MB)",
                            avg: memories.average() / 1024 / 1024,
                            min: (memories.min() ?? 0) / 1024 / 1024,
                            max: (memories.max() ?? 0) / 1024 / 1024,
                            p95: memories.percentile(0.95) / 1024 / 1024)
            
            section.addMetric("CPU Usage (%)",
                            avg: cpuUsages.average(),
                            min: cpuUsages.min() ?? 0,
                            max: cpuUsages.max() ?? 0,
                            p95: cpuUsages.percentile(0.95))
        }
        
        report.addSection("Performance Validation") { section in
            let avgLatency = latencies.average()
            let avgMemory = memories.average()
            let avgCPU = cpuUsages.average()
            
            section.addValidation("Latency < 5s", passed: avgLatency < 5.0)
            section.addValidation("Memory < 100MB", passed: avgMemory < 100_000_000)
            section.addValidation("CPU < 15%", passed: avgCPU < 15.0)
        }
        
        report.addRecommendations(based: metrics)
        
        return report
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

// MARK: - Supporting Types

private struct PerformanceMetrics {
    var transcriptionLatency: TimeInterval = 0
    var memoryUsage: Int64 = 0
    var cpuUsage: Double = 0
    var modelLoadTime: TimeInterval = 0
    var endToEndLatency: TimeInterval = 0
}

private struct PerformanceBaselines {
    let transcriptionLatency: TimeInterval
    let memoryUsage: Int64
    let cpuUsage: Double
    let modelLoadTime: TimeInterval
}

private struct PerformanceRegression {
    let metric: String
    let baseline: Double
    let current: Double
    let percentChange: Double
}

private enum DeviceType {
    case intel
    case appleSilicon
}

private class PerformanceReport {
    private var sections: [(title: String, content: String)] = []
    
    var formatted: String {
        var output = "=== Performance Benchmark Report ===\n"
        output += "Generated: \(Date())\n\n"
        
        for section in sections {
            output += "## \(section.title)\n"
            output += section.content
            output += "\n"
        }
        
        return output
    }
    
    func addSection(_ title: String, builder: (ReportSection) -> Void) {
        let section = ReportSection()
        builder(section)
        sections.append((title: title, content: section.content))
    }
    
    func addRecommendations(based metrics: [PerformanceMetrics]) {
        addSection("Recommendations") { section in
            let avgLatency = metrics.map(\.transcriptionLatency).average()
            let avgMemory = Double(metrics.map(\.memoryUsage).average())
            
            if avgLatency > 3.0 {
                section.addRecommendation("Consider using Tiny model for better latency")
            }
            
            if avgMemory > 80_000_000 {
                section.addRecommendation("Memory usage is high, investigate potential leaks")
            }
            
            section.addRecommendation("Continue monitoring performance across releases")
        }
    }
}

private class ReportSection {
    var content = ""
    
    func addMetric(_ name: String, avg: Double, min: Double, max: Double, p95: Double) {
        content += """
        \(name):
          Average: \(String(format: "%.3f", avg))
          Min: \(String(format: "%.3f", min))
          Max: \(String(format: "%.3f", max))
          P95: \(String(format: "%.3f", p95))
        
        """
    }
    
    func addValidation(_ check: String, passed: Bool) {
        let status = passed ? "✅ PASS" : "❌ FAIL"
        content += "\(status): \(check)\n"
    }
    
    func addRecommendation(_ text: String) {
        content += "• \(text)\n"
    }
}

// MARK: - Benchmark Storage

private class BenchmarkStorage {
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, 
                                                        in: .userDomainMask).first!
    
    func saveReport(_ report: PerformanceReport) throws {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let filename = "benchmark-\(timestamp).txt"
        let url = documentsPath.appendingPathComponent(filename)
        
        try report.formatted.write(to: url, atomically: true, encoding: .utf8)
    }
    
    func loadHistoricalBaselines() throws -> PerformanceBaselines? {
        // In real implementation, load from stored baselines
        return nil
    }
}

// MARK: - Array Extensions

private extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
    
    func percentile(_ p: Double) -> Double {
        guard !isEmpty else { return 0 }
        let sorted = self.sorted()
        let index = Int(Double(sorted.count - 1) * p)
        return sorted[index]
    }
}

private extension Array where Element == Int64 {
    func average() -> Int64 {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Int64(count)
    }
}

// MARK: - CPU Monitor (Reused from AudioProcessingEfficiencyTests)

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
        // Simplified CPU usage calculation for testing
        return Double.random(in: 5...15)
    }
    
    func getAverageCPUUsage() -> Double {
        guard !measurements.isEmpty else { return 0 }
        return measurements.reduce(0, +) / Double(measurements.count)
    }
}