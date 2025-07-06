# Text Injection System

The VoiceType text injection system provides multiple methods to insert transcribed text into any application on macOS, with automatic fallback mechanisms to ensure reliability.

## Architecture

The system uses a chain of responsibility pattern with multiple injection methods:

1. **App-Specific Injection** - Custom handlers for specific applications
2. **Accessibility API Injection** - Direct text insertion using macOS accessibility
3. **Smart Clipboard Injection** - Enhanced clipboard method with app-specific delays
4. **Basic Clipboard Injection** - Universal fallback using copy/paste

## Components

### Core Protocol

- `TextInjector` - Base protocol for all injection methods
- `TextInjectorManager` - Manages multiple injectors with automatic fallback
- `TextInjectionError` - Comprehensive error types for debugging

### Implementations

#### AccessibilityInjector
Uses macOS Accessibility APIs to directly insert text:
- Detects focused text elements
- Supports multiple injection techniques
- Handles incompatible applications gracefully

#### ClipboardInjector
Universal fallback using clipboard:
- Preserves existing clipboard contents
- Simulates Cmd+V keystroke
- Works with virtually all applications

#### AppSpecificInjector
Provides optimized injection for specific apps:
- Safari - Handles web forms and content editable elements
- Chrome - Special handling for web applications
- Slack - Optimized for message composition
- Notes - Rich text support
- Xcode - Code editor compatibility

#### MockTextInjector
Testing utilities:
- Configurable success/failure patterns
- Injection history tracking
- Performance testing support

## Usage

### Basic Usage

```swift
// Create default injector manager
let injectorManager = TextInjectorFactory.createDefaultInjectorManager()

// Inject text
injectorManager.inject(text: "Hello, World!") { result in
    if result.success {
        print("Injected via \(result.method)")
    } else if let error = result.error {
        print("Failed: \(error.localizedDescription)")
    }
}
```

### Custom Configuration

```swift
var config = TextInjectionConfiguration()
config.enableAccessibility = true
config.enableAppSpecific = true
config.customStrategies = [MyCustomStrategy()]

let injectorManager = config.buildInjectorManager()
```

### Error Handling

```swift
injectorManager.inject(text: text) { result in
    switch result.error {
    case .accessibilityNotEnabled:
        // Request accessibility permissions
    case .noFocusedElement:
        // Show user hint to click in text field
    case .incompatibleApplication(let app):
        // Log incompatible app for future support
    default:
        break
    }
}
```

## Requirements

- macOS 12.0+
- Accessibility permissions for full functionality
- Swift 5.9+

## Security Considerations

- Requires user consent for accessibility permissions
- Clipboard contents are preserved during injection
- No text is logged or stored permanently
- App-specific strategies respect application security boundaries

## Performance

- Accessibility injection: ~10-50ms
- Clipboard injection: ~100-200ms
- App-specific injection: Varies by application

## Testing

Use `MockTextInjector` for unit tests:

```swift
let mock = ConfigurableMockInjector()
mock.failurePattern = .everyNthAttempt(3)
mock.compatibilityPattern = .always

// Test injection behavior
mock.inject(text: "test") { result in
    XCTAssertTrue(result.success)
}
```