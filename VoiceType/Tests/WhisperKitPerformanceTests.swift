import XCTest
import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Performance tests for WhisperKit integration
class WhisperKitPerformanceTests: XCTestCase {
    var transcriber: WhisperKitTranscriber!
    var modelManager: WhisperKitModelManager!

    override func setUp() async throws {
        try await super.setUp()
        transcriber = WhisperKitTranscriber()
        modelManager = WhisperKitModelManager()
    }

    override func tearDown() async throws {
        transcriber = nil
        modelManager = nil
        try await super.tearDown()
    }

    // MARK: - Transcription Performance Tests

    func testTranscriptionSpeedFastModel() async throws {
        try await measureTranscriptionSpeed(for: .fast, expectedRealTimeFactor: 5.0)
    }

    func testTranscriptionSpeedBalancedModel() async throws {
        try await measureTranscriptionSpeed(for: .balanced, expectedRealTimeFactor: 3.0)
    }

    func testTranscriptionSpeedAccurateModel() async throws {
        try await measureTranscriptionSpeed(for: .accurate, expectedRealTimeFactor: 2.0)
    }

    private func measureTranscriptionSpeed(for modelType, expectedRealTimeFactor: Double) async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping performance test in CI")
        }

        // Check if model is available
        guard modelManager.isModelDownloaded(modelType: modelType) else {
            throw XCTSkip("Model \(modelType.displayName) not downloaded")
        }

        // Load model
        try await transcriber.loadModel(modelType)

        // Test different audio durations
        let durations = [1.0, 5.0, 10.0, 30.0]

        for duration in durations {
            let audioData = createTestAudio(duration: duration)

            // Warm up
            _ = try? await transcriber.transcribe(audioData, language: .english)

            // Measure
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try await transcriber.transcribe(audioData, language: .english)
            let processingTime = CFAbsoluteTimeGetCurrent() - startTime

            let realTimeFactor = duration / processingTime

            print("Model: \(modelType.displayName)")
            print("  Audio duration: \(duration)s")
            print("  Processing time: \(String(format: "%.3f", processingTime))s")
            print("  Real-time factor: \(String(format: "%.2fx", realTimeFactor))")

            // Verify meets performance target
            XCTAssertGreaterThan(
                realTimeFactor,
                expectedRealTimeFactor * 0.8, // Allow 20% margin
                "Model \(modelType.displayName) should process at least \(expectedRealTimeFactor)x real-time"
            )
        }
    }

    // MARK: - Model Loading Performance Tests

    func testModelLoadingTime() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping performance test in CI")
        }

        for modelType in String.allCases {
            guard modelManager.isModelDownloaded(modelType: modelType) else {
                print("Skipping \(modelType.displayName) - not downloaded")
                continue
            }

            // Measure cold load
            let coldStartTime = CFAbsoluteTimeGetCurrent()
            try await transcriber.loadModel(modelType)
            let coldLoadTime = CFAbsoluteTimeGetCurrent() - coldStartTime

            // Measure warm load (switching models)
            let otherModel = String.allCases.first { $0 != modelType } ?? .fast
            try await transcriber.loadModel(otherModel)

            let warmStartTime = CFAbsoluteTimeGetCurrent()
            try await transcriber.loadModel(modelType)
            let warmLoadTime = CFAbsoluteTimeGetCurrent() - warmStartTime

            print("Model: \(modelType.displayName)")
            print("  Cold load time: \(String(format: "%.3f", coldLoadTime))s")
            print("  Warm load time: \(String(format: "%.3f", warmLoadTime))s")

            // Verify loading completes in reasonable time
            XCTAssertLessThan(coldLoadTime, 5.0, "Cold load should complete within 5 seconds")
            XCTAssertLessThan(warmLoadTime, 3.0, "Warm load should complete within 3 seconds")
        }
    }

    // MARK: - Memory Usage Tests

    func testMemoryUsagePerModel() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping performance test in CI")
        }

        let baseline = getMemoryUsage()
        print("Baseline memory: \(formatBytes(baseline))")

        for modelType in String.allCases {
            guard modelManager.isModelDownloaded(modelType: modelType) else {
                continue
            }

            // Load model
            try await transcriber.loadModel(modelType)

            // Let memory settle
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            let loadedMemory = getMemoryUsage()
            let increase = loadedMemory - baseline

            print("Model: \(modelType.displayName)")
            print("  Memory usage: \(formatBytes(loadedMemory))")
            print("  Increase from baseline: \(formatBytes(increase))")

            // Verify memory usage is within expected bounds
            let expectedMaxMemory: Int64
            switch modelType {
            case .fast:
                expectedMaxMemory = 150 * 1024 * 1024 // 150MB
            case .balanced:
                expectedMaxMemory = 250 * 1024 * 1024 // 250MB
            case .accurate:
                expectedMaxMemory = 500 * 1024 * 1024 // 500MB
            }

            XCTAssertLessThan(
                increase,
                expectedMaxMemory,
                "Model \(modelType.displayName) should use less than \(formatBytes(expectedMaxMemory))"
            )
        }
    }

    func testMemoryUsageDuringTranscription() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping performance test in CI")
        }

        // Load smallest model
        guard modelManager.isModelDownloaded(modelType: .fast) else {
            throw XCTSkip("Fast model not available")
        }

        try await transcriber.loadModel(.fast)

        let beforeTranscription = getMemoryUsage()

        // Transcribe various audio lengths
        let durations = [1.0, 5.0, 10.0, 30.0]
        var peakMemory = beforeTranscription

        for duration in durations {
            let audioData = createTestAudio(duration: duration)

            // Start transcription
            let task = Task {
                try await transcriber.transcribe(audioData, language: .english)
            }

            // Monitor memory during transcription
            while !task.isCancelled {
                let currentMemory = getMemoryUsage()
                peakMemory = max(peakMemory, currentMemory)

                if task.isCancelled {
                    break
                }

                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }

            _ = try await task.value
        }

        let peakIncrease = peakMemory - beforeTranscription
        print("Peak memory increase during transcription: \(formatBytes(peakIncrease))")

        // Should not exceed 100MB increase during transcription
        XCTAssertLessThan(peakIncrease, 100 * 1024 * 1024)
    }

    // MARK: - Throughput Tests

    func testBatchTranscriptionThroughput() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping performance test in CI")
        }

        guard modelManager.isModelDownloaded(modelType: .fast) else {
            throw XCTSkip("Fast model not available")
        }

        try await transcriber.loadModel(.fast)

        // Create batch of audio samples
        let batchSize = 10
        let audioDuration = 2.0
        let audioSamples = (0..<batchSize).map { _ in
            createTestAudio(duration: audioDuration)
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Process sequentially
        for audio in audioSamples {
            _ = try await transcriber.transcribe(audio, language: .english)
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let totalAudioDuration = Double(batchSize) * audioDuration
        let throughput = totalAudioDuration / totalTime

        print("Batch transcription:")
        print("  Batch size: \(batchSize)")
        print("  Total audio: \(totalAudioDuration)s")
        print("  Processing time: \(String(format: "%.3f", totalTime))s")
        print("  Throughput: \(String(format: "%.2fx", throughput)) real-time")

        // Should maintain good throughput even with multiple files
        XCTAssertGreaterThan(throughput, 3.0, "Batch processing should maintain >3x real-time")
    }

    // MARK: - Latency Tests

    func testFirstTranscriptionLatency() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping performance test in CI")
        }

        // Create fresh transcriber
        let freshTranscriber = WhisperKitTranscriber()

        guard modelManager.isModelDownloaded(modelType: .fast) else {
            throw XCTSkip("Fast model not available")
        }

        // Measure cold start (model load + first transcription)
        let audioData = createTestAudio(duration: 1.0)

        let startTime = CFAbsoluteTimeGetCurrent()
        try await freshTranscriber.loadModel(.fast)
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime

        let transcribeStart = CFAbsoluteTimeGetCurrent()
        _ = try await freshTranscriber.transcribe(audioData, language: .english)
        let transcribeTime = CFAbsoluteTimeGetCurrent() - transcribeStart

        let totalColdStart = loadTime + transcribeTime

        print("Cold start latency:")
        print("  Model load: \(String(format: "%.3f", loadTime))s")
        print("  First transcription: \(String(format: "%.3f", transcribeTime))s")
        print("  Total: \(String(format: "%.3f", totalColdStart))s")

        // Cold start should be under 5 seconds total
        XCTAssertLessThan(totalColdStart, 5.0)
    }

    // MARK: - Helper Methods

    private func createTestAudio(duration: TimeInterval) -> AudioData {
        let sampleRate = 16000.0
        let sampleCount = Int(sampleRate * duration)

        // Create more realistic audio with speech-like patterns
        var samples = [Int16]()

        for i in 0..<sampleCount {
            // Simulate speech with varying amplitude
            let envelope = sin(Double(i) / sampleRate * 2.0) // Slow envelope
            let carrier = sin(Double(i) / sampleRate * 300.0 * Double.pi) // Voice frequency
            let noise = Double.random(in: -0.1...0.1) // Add some noise

            let amplitude = 5000.0 * abs(envelope)
            let sample = Int16(amplitude * (carrier + noise))
            samples.append(sample)
        }

        return AudioData(
            samples: samples,
            sampleRate: sampleRate,
            channelCount: 1
        )
    }

    private func getMemoryUsage() -> Int64 {
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

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - XCTest Performance Metrics

extension WhisperKitPerformanceTests {
    func testTranscriptionPerformanceMetric() async throws {
        // Skip in CI
        guard ProcessInfo.processInfo.environment["CI"] == nil else {
            throw XCTSkip("Skipping performance test in CI")
        }

        guard modelManager.isModelDownloaded(modelType: .fast) else {
            throw XCTSkip("Fast model not available")
        }

        try await transcriber.loadModel(.fast)
        let audioData = createTestAudio(duration: 5.0)

        // Use XCTest's performance measurement
        measure {
            let expectation = expectation(description: "Transcription complete")

            Task {
                _ = try? await transcriber.transcribe(audioData, language: .english)
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 10.0)
        }
    }
}
