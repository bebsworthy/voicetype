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
        
        // Create injector manager
        textInjectorManager = TextInjectorManager(
            primaryInjector: mockAccessibilityInjector,
            fallbackInjector: mockClipboardInjector,
            appSpecificInjectors: appSpecificInjectors
        )
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
            bundleIdentifier: "com.apple.TextEdit",
            name: "TextEdit",
            isActive: true,
            supportsTextInput: true
        )
        mockAccessibilityInjector.mockTarget = target
        
        // When: Inject text
        let testText = "Hello from VoiceType!"
        try await textInjectorManager.inject(testText, into: target)
        
        // Then: Should use app-specific injector
        if let specificInjector = appSpecificInjectors["com.apple.TextEdit"] {
            XCTAssertEqual(specificInjector.lastInjectedText, testText)
            XCTAssertEqual(specificInjector.injectCallCount, 1)
        } else {
            XCTFail("App-specific injector not found")
        }
    }
    
    func testNotesAppInjection() async throws {
        // Given: Notes.app is focused
        let target = TargetApplication(
            bundleIdentifier: "com.apple.Notes",
            name: "Notes",
            isActive: true,
            supportsTextInput: true
        )
        mockAccessibilityInjector.mockTarget = target
        
        // When: Inject text with special characters
        let testText = "Meeting notes:\n- Item 1\n- Item 2\n\t• Subitem"
        try await textInjectorManager.inject(testText, into: target)
        
        // Then: Should handle special characters correctly
        if let specificInjector = appSpecificInjectors["com.apple.Notes"] {
            XCTAssertEqual(specificInjector.lastInjectedText, testText)
            XCTAssertTrue(specificInjector.lastInjectedText?.contains("\n") ?? false)
            XCTAssertTrue(specificInjector.lastInjectedText?.contains("\t") ?? false)
        }
    }
    
    func testTerminalInjection() async throws {
        // Given: Terminal is focused
        let target = TargetApplication(
            bundleIdentifier: "com.apple.Terminal",
            name: "Terminal",
            isActive: true,
            supportsTextInput: true
        )
        mockAccessibilityInjector.mockTarget = target
        
        // When: Inject command text
        let testText = "ls -la | grep .swift"
        try await textInjectorManager.inject(testText, into: target)
        
        // Then: Should inject without executing (no newline)
        if let specificInjector = appSpecificInjectors["com.apple.Terminal"] {
            XCTAssertEqual(specificInjector.lastInjectedText, testText)
            XCTAssertFalse(specificInjector.lastInjectedText?.contains("\n") ?? true)
        }
    }
    
    func testSafariWebAppInjection() async throws {
        // Given: Safari with web app is focused
        let target = TargetApplication(
            bundleIdentifier: "com.apple.Safari",
            name: "Safari",
            isActive: true,
            supportsTextInput: true,
            focusedElement: TargetApplication.FocusedElement(
                role: "AXWebArea",
                title: "Google Docs",
                value: nil
            )
        )
        mockAccessibilityInjector.mockTarget = target
        
        // When: Inject text
        let testText = "Document content for Google Docs"
        try await textInjectorManager.inject(testText, into: target)
        
        // Then: Should use Safari-specific handling
        if let specificInjector = appSpecificInjectors["com.apple.Safari"] {
            XCTAssertEqual(specificInjector.lastInjectedText, testText)
            XCTAssertEqual(specificInjector.injectCallCount, 1)
        }
    }
    
    func testVSCodeInjection() async throws {
        // Given: VS Code is focused
        let target = TargetApplication(
            bundleIdentifier: "com.microsoft.VSCode",
            name: "Code",
            isActive: true,
            supportsTextInput: true
        )
        mockAccessibilityInjector.mockTarget = target
        
        // When: Inject code text
        let testText = "func testFunction() {\n    print(\"Hello, World!\")\n}"
        try await textInjectorManager.inject(testText, into: target)
        
        // Then: Should preserve code formatting
        if let specificInjector = appSpecificInjectors["com.microsoft.VSCode"] {
            XCTAssertEqual(specificInjector.lastInjectedText, testText)
            XCTAssertTrue(specificInjector.lastInjectedText?.contains("    ") ?? false) // Indentation
        }
    }
    
    // MARK: - Fallback Behavior Tests
    
    func testFallbackToClipboardWhenInjectionFails() async throws {
        // Given: Accessibility injection will fail
        mockAccessibilityInjector.shouldFailInjection = true
        let target = TargetApplication(
            bundleIdentifier: "com.unknown.app",
            name: "Unknown App",
            isActive: true,
            supportsTextInput: true
        )
        
        // When: Try to inject text
        let testText = "Fallback test"
        try await textInjectorManager.inject(testText, into: target)
        
        // Then: Should use clipboard fallback
        XCTAssertEqual(mockClipboardInjector.lastInjectedText, testText)
        XCTAssertEqual(mockClipboardInjector.injectCallCount, 1)
    }
    
    func testNoFocusedApplicationHandling() async throws {
        // Given: No application is focused
        mockAccessibilityInjector.mockTarget = nil
        
        // When: Try to get focused target
        let target = await textInjectorManager.getFocusedTarget()
        
        // Then: Should return nil
        XCTAssertNil(target)
    }
    
    func testUnsupportedApplicationHandling() async throws {
        // Given: Application doesn't support text input
        let target = TargetApplication(
            bundleIdentifier: "com.apple.FaceTime",
            name: "FaceTime",
            isActive: true,
            supportsTextInput: false
        )
        mockAccessibilityInjector.mockTarget = target
        
        // When: Check if can inject
        let canInject = textInjectorManager.canInject(into: target)
        
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
                bundleIdentifier: testCase.bundleId,
                name: testCase.appName,
                isActive: true,
                supportsTextInput: true
            )
            
            // When: Inject text
            let testText = "Test for \(testCase.appName)"
            try await textInjectorManager.inject(testText, into: target)
            
            // Then: Should use correct app-specific injector
            if let specificInjector = appSpecificInjectors[testCase.bundleId] {
                XCTAssertEqual(specificInjector.lastInjectedText, testText)
                
                // Reset for next test
                specificInjector.reset()
            } else {
                XCTFail("No injector for \(testCase.bundleId)")
            }
        }
    }
    
    func testInjectorRetryMechanism() async throws {
        // Given: Injector will fail first time
        mockAccessibilityInjector.failureCount = 1 // Fail once then succeed
        let target = TargetApplication(
            bundleIdentifier: "com.apple.TextEdit",
            name: "TextEdit",
            isActive: true,
            supportsTextInput: true
        )
        
        // When: Inject text
        let testText = "Retry test"
        do {
            try await textInjectorManager.inject(testText, into: target)
            // If retry mechanism works, this should succeed
        } catch {
            // If no retry, this will throw
            XCTFail("Injection failed without retry: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testInjectionPerformance() throws {
        let target = TargetApplication(
            bundleIdentifier: "com.apple.TextEdit",
            name: "TextEdit",
            isActive: true,
            supportsTextInput: true
        )
        mockAccessibilityInjector.mockTarget = target
        
        measure {
            let expectation = XCTestExpectation(description: "Injection complete")
            
            Task {
                let longText = String(repeating: "Test ", count: 1000)
                try await textInjectorManager.inject(longText, into: target)
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
        return TargetApplication(
            bundleIdentifier: bundleId,
            name: name,
            isActive: true,
            supportsTextInput: supportsInput
        )
    }
}