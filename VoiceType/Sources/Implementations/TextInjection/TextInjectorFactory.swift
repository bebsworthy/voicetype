import Foundation

/// Factory for creating text injector configurations
public class TextInjectorFactory {
    
    /// Create the default production text injector manager
    public static func createDefaultInjectorManager() -> TextInjectorManager {
        let injectors: [TextInjector] = [
            // Primary: App-specific injector with accessibility
            AppSpecificInjector(fallbackInjector: AccessibilityInjector()),
            
            // Secondary: Direct accessibility injection
            AccessibilityInjector(),
            
            // Tertiary: Smart clipboard with app-specific delays
            SmartClipboardInjector(),
            
            // Last resort: Basic clipboard injection
            ClipboardInjector()
        ]
        
        return TextInjectorManager(injectors: injectors)
    }
    
    /// Create a test injector manager with mock implementations
    public static func createTestInjectorManager() -> TextInjectorManager {
        let mockInjector = ConfigurableMockInjector()
        mockInjector.failurePattern = .random(probability: 0.1) // 10% failure rate
        
        let injectors: [TextInjector] = [
            mockInjector,
            MockTextInjector() // Always succeeds as fallback
        ]
        
        return TextInjectorManager(injectors: injectors)
    }
    
    /// Create a minimal injector manager (clipboard only)
    public static func createMinimalInjectorManager() -> TextInjectorManager {
        return TextInjectorManager(injectors: [ClipboardInjector()])
    }
    
    /// Create a custom injector manager
    public static func createCustomInjectorManager(injectors: [TextInjector]) -> TextInjectorManager {
        return TextInjectorManager(injectors: injectors)
    }
}

/// Configuration for text injection behavior
public struct TextInjectionConfiguration {
    public var enableAccessibility: Bool = true
    public var enableAppSpecific: Bool = true
    public var enableSmartClipboard: Bool = true
    public var fallbackToClipboard: Bool = true
    public var customStrategies: [AppInjectionStrategy] = []
    
    public init() {}
    
    /// Build an injector manager based on this configuration
    public func buildInjectorManager() -> TextInjectorManager {
        var injectors: [TextInjector] = []
        
        if enableAppSpecific {
            let appSpecific = AppSpecificInjector(
                fallbackInjector: enableAccessibility ? AccessibilityInjector() : ClipboardInjector()
            )
            
            // Add custom strategies
            for strategy in customStrategies {
                appSpecific.registerStrategy(strategy)
            }
            
            injectors.append(appSpecific)
        }
        
        if enableAccessibility {
            injectors.append(AccessibilityInjector())
        }
        
        if enableSmartClipboard {
            injectors.append(SmartClipboardInjector())
        }
        
        if fallbackToClipboard {
            injectors.append(ClipboardInjector())
        }
        
        return TextInjectorManager(injectors: injectors)
    }
}