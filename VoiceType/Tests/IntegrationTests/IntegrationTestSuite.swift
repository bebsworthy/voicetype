import XCTest
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations
@testable import VoiceType

/// Main integration test suite that runs all integration tests
final class IntegrationTestSuite: XCTestCase {
    
    // MARK: - Properties
    
    private var performanceCollector: TestUtilities.PerformanceCollector!
    private var testStartTime: Date!
    
    // MARK: - Test Lifecycle
    
    override class func setUp() {
        super.setUp()
        print("🚀 Starting VoiceType Integration Test Suite")
        print("================================================")
    }
    
    override class func tearDown() {
        super.tearDown()
        print("================================================")
        print("✅ VoiceType Integration Test Suite Complete")
    }
    
    override func setUp() {
        super.setUp()
        performanceCollector = TestUtilities.PerformanceCollector()
        testStartTime = Date()
    }
    
    override func tearDown() {
        let elapsed = Date().timeIntervalSince(testStartTime)
        print("⏱️  Test completed in \(String(format: "%.3f", elapsed))s")
        super.tearDown()
    }
    
    // MARK: - Comprehensive Test Scenarios
    
    /// Test complete user journey from app launch to successful dictation
    func testCompleteUserJourney() async throws {
        print("📋 Testing complete user journey...")
        
        // 1. App Launch
        let coordinator = await createFullyConfiguredCoordinator()
        
        // 2. First-time setup
        await coordinator.requestPermissions()
        try await TestUtilities.waitFor(
            condition: { await coordinator.hasMicrophonePermission },
            timeout: 2.0
        )
        
        // 3. Model loading
        let (_, loadTime) = try await TestUtilities.measureTime {
            await coordinator.changeModel(.fast)
        }
        performanceCollector.record(metric: "model_loading", time: loadTime)
        
        // 4. Hotkey registration
        let hotkeyManager = HotkeyManager()
        try hotkeyManager.registerHotkey(
            identifier: "test",
            keyCombo: "ctrl+shift+v"
        ) {
            Task { await coordinator.startDictation() }
        }
        
        // 5. Dictation workflow
        let (_, dictationTime) = try await TestUtilities.measureTime {
            await coordinator.startDictation()
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await coordinator.stopDictation()
            try await TestUtilities.waitForState(coordinator, state: .success)
        }
        performanceCollector.record(metric: "full_dictation", time: dictationTime)
        
        // Verify success
        XCTAssertFalse(coordinator.lastTranscription.isEmpty)
        print("✅ User journey completed successfully")
    }
    
    /// Test app behavior under stress conditions
    func testStressConditions() async throws {
        print("💪 Testing under stress conditions...")
        
        let coordinator = await createFullyConfiguredCoordinator()
        
        // Rapid dictation cycles
        for i in 0..<20 {
            let (_, cycleTime) = try await TestUtilities.measureTime {
                await coordinator.startDictation()
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                await coordinator.stopDictation()
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
            performanceCollector.record(metric: "stress_cycle", time: cycleTime)
            
            if i % 5 == 0 {
                print("  Completed \(i + 1) stress cycles...")
            }
        }
        
        // Memory usage check
        let (_, peakMemory) = try await TestUtilities.trackMemoryUsage {
            for _ in 0..<5 {
                await coordinator.startDictation()
                try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                await coordinator.stopDictation()
            }
        }
        
        let peakMemoryMB = Double(peakMemory) / 1_048_576
        print("  Peak memory usage: \(String(format: "%.2f", peakMemoryMB)) MB")
        XCTAssertLessThan(peakMemoryMB, 100.0, "Memory usage exceeded 100MB")
        
        print("✅ Stress test completed")
    }
    
    /// Test recovery from various failure scenarios
    func testFailureRecoveryScenarios() async throws {
        print("🔧 Testing failure recovery scenarios...")
        
        var recoveryTests = [
            "Microphone permission denial",
            "Audio device disconnection",
            "Model loading failure",
            "Network failure during download",
            "Text injection failure"
        ]
        
        for (index, test) in recoveryTests.enumerated() {
            print("  Testing: \(test)")
            
            let coordinator = await createFullyConfiguredCoordinator()
            
            switch index {
            case 0: // Permission denial
                let mockPermission = coordinator.value(forKey: "permissionManager") as? MockPermissionManager
                mockPermission?.mockMicrophonePermission = .denied
                await coordinator.startDictation()
                XCTAssertNotNil(coordinator.errorMessage)
                
            case 1: // Device disconnection
                let mockAudio = coordinator.value(forKey: "audioProcessor") as? MockAudioProcessor
                await coordinator.startDictation()
                mockAudio?.simulateError(.deviceDisconnected)
                try await Task.sleep(nanoseconds: 200_000_000)
                XCTAssertTrue(coordinator.recordingState.isError)
                
            case 2: // Model failure
                let mockTranscriber = coordinator.value(forKey: "transcriber") as? MockTranscriber
                mockTranscriber?.setReady(false)
                await coordinator.startDictation()
                XCTAssertNotNil(coordinator.errorMessage)
                
            case 3: // Network failure
                let mockModel = coordinator.value(forKey: "modelManager") as? MockModelManager
                mockModel?.shouldFailDownload = true
                await coordinator.changeModel(.base)
                XCTAssertEqual(coordinator.selectedModel, .fast) // Fallback
                
            case 4: // Injection failure
                let mockInjector = coordinator.value(forKey: "textInjector") as? MockTextInjector
                mockInjector?.shouldFailInjection = true
                await performFullDictation(with: coordinator)
                XCTAssertTrue(coordinator.errorMessage?.contains("clipboard") ?? false)
                
            default:
                break
            }
            
            print("    ✓ Recovered from \(test)")
        }
        
        print("✅ All recovery scenarios tested")
    }
    
    /// Test compatibility with target applications
    func testTargetApplicationCompatibility() async throws {
        print("📱 Testing target application compatibility...")
        
        let targetApps = [
            ("com.apple.TextEdit", "TextEdit"),
            ("com.apple.Notes", "Notes"),
            ("com.apple.Terminal", "Terminal"),
            ("com.apple.Safari", "Safari"),
            ("com.microsoft.VSCode", "VS Code")
        ]
        
        let injectorManager = TextInjectorManager()
        
        for (bundleId, name) in targetApps {
            let target = TestUtilities.mockTargetApplication(
                bundleId: bundleId,
                name: name
            )
            
            let canInject = injectorManager.canInject(into: target)
            XCTAssertTrue(canInject, "\(name) should support injection")
            
            print("  ✓ \(name) compatibility verified")
        }
        
        print("✅ Application compatibility tests complete")
    }
    
    /// Generate performance report
    func testPerformanceReport() async throws {
        print("📊 Generating performance report...")
        
        // Run performance benchmarks
        let coordinator = await createFullyConfiguredCoordinator()
        
        // Measure various operations
        for _ in 0..<10 {
            // Model loading
            let (_, loadTime) = try await TestUtilities.measureTime {
                await coordinator.changeModel(.fast)
            }
            performanceCollector.record(metric: "model_load", time: loadTime)
            
            // Recording start latency
            let (_, startTime) = try await TestUtilities.measureTime {
                await coordinator.startDictation()
            }
            performanceCollector.record(metric: "recording_start", time: startTime)
            
            // Full workflow
            let (_, workflowTime) = try await TestUtilities.measureTime {
                await performFullDictation(with: coordinator)
            }
            performanceCollector.record(metric: "full_workflow", time: workflowTime)
        }
        
        // Print report
        print(performanceCollector.report())
        
        // Verify performance targets
        if let avgWorkflow = performanceCollector.average(for: "full_workflow") {
            XCTAssertLessThan(avgWorkflow, 5.0, "Average workflow time exceeded 5 seconds")
        }
        
        print("✅ Performance benchmarks complete")
    }
    
    // MARK: - Helper Methods
    
    private func createFullyConfiguredCoordinator() async -> VoiceTypeCoordinator {
        let mockAudio = MockAudioProcessor()
        let mockTranscriber = MockTranscriber()
        let mockInjector = MockTextInjector()
        let mockPermission = MockPermissionManager()
        let mockModel = MockModelManager()
        
        // Configure mocks
        mockPermission.mockMicrophonePermission = .granted
        mockTranscriber.setReady(true)
        mockInjector.mockTarget = TestUtilities.mockTargetApplication()
        
        let coordinator = await VoiceTypeCoordinator(
            audioProcessor: mockAudio,
            transcriber: mockTranscriber,
            textInjector: mockInjector,
            permissionManager: mockPermission,
            modelManager: mockModel
        )
        
        // Wait for initialization
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        return coordinator
    }
    
    private func performFullDictation(with coordinator: VoiceTypeCoordinator) async {
        await coordinator.startDictation()
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        await coordinator.stopDictation()
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
    }
}

// MARK: - Test Runner

/// Run all integration tests with proper setup and teardown
class IntegrationTestRunner {
    static func runAllTests() async {
        print("🏃 Running VoiceType Integration Tests")
        print("=====================================")
        
        let testClasses = [
            EndToEndWorkflowTests.self,
            TargetApplicationCompatibilityTests.self,
            ModelLoadingSwitchingTests.self,
            ErrorScenarioTests.self
        ]
        
        var totalTests = 0
        var passedTests = 0
        var failedTests: [(String, String)] = []
        
        for testClass in testClasses {
            print("\n📁 Running \(String(describing: testClass))")
            
            let suite = XCTestSuite(forTestCaseClass: testClass)
            let result = XCTestResult()
            suite.run(result)
            
            totalTests += result.executionCount
            passedTests += result.executionCount - result.failureCount
            
            if result.failureCount > 0 {
                for failure in result.failures {
                    failedTests.append((
                        String(describing: testClass),
                        failure.compactDescription
                    ))
                }
            }
        }
        
        // Print summary
        print("\n=====================================")
        print("📊 Test Summary")
        print("=====================================")
        print("Total tests: \(totalTests)")
        print("Passed: \(passedTests) ✅")
        print("Failed: \(failedTests.count) ❌")
        
        if !failedTests.isEmpty {
            print("\n❌ Failed Tests:")
            for (testClass, failure) in failedTests {
                print("  - \(testClass): \(failure)")
            }
        }
        
        let successRate = Double(passedTests) / Double(totalTests) * 100
        print("\nSuccess rate: \(String(format: "%.1f", successRate))%")
        
        if successRate == 100 {
            print("\n🎉 All tests passed! VoiceType is ready for CI/CD.")
        } else {
            print("\n⚠️  Some tests failed. Please review and fix before deployment.")
        }
    }
}