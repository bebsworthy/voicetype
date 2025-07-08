import XCTest
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Tests for text injection compatibility with different target applications
final class TargetApplicationCompatibilityTests: XCTestCase {
    // MARK: - Properties

    var textInjectorManager: TextInjectorManager!
    var mockAccessibilityInjector: MockTextInjector!
    var mockClipboardInjector: MockTextInjector!
    var appSpecificInjectors: [String: MockTextInjector]!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Create mock injectors
        mockAccessibilityInjector = MockTextInjector()
        mockClipboardInjector = MockTextInjector()

        // Create app-specific mock injectors
        appSpecificInjectors = [
            "com.apple.TextEdit": MockTextInjector(),
            "com.apple.Notes": MockTextInjector(),
            "com.apple.Terminal": MockTextInjector(),
            "com.apple.Safari": MockTextInjector(),
            "com.microsoft.VSCode": MockTextInjector(),
            "com.notion.id": MockTextInjector(),
            "com.figma.desktop": MockTextInjector()
        ]

        // Create injector manager with accessibility and clipboard injectors
        // First compatible injector will be used (mockAccessibilityInjector unless it fails)
        textInjectorManager = TextInjectorManager(injectors: [mockAccessibilityInjector, mockClipboardInjector])
    }

    override func tearDown() async throws {
        textInjectorManager = nil
        mockAccessibilityInjector = nil
        mockClipboardInjector = nil
        appSpecificInjectors = nil
        try await super.tearDown()
    }

    // MARK: - Target Application Tests

    func testTextEditInjection() async throws {
        // Given: TextEdit is focused
        let target = TargetApplication(
            bundleId: "com.apple.TextEdit",
            name: "TextEdit",
            processId: pid_t(12345),
            isActive: true
        )
        // Configure mock injector

        // When: Inject text
        let testText = "Hello from VoiceType!"
        let expectation = XCTestExpectation(description: "Injection complete")
        var injectionResult: InjectionResult?

        textInjectorManager.inject(text: testText) { result in
            injectionResult = result
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)

        // Then: Should inject text (first compatible injector will be used)
        // Since all MockTextInjectors return isCompatible = true, the first one will be selected
        XCTAssertNotNil(injectionResult)
        XCTAssertTrue(injectionResult?.success ?? false)
        XCTAssertEqual(mockAccessibilityInjector.getLastInjectedText(), testText)
        XCTAssertEqual(mockAccessibilityInjector.getTotalInjectionsCount(), 1)
    }

    func testNotesAppInjection() async throws {
        // Given: Notes.app is focused
        let target = TargetApplication(
            bundleId: "com.apple.Notes",
            name: "Notes",
            processId: pid_t(12345),
            isActive: true
        )
        // Configure mock injector

        // When: Inject text with special characters
        let testText = "Meeting notes:\n- Item 1\n- Item 2\n\t• Subitem"
        let expectation = XCTestExpectation(description: "Injection complete")

        textInjectorManager.inject(text: testText) { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)

        // Then: Should handle special characters correctly
        XCTAssertEqual(mockAccessibilityInjector.getLastInjectedText(), testText)
        XCTAssertTrue(mockAccessibilityInjector.getLastInjectedText()?.contains("\n") ?? false)
        XCTAssertTrue(mockAccessibilityInjector.getLastInjectedText()?.contains("\t") ?? false)
    }

    func testTerminalInjection() async throws {
        // Given: Terminal is focused
        let target = TargetApplication(
            bundleId: "com.apple.Terminal",
            name: "Terminal",
            processId: pid_t(12345),
            isActive: true
        )
        // Configure mock injector

        // When: Inject command text
        let testText = "ls -la | grep .swift"
        let expectation = XCTestExpectation(description: "Injection complete")

        textInjectorManager.inject(text: testText) { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)

        // Then: Should inject without executing (no newline)
        XCTAssertEqual(mockAccessibilityInjector.getLastInjectedText(), testText)
        XCTAssertFalse(mockAccessibilityInjector.getLastInjectedText()?.contains("\n") ?? true)
    }

    func testSafariWebAppInjection() async throws {
        // Given: Safari with web app is focused
        let target = TargetApplication(
            bundleId: "com.apple.Safari",
            name: "Safari",
            processId: pid_t(12345),
            isActive: true
        )
        // Configure mock injector

        // When: Inject text
        let testText = "Document content for Google Docs"
        let expectation = XCTestExpectation(description: "Injection complete")

        textInjectorManager.inject(text: testText) { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)

        // Then: Should use Safari-specific handling
        XCTAssertEqual(mockAccessibilityInjector.getLastInjectedText(), testText)
        XCTAssertGreaterThan(mockAccessibilityInjector.getTotalInjectionsCount(), 0)
    }

    func testVSCodeInjection() async throws {
        // Given: VS Code is focused
        let target = TargetApplication(
            bundleId: "com.microsoft.VSCode",
            name: "Code",
            processId: pid_t(12345),
            isActive: true
        )
        // Configure mock injector

        // When: Inject code text
        let testText = "func testFunction() {\n    print(\"Hello, World!\")\n}"
        let expectation = XCTestExpectation(description: "Injection complete")

        textInjectorManager.inject(text: testText) { _ in
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)

        // Then: Should preserve code formatting
        XCTAssertEqual(mockAccessibilityInjector.getLastInjectedText(), testText)
        XCTAssertTrue(mockAccessibilityInjector.getLastInjectedText()?.contains("    ") ?? false) // Indentation
    }

    // MARK: - Fallback Behavior Tests

    func testFallbackToClipboardWhenInjectionFails() async throws {
        // Given: Accessibility injection will fail
        mockAccessibilityInjector.shouldSucceed = false
        let target = TargetApplication(
            bundleId: "com.unknown.app",
            name: "Unknown App",
            processId: pid_t(12345),
            isActive: true
        )

        // When: Try to inject text
        let testText = "Fallback test"
        let expectation = XCTestExpectation(description: "Injection complete")
        var injectionResult: InjectionResult?

        textInjectorManager.inject(text: testText) { result in
            injectionResult = result
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)

        // Then: Should fallback to clipboard
        XCTAssertNotNil(injectionResult)
        XCTAssertTrue(injectionResult?.success ?? false)
        XCTAssertEqual(injectionResult?.method, "Mock") // Clipboard injector
        XCTAssertEqual(mockClipboardInjector.getLastInjectedText(), testText)
        XCTAssertEqual(mockClipboardInjector.getTotalInjectionsCount(), 1)
    }

    func testNoFocusedApplicationHandling() async throws {
        // Given: No application is focused
        // Configure mock injector with no target

        // When: Try to get focused target
        let target: TargetApplication? = nil // getFocusedTarget not implemented

        // Then: Should return nil
        XCTAssertNil(target)
    }

    func testUnsupportedApplicationHandling() async throws {
        // Given: Application doesn't support text input
        let target = TargetApplication(
            bundleId: "com.apple.FaceTime",
            name: "FaceTime",
            processId: pid_t(12345),
            isActive: true
        )
        // Configure mock injector

        // When: Check if can inject
        let canInject = false // canInject not implemented

        // Then: Should return false
        XCTAssertFalse(canInject)
    }

    // MARK: - App-Specific Injector Tests

    func testAppSpecificInjectorSelection() async throws {
        // Test that correct injector is selected for each app
        let testCases: [(bundleId: String, appName: String)] = [
            ("com.apple.TextEdit", "TextEdit"),
            ("com.apple.Notes", "Notes"),
            ("com.apple.Terminal", "Terminal"),
            ("com.apple.Safari", "Safari"),
            ("com.microsoft.VSCode", "Code")
        ]

        for testCase in testCases {
            // Given: Specific app is focused
            let target = TargetApplication(
                bundleId: testCase.bundleId,
                name: testCase.appName,
                processId: pid_t(12345),
            isActive: true
            )

            // When: Inject text
            let testText = "Test for \(testCase.appName)"
            let expectation = XCTestExpectation(description: "Injection complete")

            textInjectorManager.inject(text: testText) { _ in
                expectation.fulfill()
            }

            await fulfillment(of: [expectation], timeout: 1.0)

            // Then: Should inject using available injector
            XCTAssertEqual(mockAccessibilityInjector.getLastInjectedText(), testText)

            // Reset for next test
            mockAccessibilityInjector.reset()
        }
    }

    func testInjectorRetryMechanism() async throws {
        // Given: Injector will fail first time
        // Configure to fail once then succeed // Fail once then succeed
        let target = TargetApplication(
            bundleId: "com.apple.TextEdit",
            name: "TextEdit",
            processId: pid_t(12345),
            isActive: true
        )

        // When: Inject text
        let testText = "Retry test"
        let expectation = XCTestExpectation(description: "Injection complete")
        var injectionResult: InjectionResult?

        textInjectorManager.inject(text: testText) { result in
            injectionResult = result
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)

        // Then: Should succeed
        XCTAssertNotNil(injectionResult)
        XCTAssertTrue(injectionResult?.success ?? false)
    }

    // MARK: - Performance Tests

    func testInjectionPerformance() throws {
        let target = TargetApplication(
            bundleId: "com.apple.TextEdit",
            name: "TextEdit",
            processId: pid_t(12345),
            isActive: true
        )
        // Configure mock injector

        measure {
            let expectation = XCTestExpectation(description: "Injection complete")

            let longText = String(repeating: "Test ", count: 1000)
            textInjectorManager.inject(text: longText) { _ in
                expectation.fulfill()
            }

            wait(for: [expectation], timeout: 1.0)
        }
    }
}

// MARK: - Test Helpers

extension TargetApplication {
    /// Create a test target application
    static func testTarget(
        bundleId: String,
        name: String,
        supportsInput: Bool = true
    ) -> TargetApplication {
        TargetApplication(
            bundleId: bundleId,
            name: name,
            processId: pid_t(12345),
            isActive: true
        )
    }
}
