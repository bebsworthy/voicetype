import XCTest
import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Tests for TranscriberFactory thread safety and configuration
class TranscriberFactoryThreadSafetyTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        // Reset to default configuration
        TranscriberFactory.configure(TranscriberFactory.Configuration())
    }

    override func tearDown() async throws {
        // Reset to default configuration
        TranscriberFactory.configure(TranscriberFactory.Configuration())
        try await super.tearDown()
    }

    // MARK: - Thread Safety Tests

    func testConcurrentConfigurationAccess() async {
        let iterations = 100
        let concurrentTasks = 10

        // Create multiple tasks that read and write configuration concurrently
        let tasks = (0..<concurrentTasks).map { taskIndex in
            Task {
                for i in 0..<iterations {
                    // Alternate between different configurations
                    var config = TranscriberFactory.Configuration()

                    if taskIndex % 2 == 0 {
                        config.useMockForTesting = (i % 2 == 0)
                        config.useWhisperKit = true
                    } else {
                        config.useMockForTesting = false
                        config.useWhisperKit = (i % 2 == 0)
                    }

                    TranscriberFactory.configure(config)

                    // Create transcriber to read configuration
                    let transcriber = TranscriberFactory.createDefault()

                    // Verify we got a valid transcriber
                    XCTAssertNotNil(transcriber)

                    // Small delay to increase chance of race conditions
                    try? await Task.sleep(nanoseconds: 1_000) // 1 microsecond
                }
            }
        }

        // Wait for all tasks to complete
        for task in tasks {
            await task.value
        }

        // If we get here without crashes, thread safety is working
        XCTAssertTrue(true, "Concurrent configuration access completed without crashes")
    }

    func testRapidConfigurationChanges() {
        let iterations = 1000

        for i in 0..<iterations {
            var config = TranscriberFactory.Configuration()
            config.useMockForTesting = (i % 3 == 0)
            config.useWhisperKit = (i % 3 != 1)

            TranscriberFactory.configure(config)

            let transcriber = TranscriberFactory.createDefault()

            // Verify configuration is applied correctly
            if config.useMockForTesting {
                XCTAssertTrue(transcriber is MockTranscriber)
            } else if config.useWhisperKit {
                XCTAssertTrue(transcriber is WhisperKitTranscriber)
            } else {
                XCTAssertTrue(transcriber is CoreMLWhisper)
            }
        }
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        // Default should use WhisperKit
        let transcriber = TranscriberFactory.createDefault()
        XCTAssertTrue(transcriber is WhisperKitTranscriber)
    }

    func testMockConfiguration() {
        var config = TranscriberFactory.Configuration()
        config.useMockForTesting = true
        TranscriberFactory.configure(config)

        let transcriber = TranscriberFactory.createDefault()
        XCTAssertTrue(transcriber is MockTranscriber)
    }

    func testCoreMLFallback() {
        var config = TranscriberFactory.Configuration()
        config.useMockForTesting = false
        config.useWhisperKit = false
        TranscriberFactory.configure(config)

        let transcriber = TranscriberFactory.createDefault()
        XCTAssertTrue(transcriber is CoreMLWhisper)
    }

    // MARK: - Factory Method Tests

    func testCreateWhisperKit() {
        let transcriber = TranscriberFactory.createWhisperKit()
        XCTAssertNotNil(transcriber)
        XCTAssertTrue(transcriber is WhisperKitTranscriber)
    }

    func testCreateCoreMLWhisper() {
        let transcriber = TranscriberFactory.createCoreMLWhisper(model: .tiny)
        XCTAssertNotNil(transcriber)
        XCTAssertTrue(transcriber is CoreMLWhisper)
    }

    func testCreateCoreMLWhisperWithCustomPath() {
        let customPath = "/tmp/models"
        let transcriber = TranscriberFactory.createCoreMLWhisper(
            model: .base,
            modelDirectory: customPath
        )
        XCTAssertNotNil(transcriber)
        XCTAssertTrue(transcriber is CoreMLWhisper)
    }

    func testCreateMock() {
        let transcriber = TranscriberFactory.createMock()
        XCTAssertNotNil(transcriber)
        XCTAssertTrue(transcriber is MockTranscriber)
    }

    func testCreateMockWithScenario() {
        let scenarios: [MockTranscriber.MockBehavior] = [
            MockTranscriber.Scenarios.success,
            MockTranscriber.Scenarios.empty,
            MockTranscriber.Scenarios.networkError,
            MockTranscriber.Scenarios.timeout
        ]

        for scenario in scenarios {
            let transcriber = TranscriberFactory.createMock(scenario: scenario)
            XCTAssertNotNil(transcriber)
            XCTAssertTrue(transcriber is MockTranscriber)
        }
    }

    func testCreateWithType() {
        // Test WhisperKit type
        let whisperKit = TranscriberFactory.create(type: .whisperKit)
        XCTAssertTrue(whisperKit is WhisperKitTranscriber)

        // Test CoreML type
        let coreML = TranscriberFactory.create(type: .coreMLWhisper(model: .tiny, modelPath: "/tmp"))
        XCTAssertTrue(coreML is CoreMLWhisper)

        // Test Mock type
        let mock = TranscriberFactory.create(type: .mock(behavior: MockTranscriber.Scenarios.success))
        XCTAssertTrue(mock is MockTranscriber)
    }

    // MARK: - Stress Tests

    func testFactoryUnderLoad() async {
        let queues = (0..<5).map { i in
            DispatchQueue(label: "test.queue.\(i)", attributes: .concurrent)
        }

        let group = DispatchGroup()
        let iterations = 100

        for queue in queues {
            for i in 0..<iterations {
                group.enter()
                queue.async {
                    // Randomly configure
                    if i % 10 == 0 {
                        var config = TranscriberFactory.Configuration()
                        config.useMockForTesting = Bool.random()
                        config.useWhisperKit = Bool.random()
                        TranscriberFactory.configure(config)
                    }

                    // Create various transcribers
                    let transcribers = [
                        TranscriberFactory.createDefault(),
                        TranscriberFactory.createWhisperKit(),
                        TranscriberFactory.createMock(),
                        TranscriberFactory.createCoreMLWhisper(model: .tiny)
                    ]

                    // Verify all are non-nil
                    for transcriber in transcribers {
                        XCTAssertNotNil(transcriber)
                    }

                    group.leave()
                }
            }
        }

        // Wait for all operations to complete
        let result = group.wait(timeout: .now() + 10)
        XCTAssertEqual(result, .success, "All factory operations should complete within timeout")
    }

    // MARK: - Configuration Persistence Tests

    func testConfigurationPersistence() {
        // Set a specific configuration
        var config = TranscriberFactory.Configuration()
        config.useMockForTesting = true
        config.useWhisperKit = false
        TranscriberFactory.configure(config)

        // Create multiple transcribers
        for _ in 0..<10 {
            let transcriber = TranscriberFactory.createDefault()
            XCTAssertTrue(transcriber is MockTranscriber, "Configuration should persist")
        }

        // Change configuration
        config.useMockForTesting = false
        config.useWhisperKit = true
        TranscriberFactory.configure(config)

        // Verify new configuration is applied
        for _ in 0..<10 {
            let transcriber = TranscriberFactory.createDefault()
            XCTAssertTrue(transcriber is WhisperKitTranscriber, "New configuration should be applied")
        }
    }

    // MARK: - Debug Mode Tests

    #if DEBUG
    func testDebugModeConfiguration() {
        // In debug mode, we can disable WhisperKit
        var config = TranscriberFactory.Configuration()
        config.useMockForTesting = false
        config.useWhisperKit = false
        TranscriberFactory.configure(config)

        let transcriber = TranscriberFactory.createDefault()
        XCTAssertTrue(transcriber is CoreMLWhisper, "Debug mode should allow CoreML fallback")
    }
    #endif
}
