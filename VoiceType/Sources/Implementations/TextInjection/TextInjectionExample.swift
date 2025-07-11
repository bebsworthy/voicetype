import Foundation
import AppKit
import VoiceTypeCore

/// Example usage and testing of the text injection system
public class TextInjectionExample {
    /// Demonstrate basic text injection
    public static func basicExample() {
        // Create the default injector manager
        let injectorManager = TextInjectorFactory.createDefaultInjectorManager()

        // Check accessibility permissions
        if !TextInjectorManager.checkAccessibilityPermissions() {
            print("⚠️ Accessibility permissions not granted. Some injection methods may not work.")
        }

        // Inject some text
        let textToInject = "Hello from VoiceType!"

        injectorManager.inject(text: textToInject) { result in
            switch result {
            case .success:
                print("✅ Text injected successfully")
                // Note: The specific method used is logged internally
            case .failure(let error):
                print("❌ Text injection failed: \(error.localizedDescription)")
            }
        }
    }

    /// Demonstrate configuration-based injection
    public static func configurationExample() {
        // Create a custom configuration
        var config = TextInjectionConfiguration()
        config.enableAccessibility = true
        config.enableAppSpecific = true
        config.enableSmartClipboard = true
        config.fallbackToClipboard = true

        // Add a custom strategy for a specific app
        config.customStrategies.append(CustomAppStrategy())

        // Build the injector manager
        let injectorManager = config.buildInjectorManager()

        // Use it to inject text
        injectorManager.inject(text: "Custom configured injection") { result in
            switch result {
            case .success:
                print("Injection result: Success")
            case .failure(let error):
                print("Injection result: Failed - \(error)")
            }
        }
    }

    /// Demonstrate testing with mock injectors
    public static func testingExample() {
        // Create a test injector
        let mockInjector = ConfigurableMockInjector()

        // Configure failure pattern
        mockInjector.failurePattern = .everyNthAttempt(3) // Fail every 3rd attempt
        mockInjector.compatibilityPattern = .always

        // Create manager with mock
        let manager = TextInjectorFactory.createCustomInjectorManager(
            injectors: [mockInjector, MockTextInjector()]
        )

        // Test multiple injections
        for i in 1...5 {
            manager.inject(text: "Test \(i)") { result in
                switch result {
                case .success:
                    print("Attempt \(i): ✅")
                case .failure:
                    print("Attempt \(i): ❌")
                }
            }
        }

        // Check injection history
        print("\nInjection history:")
        for record in mockInjector.injectionHistory {
            print("- \"\(record.text)\" at \(record.timestamp)")
        }
    }

    /// Demonstrate app context detection
    public static func contextDetectionExample() {
        let context = TextInjectorManager.getCurrentApplicationContext()

        print("Current Application Context:")
        print("- App: \(context.name)")
        print("- Bundle ID: \(context.bundleIdentifier ?? "None")")
        print("- Is Running: \(context.isRunning)")

        // Check compatibility with different injectors
        let injectors: [TextInjector] = [
            AccessibilityInjector(),
            ClipboardInjector(),
            AppSpecificInjector()
        ]

        print("\nInjector Compatibility:")
        for injector in injectors {
            let compatible = injector.isCompatibleWithCurrentContext()
            print("- \(injector.methodName): \(compatible ? "✅ Compatible" : "❌ Not compatible")")
        }
    }

    /// Demonstrate error handling
    public static func errorHandlingExample() {
        let injectorManager = TextInjectorFactory.createDefaultInjectorManager()

        // Inject into a potentially problematic context
        injectorManager.inject(text: "Error test") { result in
            switch result {
            case .success:
                print("Injection succeeded")
            case .failure(let error):
                switch error {
                case .incompatibleApplication(let appName):
                    print("App '\(appName)' doesn't support this injection method")
                    // Could show user a helpful message

                case .noFocusedElement:
                    print("No text field is selected. Please click in a text field.")
                    // Could show an overlay hint

                case .accessibilityNotEnabled:
                    print("Please enable accessibility permissions in System Preferences")
                    // Could open System Preferences

                case .clipboardError(let error):
                    print("Clipboard error: \(error)")
                    // Could retry with different method

                case .injectionFailed(let reason):
                    print("Injection failed: \(reason)")
                    // Log for debugging

                case .timeout:
                    print("Injection timed out")
                    // Could increase timeout or retry
                }
            }
        }
    }
}

// Example custom app strategy
class CustomAppStrategy: AppInjectionStrategy {
    let bundleIdentifier = "com.example.customapp"

    func canHandle(element: AXUIElement) -> Bool {
        // Custom logic to determine if we can handle this element
        true
    }

    func inject(text: String, element: AXUIElement) throws {
        // Custom injection logic for this specific app
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString)
        if result != .success {
            throw TextInjectionError.injectionFailed(reason: "Custom app injection failed")
        }
    }
}

/// Performance testing utilities
public class TextInjectionPerformance {
    /// Measure injection latency
    public static func measureLatency(injector: TextInjector, iterations: Int = 100) {
        var totalTime: TimeInterval = 0
        var successCount = 0

        let semaphore = DispatchSemaphore(value: 0)

        for i in 0..<iterations {
            let start = Date()

            injector.inject(text: "Performance test \(i)") { result in
                let elapsed = Date().timeIntervalSince(start)
                totalTime += elapsed
                switch result {
                case .success:
                    successCount += 1
                case .failure:
                    break
                }
                semaphore.signal()
            }

            semaphore.wait()
        }

        let averageTime = totalTime / Double(iterations)
        let successRate = Double(successCount) / Double(iterations) * 100

        print("\nPerformance Results for \(injector.methodName):")
        print("- Average latency: \((averageTime * 1000).formatted(.number.precision(.fractionLength(3))))ms")
        print("- Success rate: \(successRate.formatted(.number.precision(.fractionLength(1))))%")
        print("- Total time: \(totalTime.formatted(.number.precision(.fractionLength(2))))s")
    }

    /// Compare different injector performance
    public static func compareInjectors() {
        let injectors: [TextInjector] = [
            MockTextInjector(), // Fastest, for baseline
            AccessibilityInjector(),
            ClipboardInjector(),
            SmartClipboardInjector()
        ]

        print("Comparing injector performance...")

        for injector in injectors {
            measureLatency(injector: injector, iterations: 50)
        }
    }
}
