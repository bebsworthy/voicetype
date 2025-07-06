# App Compatibility Guide

This guide explains how to add support for new applications in VoiceType, including different text injection strategies and testing procedures.

## Overview

VoiceType injects transcribed text into target applications using several strategies:

1. **Accessibility API** (Primary method)
2. **Clipboard** (Universal fallback)
3. **App-Specific Injectors** (Custom implementations)
4. **Keyboard Simulation** (Last resort)

## Text Injection Strategies

### 1. Accessibility API (Recommended)

The most reliable method for most macOS applications:

```swift
class AccessibilityInjector: TextInjector {
    func inject(_ text: String, into target: TargetApplication) async throws {
        // Get the focused element
        guard let app = NSWorkspace.shared.runningApplications.first(
            where: { $0.bundleIdentifier == target.bundleIdentifier }
        ) else {
            throw VoiceTypeError.noFocusedApplication
        }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        
        // Find focused text field
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard result == .success,
              let textField = focusedElement as! AXUIElement? else {
            throw VoiceTypeError.injectionFailed("No focused text field")
        }
        
        // Insert text at cursor position
        AXUIElementSetAttributeValue(
            textField,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
    }
}
```

**Pros:**
- Works with most native macOS apps
- Preserves formatting and cursor position
- Supports undo/redo

**Cons:**
- Requires accessibility permission
- May not work with some web apps

### 2. Clipboard Injection

Universal fallback that works everywhere:

```swift
class ClipboardInjector: TextInjector {
    func inject(_ text: String, into target: TargetApplication) async throws {
        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let savedContent = pasteboard.string(forType: .string)
        
        // Copy text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down
        let cmdDown = CGEvent(keyboardEventSource: source, 
                             virtualKey: 0x37, // Cmd key
                             keyDown: true)
        let vDown = CGEvent(keyboardEventSource: source,
                           virtualKey: 0x09, // V key
                           keyDown: true)
        vDown?.flags = .maskCommand
        
        // Key up
        let vUp = CGEvent(keyboardEventSource: source,
                         virtualKey: 0x09,
                         keyDown: false)
        vUp?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: source,
                           virtualKey: 0x37,
                           keyDown: false)
        
        // Post events
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
        
        // Restore clipboard after delay
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if let saved = savedContent {
                pasteboard.clearContents()
                pasteboard.setString(saved, forType: .string)
            }
        }
    }
}
```

**Pros:**
- Works with any application
- No special permissions needed
- Simple implementation

**Cons:**
- Modifies clipboard (temporarily)
- User might notice the paste action
- Doesn't work if paste is disabled

### 3. App-Specific Injectors

Custom implementations for specific applications:

```swift
class SlackInjector: TextInjector {
    func canInject(into target: TargetApplication) -> Bool {
        return target.bundleIdentifier == "com.tinyspeck.slackmacgap"
    }
    
    func inject(_ text: String, into target: TargetApplication) async throws {
        // Use Slack's specific accessibility structure
        guard let app = NSWorkspace.shared.runningApplications.first(
            where: { $0.bundleIdentifier == target.bundleIdentifier }
        ) else {
            throw VoiceTypeError.noFocusedApplication
        }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        
        // Slack has a specific message input structure
        if let messageInput = findSlackMessageInput(in: axApp) {
            // Use Slack's custom text insertion method
            insertTextInSlack(text, into: messageInput)
        } else {
            // Fallback to clipboard
            try await ClipboardInjector().inject(text, into: target)
        }
    }
    
    private func findSlackMessageInput(in app: AXUIElement) -> AXUIElement? {
        // Navigate Slack's accessibility tree
        // Look for role: AXTextArea with specific attributes
        // This is app-specific logic
    }
    
    private func insertTextInSlack(_ text: String, into element: AXUIElement) {
        // Slack-specific text insertion
        // May need to handle markdown, emoji conversion, etc.
    }
}
```

### 4. Keyboard Simulation

Direct keyboard event simulation:

```swift
class KeyboardSimulationInjector: TextInjector {
    func inject(_ text: String, into target: TargetApplication) async throws {
        let source = CGEventSource(stateID: .hidSystemState)
        
        for character in text {
            // Convert character to key code
            guard let keyCode = keyCode(for: character) else {
                continue
            }
            
            // Create key events
            let keyDown = CGEvent(keyboardEventSource: source,
                                 virtualKey: keyCode.virtualKey,
                                 keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source,
                               virtualKey: keyCode.virtualKey,
                               keyDown: false)
            
            // Set modifiers if needed
            if keyCode.needsShift {
                keyDown?.flags = .maskShift
                keyUp?.flags = .maskShift
            }
            
            // Post events
            keyDown?.post(tap: .cghidEventTap)
            keyUp?.post(tap: .cghidEventTap)
            
            // Small delay between characters
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
    
    private func keyCode(for character: Character) -> (virtualKey: CGKeyCode, needsShift: Bool)? {
        // Character to key code mapping
        // This is complex due to keyboard layouts
    }
}
```

**Pros:**
- Works when other methods fail
- Can handle special keys

**Cons:**
- Slow for long text
- Affected by keyboard layout
- May trigger unwanted shortcuts

## Adding Support for New Applications

### Step 1: Analyze the Application

First, understand how the target application handles text input:

```swift
class AppAnalyzer {
    static func analyzeApp(bundleId: String) -> AppAnalysis {
        guard let app = NSWorkspace.shared.runningApplications.first(
            where: { $0.bundleIdentifier == bundleId }
        ) else {
            return AppAnalysis(bundleId: bundleId, status: .notRunning)
        }
        
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        
        // Check accessibility support
        var isAccessible: DarwinBoolean = false
        AXIsProcessTrusted()
        AXUIElementIsAttributeSettable(
            axApp,
            kAXFocusedUIElementAttribute as CFString,
            &isAccessible
        )
        
        // Analyze UI structure
        let structure = analyzeUIStructure(axApp)
        
        // Test injection methods
        let workingMethods = testInjectionMethods(axApp)
        
        return AppAnalysis(
            bundleId: bundleId,
            status: .analyzed,
            isAccessible: isAccessible.boolValue,
            uiStructure: structure,
            workingMethods: workingMethods
        )
    }
}
```

### Step 2: Create App Configuration

Define how VoiceType should interact with the app:

```swift
struct AppConfiguration {
    let bundleId: String
    let name: String
    let injectionStrategy: InjectionStrategy
    let customSettings: [String: Any]
    
    // Known app configurations
    static let configurations: [String: AppConfiguration] = [
        "com.apple.TextEdit": AppConfiguration(
            bundleId: "com.apple.TextEdit",
            name: "TextEdit",
            injectionStrategy: .accessibility,
            customSettings: [:]
        ),
        
        "com.microsoft.VSCode": AppConfiguration(
            bundleId: "com.microsoft.VSCode",
            name: "Visual Studio Code",
            injectionStrategy: .custom(VSCodeInjector()),
            customSettings: [
                "preferExtensionAPI": true,
                "fallbackToClipboard": true
            ]
        ),
        
        "com.google.Chrome": AppConfiguration(
            bundleId: "com.google.Chrome",
            name: "Google Chrome",
            injectionStrategy: .hybrid([.accessibility, .clipboard]),
            customSettings: [
                "detectWebApps": true,
                "webAppStrategies": [
                    "docs.google.com": "clipboard",
                    "github.com": "accessibility"
                ]
            ]
        )
    ]
}

enum InjectionStrategy {
    case accessibility
    case clipboard
    case keyboard
    case custom(TextInjector)
    case hybrid([InjectionStrategy])
}
```

### Step 3: Implement Custom Injector (if needed)

For apps that need special handling:

```swift
class CustomAppInjector: TextInjector {
    private let config: AppConfiguration
    
    init(config: AppConfiguration) {
        self.config = config
    }
    
    func canInject(into target: TargetApplication) -> Bool {
        return target.bundleIdentifier == config.bundleId
    }
    
    func inject(_ text: String, into target: TargetApplication) async throws {
        // Try primary strategy
        do {
            try await injectUsingPrimaryStrategy(text, into: target)
        } catch {
            // Fallback to secondary strategy
            if config.customSettings["fallbackToClipboard"] as? Bool == true {
                try await ClipboardInjector().inject(text, into: target)
            } else {
                throw error
            }
        }
    }
    
    private func injectUsingPrimaryStrategy(
        _ text: String,
        into target: TargetApplication
    ) async throws {
        // App-specific implementation
    }
}
```

### Step 4: Register the Configuration

Add the app to VoiceType's registry:

```swift
// In TextInjectorFactory.swift
class TextInjectorFactory {
    private static var customInjectors: [String: TextInjector] = [:]
    
    static func registerAppConfiguration(_ config: AppConfiguration) {
        switch config.injectionStrategy {
        case .custom(let injector):
            customInjectors[config.bundleId] = injector
        default:
            // Use default strategies
            break
        }
    }
    
    static func createInjector(for app: TargetApplication) -> TextInjector {
        // Check for custom injector
        if let custom = customInjectors[app.bundleIdentifier] {
            return custom
        }
        
        // Check known configurations
        if let config = AppConfiguration.configurations[app.bundleIdentifier] {
            return createFromStrategy(config.injectionStrategy)
        }
        
        // Default strategy
        return AccessibilityInjector()
    }
}
```

## Testing App Compatibility

### Automated Testing

Create comprehensive tests for each supported app:

```swift
class AppCompatibilityTests: XCTestCase {
    func testTextEditInjection() async throws {
        // Launch TextEdit
        let app = XCUIApplication(bundleIdentifier: "com.apple.TextEdit")
        app.launch()
        
        // Wait for app to be ready
        wait(for: app.state == .runningForeground)
        
        // Create new document
        app.typeKey("n", modifierFlags: .command)
        
        // Get injector
        let target = TargetApplication(
            bundleIdentifier: "com.apple.TextEdit",
            name: "TextEdit",
            isActive: true,
            processIdentifier: app.processIdentifier
        )
        let injector = TextInjectorFactory.createInjector(for: target)
        
        // Test injection
        let testText = "Hello from VoiceType!"
        try await injector.inject(testText, into: target)
        
        // Verify text was inserted
        let textView = app.textViews.firstMatch
        XCTAssertEqual(textView.value as? String, testText)
        
        // Test special characters
        let specialText = "Special chars: @#$%^&*()"
        try await injector.inject(specialText, into: target)
        
        // Test unicode
        let unicodeText = "Unicode: 你好 🎙️ café"
        try await injector.inject(unicodeText, into: target)
    }
}
```

### Manual Testing Checklist

For each new app, test:

- [ ] **Basic text injection** works
- [ ] **Special characters** are handled correctly
- [ ] **Unicode/emoji** support
- [ ] **Multiple paragraphs** with line breaks
- [ ] **Cursor position** is preserved
- [ ] **Undo/redo** functionality works
- [ ] **Different input fields** (if applicable)
- [ ] **Performance** with long text
- [ ] **App-specific features** (formatting, etc.)

### Compatibility Test Suite

```swift
struct CompatibilityTest {
    let name: String
    let test: (TargetApplication) async throws -> TestResult
}

class AppCompatibilityTestSuite {
    static let tests: [CompatibilityTest] = [
        CompatibilityTest(
            name: "Basic Text Injection",
            test: { target in
                let injector = TextInjectorFactory.createInjector(for: target)
                try await injector.inject("Test text", into: target)
                return .success
            }
        ),
        
        CompatibilityTest(
            name: "Special Characters",
            test: { target in
                let specialChars = "!@#$%^&*()_+-=[]{}|;':\",./<>?"
                let injector = TextInjectorFactory.createInjector(for: target)
                try await injector.inject(specialChars, into: target)
                return .success
            }
        ),
        
        CompatibilityTest(
            name: "Long Text Performance",
            test: { target in
                let longText = String(repeating: "Lorem ipsum ", count: 1000)
                let injector = TextInjectorFactory.createInjector(for: target)
                
                let start = Date()
                try await injector.inject(longText, into: target)
                let duration = Date().timeIntervalSince(start)
                
                return duration < 2.0 ? .success : .warning("Slow injection: \(duration)s")
            }
        )
    ]
    
    static func runTests(for app: TargetApplication) async -> [TestResult] {
        var results: [TestResult] = []
        
        for test in tests {
            do {
                let result = try await test.test(app)
                results.append(result)
                print("✅ \(test.name): Passed")
            } catch {
                results.append(.failure(error.localizedDescription))
                print("❌ \(test.name): Failed - \(error)")
            }
        }
        
        return results
    }
}
```

## Configuration Format

### App Compatibility Configuration File

VoiceType uses a JSON configuration file for app compatibility:

```json
{
  "version": "1.0",
  "apps": [
    {
      "bundleId": "com.apple.TextEdit",
      "name": "TextEdit",
      "category": "text-editor",
      "injection": {
        "primary": "accessibility",
        "fallback": "clipboard"
      },
      "settings": {
        "preserveFormatting": true,
        "supportRichText": true
      },
      "knownIssues": [],
      "lastTested": "2024-01-15"
    },
    {
      "bundleId": "com.tinyspeck.slackmacgap",
      "name": "Slack",
      "category": "communication",
      "injection": {
        "primary": "custom",
        "customClass": "SlackInjector",
        "fallback": "clipboard"
      },
      "settings": {
        "handleMarkdown": true,
        "emojiConversion": true,
        "multilineSupport": true
      },
      "knownIssues": [
        "Emoji picker may interfere with injection"
      ],
      "lastTested": "2024-01-10"
    }
  ]
}
```

### Loading Configuration

```swift
class AppCompatibilityManager {
    static func loadConfiguration() throws -> AppCompatibilityConfig {
        let configURL = Bundle.main.url(
            forResource: "AppCompatibility",
            withExtension: "json"
        )!
        
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(AppCompatibilityConfig.self, from: data)
    }
    
    static func injector(for app: TargetApplication) -> TextInjector {
        do {
            let config = try loadConfiguration()
            
            if let appConfig = config.apps.first(
                where: { $0.bundleId == app.bundleIdentifier }
            ) {
                return createInjector(from: appConfig)
            }
        } catch {
            print("Failed to load app config: \(error)")
        }
        
        // Default fallback
        return AccessibilityInjector()
    }
}
```

## Troubleshooting Common Issues

### Issue: Text Not Appearing

**Symptoms:** Injection completes but text doesn't appear

**Solutions:**
1. Check if the app has focus
2. Verify cursor is in a text field
3. Test with clipboard method
4. Check accessibility permissions

```swift
func diagnoseInjectionFailure(app: TargetApplication) async {
    print("Diagnosing injection failure for \(app.name)")
    
    // Check app is running
    if !isAppRunning(app) {
        print("❌ App is not running")
        return
    }
    
    // Check accessibility
    if !AXIsProcessTrusted() {
        print("❌ Accessibility permission not granted")
        return
    }
    
    // Try different methods
    let methods: [(String, TextInjector)] = [
        ("Accessibility", AccessibilityInjector()),
        ("Clipboard", ClipboardInjector()),
        ("Keyboard", KeyboardSimulationInjector())
    ]
    
    for (name, injector) in methods {
        do {
            try await injector.inject("test", into: app)
            print("✅ \(name) injection works")
        } catch {
            print("❌ \(name) injection failed: \(error)")
        }
    }
}
```

### Issue: Special Characters Corrupted

**Symptoms:** Special characters appear as question marks or boxes

**Solutions:**
1. Ensure proper text encoding
2. Use clipboard for Unicode
3. Check app's character support

### Issue: Slow Injection

**Symptoms:** Text appears character by character slowly

**Solutions:**
1. Use accessibility API instead of keyboard
2. Batch text insertion
3. Increase event posting speed

## Best Practices

### 1. Progressive Enhancement

Start with the most reliable method and fall back gracefully:

```swift
func inject(_ text: String, into app: TargetApplication) async throws {
    let strategies: [TextInjector] = [
        AccessibilityInjector(),
        ClipboardInjector(),
        KeyboardSimulationInjector()
    ]
    
    var lastError: Error?
    
    for strategy in strategies {
        do {
            try await strategy.inject(text, into: app)
            return // Success!
        } catch {
            lastError = error
            continue // Try next strategy
        }
    }
    
    throw lastError ?? VoiceTypeError.injectionFailed("All strategies failed")
}
```

### 2. User Notification

Inform users about compatibility:

```swift
class CompatibilityNotifier {
    static func notifyUserAboutApp(_ app: TargetApplication) {
        if isFirstTimeWithApp(app) {
            showNotification(
                title: "VoiceType Compatibility",
                message: determineCompatibilityMessage(for: app)
            )
        }
    }
    
    static func determineCompatibilityMessage(for app: TargetApplication) -> String {
        switch app.bundleIdentifier {
        case "com.apple.TextEdit", "com.apple.Notes":
            return "\(app.name) works great with VoiceType!"
            
        case "com.google.Chrome":
            return "\(app.name) works well. For best results, click in text fields first."
            
        default:
            return "VoiceType will use clipboard mode for \(app.name). Press ⌘V after dictation."
        }
    }
}
```

### 3. Continuous Testing

Regularly test app compatibility:

```swift
class CompatibilityMonitor {
    static func scheduleRegularTests() {
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            Task {
                await runCompatibilityTests()
            }
        }
    }
    
    static func runCompatibilityTests() async {
        let commonApps = [
            "com.apple.TextEdit",
            "com.apple.Notes",
            "com.microsoft.Word",
            "com.google.Chrome",
            "com.tinyspeck.slackmacgap"
        ]
        
        for bundleId in commonApps {
            if let app = getRunningApp(bundleId: bundleId) {
                let results = await AppCompatibilityTestSuite.runTests(for: app)
                logResults(app: bundleId, results: results)
            }
        }
    }
}
```

## Adding Your App

To request support for a new application:

1. **Test current compatibility** using VoiceType
2. **Document issues** you encounter
3. **Submit request** with:
   - App name and bundle ID
   - macOS version
   - Specific issues encountered
   - Screenshots if helpful

Or contribute directly by:
1. Following this guide to implement support
2. Testing thoroughly
3. Submitting a pull request

Your contributions help make VoiceType work better for everyone!