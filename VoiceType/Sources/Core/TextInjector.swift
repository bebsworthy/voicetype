import Foundation

/// Protocol defining the interface for inserting text into target applications.
/// Implementations handle different injection methods (accessibility API, clipboard, etc.)
public protocol TextInjector {
    /// Human-readable name of this injection method
    var methodName: String { get }
    
    /// Injects text using this method
    /// - Parameters:
    ///   - text: The text to inject
    ///   - completion: Callback with the result
    func inject(text: String, completion: @escaping (Result<Void, TextInjectionError>) -> Void)
    
    /// Checks if this injector is compatible with the current context
    /// - Returns: true if this injector can be used right now
    func isCompatibleWithCurrentContext() -> Bool
}

/// Errors that can occur during text injection
public enum TextInjectionError: LocalizedError {
    case incompatibleApplication(String)
    case noFocusedElement
    case accessibilityNotEnabled
    case clipboardError(String)
    case injectionFailed(reason: String)
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .incompatibleApplication(let app):
            return "Text injection not supported for \(app)"
        case .noFocusedElement:
            return "No text field is currently focused"
        case .accessibilityNotEnabled:
            return "Accessibility permission required. Grant permission in System Preferences > Privacy & Security > Accessibility"
        case .clipboardError(let reason):
            return "Clipboard operation failed: \(reason)"
        case .injectionFailed(let reason):
            return "Failed to inject text: \(reason)"
        case .timeout:
            return "Text injection timed out"
        }
    }
}

/// Context information about the target application
public struct ApplicationContext {
    public let bundleIdentifier: String?
    public let name: String
    public let isRunning: Bool
    
    public init(bundleIdentifier: String?, name: String, isRunning: Bool) {
        self.bundleIdentifier = bundleIdentifier
        self.name = name
        self.isRunning = isRunning
    }
}

/// Result of a text injection operation
public struct InjectionResult {
    public let success: Bool
    public let method: String
    public let error: TextInjectionError?
    public let fallbackUsed: Bool
    
    public init(success: Bool, method: String, error: TextInjectionError? = nil, fallbackUsed: Bool = false) {
        self.success = success
        self.method = method
        self.error = error
        self.fallbackUsed = fallbackUsed
    }
}

// Note: TextInjectorManager is implemented in the Implementations module
// to avoid circular dependencies