import Foundation
import AppKit
import VoiceTypeCore

/// Protocol for app-specific injection strategies
public protocol AppInjectionStrategy {
    var bundleIdentifier: String { get }
    func canHandle(element: AXUIElement) -> Bool
    func inject(text: String, element: AXUIElement) throws
}

/// Manages app-specific injection strategies
public class AppSpecificInjector: TextInjector {
    public var methodName: String { "AppSpecific" }

    private var strategies: [String: AppInjectionStrategy] = [:]
    private let fallbackInjector: TextInjector

    public init(fallbackInjector: TextInjector = ClipboardInjector()) {
        self.fallbackInjector = fallbackInjector
        registerDefaultStrategies()
    }

    public func inject(text: String, completion: @escaping (Result<Void, TextInjectionError>) -> Void) {
        print("[AppSpecificInjector] Starting app-specific injection")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("[AppSpecificInjector] ERROR: Injector deallocated")
                completion(.failure(.injectionFailed(reason: "Injector deallocated")))
                return
            }

            guard let context = self.getCurrentContext() else {
                print("[AppSpecificInjector] No context available, falling back to clipboard method")
                // Fall back to clipboard method
                self.fallbackInjector.inject(text: text, completion: completion)
                return
            }

            if let bundleId = context.bundleIdentifier {
                let appName = context.appName ?? "Unknown"
                print("[AppSpecificInjector] Current app: \(appName) (bundle ID: \(bundleId))")
                
                if let strategy = self.strategies[bundleId],
                   let element = context.focusedElement,
                   strategy.canHandle(element: element) {
                    print("[AppSpecificInjector] Found strategy for \(appName), attempting injection...")
                    
                    do {
                        try strategy.inject(text: text, element: element)
                        print("[AppSpecificInjector] App-specific injection successful")
                        completion(.success(()))
                    } catch let error as TextInjectionError {
                        print("[AppSpecificInjector] App-specific injection failed: \(error)")
                        completion(.failure(error))
                    } catch {
                        print("[AppSpecificInjector] App-specific injection failed with unexpected error: \(error)")
                        completion(.failure(.injectionFailed(reason: error.localizedDescription)))
                    }
                } else {
                    print("[AppSpecificInjector] No strategy found for \(appName), using fallback")
                    // Use fallback
                    self.fallbackInjector.inject(text: text, completion: completion)
                }
            } else {
                print("[AppSpecificInjector] No bundle ID available, using fallback")
                self.fallbackInjector.inject(text: text, completion: completion)
            }
        }
    }

    public func isCompatibleWithCurrentContext() -> Bool {
        print("[AppSpecificInjector] Checking compatibility...")
        
        guard let context = getCurrentContext() else {
            print("[AppSpecificInjector] No context, checking fallback compatibility")
            return fallbackInjector.isCompatibleWithCurrentContext()
        }

        if let bundleId = context.bundleIdentifier,
           let strategy = strategies[bundleId],
           let element = context.focusedElement {
            let appName = context.appName ?? "Unknown"
            let canHandle = strategy.canHandle(element: element)
            print("[AppSpecificInjector] Strategy for \(appName) can handle: \(canHandle)")
            return canHandle
        }

        print("[AppSpecificInjector] No specific strategy, checking fallback compatibility")
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

    private func getCurrentContext() -> (bundleIdentifier: String?, appName: String?, focusedElement: AXUIElement?)? {
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

        return (frontmostApp.bundleIdentifier, frontmostApp.localizedName, element as! AXUIElement)
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
            print("[ChromeInjectionStrategy] Element role: \(roleString)")
            
            // Chrome uses various roles for text input
            let acceptedRoles = [
                kAXTextFieldRole as String,
                kAXTextAreaRole as String,
                "AXTextField",
                "AXTextArea",
                "AXWebArea",
                "AXGroup",  // Chrome sometimes uses groups for input areas
                "AXStaticText"  // For contenteditable elements
            ]
            
            return acceptedRoles.contains(roleString)
        }
        return false
    }

    func inject(text: String, element: AXUIElement) throws {
        print("[ChromeInjectionStrategy] Attempting Chrome-specific injection")
        
        // Chrome sometimes needs special handling for content editable divs
        // Try setting selected text first
        print("[ChromeInjectionStrategy] Trying selected text approach...")
        let selectedResult = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)

        if selectedResult != .success {
            print("[ChromeInjectionStrategy] Selected text failed (result: \(selectedResult.rawValue)), trying value approach...")
            
            // Fall back to value setting
            let valueResult = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFString)
            if valueResult != .success {
                print("[ChromeInjectionStrategy] Value approach also failed (result: \(valueResult.rawValue))")
                throw TextInjectionError.injectionFailed(reason: "Chrome injection failed")
            } else {
                print("[ChromeInjectionStrategy] Value approach succeeded")
            }
        } else {
            print("[ChromeInjectionStrategy] Selected text approach succeeded")
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
            throw TextInjectionError.incompatibleApplication("Xcode")
        }
    }
}
