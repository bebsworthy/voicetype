import Foundation
import AppKit

/// Protocol for app-specific injection strategies
public protocol AppInjectionStrategy {
    var bundleIdentifier: String { get }
    func canHandle(element: AXUIElement) -> Bool
    func inject(text: String, element: AXUIElement) throws
}

/// Manages app-specific injection strategies
public class AppSpecificInjector: TextInjector {
    public let methodName = "AppSpecific"
    
    private var strategies: [String: AppInjectionStrategy] = [:]
    private let fallbackInjector: TextInjector
    
    public init(fallbackInjector: TextInjector = ClipboardInjector()) {
        self.fallbackInjector = fallbackInjector
        registerDefaultStrategies()
    }
    
    public func inject(text: String, completion: @escaping (Result<Void, TextInjectionError>) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion(.failure(.injectionFailed(reason: "Injector deallocated")))
                return
            }
            
            guard let context = self.getCurrentContext() else {
                // Fall back to clipboard method
                self.fallbackInjector.inject(text: text, completion: completion)
                return
            }
            
            if let bundleId = context.bundleIdentifier,
               let strategy = self.strategies[bundleId],
               let element = context.focusedElement,
               strategy.canHandle(element: element) {
                
                do {
                    try strategy.inject(text: text, element: element)
                    completion(.success(()))
                } catch let error as TextInjectionError {
                    completion(.failure(error))
                } catch {
                    completion(.failure(.injectionFailed(reason: error.localizedDescription)))
                }
            } else {
                // Use fallback
                self.fallbackInjector.inject(text: text, completion: completion)
            }
        }
    }
    
    public func isCompatibleWithCurrentContext() -> Bool {
        guard let context = getCurrentContext() else {
            return fallbackInjector.isCompatibleWithCurrentContext()
        }
        
        if let bundleId = context.bundleIdentifier,
           let strategy = strategies[bundleId],
           let element = context.focusedElement {
            return strategy.canHandle(element: element)
        }
        
        return fallbackInjector.isCompatibleWithCurrentContext()
    }
    
    public func registerStrategy(_ strategy: AppInjectionStrategy) {
        strategies[strategy.bundleIdentifier] = strategy
    }
    
    private func registerDefaultStrategies() {
        // Register built-in strategies
        registerStrategy(SafariInjectionStrategy())
        registerStrategy(ChromeInjectionStrategy())
        registerStrategy(SlackInjectionStrategy())
        registerStrategy(NotesInjectionStrategy())
        registerStrategy(XcodeInjectionStrategy())
    }
    
    private func getCurrentContext() -> (bundleIdentifier: String?, focusedElement: AXUIElement?)? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication,
              AXIsProcessTrusted() else {
            return nil
        }
        
        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        
        guard result == .success, let element = focusedElement else {
            return nil
        }
        
        return (frontmostApp.bundleIdentifier, element as! AXUIElement)
    }
}

// MARK: - App-Specific Strategies

/// Safari-specific injection strategy
class SafariInjectionStrategy: AppInjectionStrategy {
    let bundleIdentifier = "com.apple.Safari"
    
    func canHandle(element: AXUIElement) -> Bool {
        // Check if it's a web content area
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if let roleString = role as? String {
            return roleString == kAXTextFieldRole as String ||
                   roleString == kAXTextAreaRole as String ||
                   roleString == "AXWebArea"
        }
        return false
    }
    
    func inject(text: String, element: AXUIElement) throws {
        // Safari often needs JavaScript injection for complex web apps
        // First try standard accessibility injection
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString)
        
        if result != .success {
            // Try focused element value setting
            var focusedElement: CFTypeRef?
            let focusResult = AXUIElementCopyAttributeValue(element, kAXFocusedUIElementAttribute as CFString, &focusedElement)
            
            if focusResult == .success, let focused = focusedElement {
                let valueResult = AXUIElementSetAttributeValue(focused as! AXUIElement, kAXValueAttribute as CFString, text as CFString)
                if valueResult != .success {
                    throw TextInjectionError.injectionFailed(reason: "Safari injection failed")
                }
            } else {
                throw TextInjectionError.injectionFailed(reason: "Could not access Safari focused element")
            }
        }
    }
}

/// Chrome-specific injection strategy
class ChromeInjectionStrategy: AppInjectionStrategy {
    let bundleIdentifier = "com.google.Chrome"
    
    func canHandle(element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if let roleString = role as? String {
            return roleString == kAXTextFieldRole as String ||
                   roleString == kAXTextAreaRole as String ||
                   roleString == "AXTextField"
        }
        return false
    }
    
    func inject(text: String, element: AXUIElement) throws {
        // Chrome sometimes needs special handling for content editable divs
        // Try setting selected text first
        let selectedResult = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)
        
        if selectedResult != .success {
            // Fall back to value setting
            let valueResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString)
            if valueResult != .success {
                throw TextInjectionError.injectionFailed(reason: "Chrome injection failed")
            }
        }
    }
}

/// Slack-specific injection strategy
class SlackInjectionStrategy: AppInjectionStrategy {
    let bundleIdentifier = "com.tinyspeck.slackmacgap"
    
    func canHandle(element: AXUIElement) -> Bool {
        // Slack uses custom web components
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if let roleString = role as? String {
            return roleString == kAXTextAreaRole as String ||
                   roleString == "AXTextArea" ||
                   roleString == "AXTextField"
        }
        return false
    }
    
    func inject(text: String, element: AXUIElement) throws {
        // Slack's message input needs special handling
        // Clear any existing selection first
        AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, "" as CFString)
        
        // Insert at cursor position
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)
        
        if result != .success {
            // Try appending to value
            var currentValue: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)
            let current = (currentValue as? String) ?? ""
            
            let valueResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, (current + text) as CFString)
            if valueResult != .success {
                throw TextInjectionError.injectionFailed(reason: "Slack injection failed")
            }
        }
    }
}

/// Notes app-specific injection strategy
class NotesInjectionStrategy: AppInjectionStrategy {
    let bundleIdentifier = "com.apple.Notes"
    
    func canHandle(element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if let roleString = role as? String {
            return roleString == kAXTextAreaRole as String ||
                   roleString == "AXTextArea"
        }
        return false
    }
    
    func inject(text: String, element: AXUIElement) throws {
        // Notes app uses rich text, so we need to handle it carefully
        // Get current selection
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)
        
        if rangeResult == .success {
            // Replace selected text
            let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)
            if result != .success {
                throw TextInjectionError.injectionFailed(reason: "Notes injection failed")
            }
        } else {
            // Append to end
            var currentValue: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)
            let current = (currentValue as? String) ?? ""
            
            let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, (current + text) as CFString)
            if result != .success {
                throw TextInjectionError.injectionFailed(reason: "Notes append failed")
            }
        }
    }
}

/// Xcode-specific injection strategy
class XcodeInjectionStrategy: AppInjectionStrategy {
    let bundleIdentifier = "com.apple.dt.Xcode"
    
    func canHandle(element: AXUIElement) -> Bool {
        // Xcode has complex editor structure
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        if let roleString = role as? String {
            return roleString == kAXTextAreaRole as String ||
                   roleString == "AXTextArea" ||
                   roleString.contains("Editor")
        }
        return false
    }
    
    func inject(text: String, element: AXUIElement) throws {
        // Xcode needs careful handling to maintain code formatting
        // Try to use selected text replacement
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)
        
        if result != .success {
            // Xcode might need a different approach
            throw TextInjectionError.incompatibleApplication(appName: "Xcode")
        }
    }
}