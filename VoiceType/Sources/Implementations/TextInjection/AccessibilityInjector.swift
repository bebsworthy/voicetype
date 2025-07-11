import Foundation
import AppKit
import ApplicationServices
import VoiceTypeCore

/// Text injector using macOS Accessibility APIs
public class AccessibilityInjector: TextInjector {
    public var methodName: String { "Accessibility" }

    // Known problematic applications that don't support accessibility properly
    private let incompatibleApps = Set([
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.microsoft.VSCode",
        "com.sublimetext.4"
    ])

    public init() {}

    public func inject(text: String, completion: @escaping (Result<Void, TextInjectionError>) -> Void) {
        print("[AccessibilityInjector] Starting accessibility injection")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("[AccessibilityInjector] ERROR: Injector deallocated")
                completion(.failure(.injectionFailed(reason: "Injector deallocated")))
                return
            }

            do {
                try self.performInjection(text: text)
                print("[AccessibilityInjector] Injection successful")
                completion(.success(()))
            } catch let error as TextInjectionError {
                print("[AccessibilityInjector] Injection failed with error: \(error)")
                completion(.failure(error))
            } catch {
                print("[AccessibilityInjector] Injection failed with unexpected error: \(error)")
                completion(.failure(.injectionFailed(reason: error.localizedDescription)))
            }
        }
    }

    public func isCompatibleWithCurrentContext() -> Bool {
        print("[AccessibilityInjector] Checking compatibility...")
        
        // Check accessibility permissions
        guard AXIsProcessTrusted() else {
            print("[AccessibilityInjector] Not compatible: Accessibility permissions not granted")
            return false
        }

        // Check if current app is in incompatible list
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontmostApp.bundleIdentifier {
            print("[AccessibilityInjector] Current app: \(frontmostApp.localizedName ?? "Unknown") (\(bundleId))")
            
            if incompatibleApps.contains(bundleId) {
                print("[AccessibilityInjector] Not compatible: App is in incompatible list")
                return false
            }
            
            // Chrome has known issues with accessibility APIs for web content
            if bundleId == "com.google.Chrome" {
                print("[AccessibilityInjector] Not compatible: Chrome doesn't support accessibility APIs for web content")
                return false
            }
        }

        // Check if we can access the focused element
        guard let systemWideElement = AXUIElementCreateSystemWide() as AXUIElement?,
              let focusedElement = getFocusedElement(from: systemWideElement) else {
            print("[AccessibilityInjector] Not compatible: Cannot access focused element")
            return false
        }

        // Check if the focused element supports text input
        let isTextInput = isTextInputElement(focusedElement)
        print("[AccessibilityInjector] Focused element is text input: \(isTextInput)")
        
        return isTextInput
    }

    private func performInjection(text: String) throws {
        print("[AccessibilityInjector] Performing injection...")
        
        // Validate input
        guard !text.isEmpty else {
            print("[AccessibilityInjector] ERROR: Cannot inject empty text")
            throw TextInjectionError.injectionFailed(reason: "Cannot inject empty text")
        }
        
        guard AXIsProcessTrusted() else {
            print("[AccessibilityInjector] ERROR: Accessibility not enabled")
            throw TextInjectionError.accessibilityNotEnabled
        }

        guard let systemWideElement = AXUIElementCreateSystemWide() as AXUIElement? else {
            print("[AccessibilityInjector] ERROR: Failed to create system-wide element")
            throw TextInjectionError.injectionFailed(reason: "Failed to create system-wide element")
        }

        guard let focusedElement = getFocusedElement(from: systemWideElement) else {
            print("[AccessibilityInjector] ERROR: No focused element found")
            throw TextInjectionError.noFocusedElement
        }

        guard isTextInputElement(focusedElement) else {
            print("[AccessibilityInjector] ERROR: Focused element is not a text input")
            throw TextInjectionError.noFocusedElement
        }

        // Try different methods to insert text
        print("[AccessibilityInjector] Trying direct value set...")
        if let error = tryDirectValueSet(element: focusedElement, text: text) {
            print("[AccessibilityInjector] Direct value set failed: \(error)")
            print("[AccessibilityInjector] Trying selected text replacement...")
            
            if let error = trySelectedTextReplacement(element: focusedElement, text: text) {
                print("[AccessibilityInjector] Selected text replacement failed: \(error)")
                print("[AccessibilityInjector] Trying keystroke simulation...")
                
                if let error = tryKeystrokeSimulation(text: text) {
                    print("[AccessibilityInjector] Keystroke simulation failed: \(error)")
                    throw TextInjectionError.injectionFailed(reason: "All injection methods failed: \(error)")
                } else {
                    print("[AccessibilityInjector] Keystroke simulation succeeded")
                }
            } else {
                print("[AccessibilityInjector] Selected text replacement succeeded")
            }
        } else {
            print("[AccessibilityInjector] Direct value set succeeded")
        }
    }

    private func getFocusedElement(from systemWideElement: AXUIElement) -> AXUIElement? {
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard result == .success, let element = focusedElement else {
            print("[AccessibilityInjector] Failed to get focused element. Result: \(result.rawValue)")
            
            // Try alternative approach for Chrome
            if let frontmostApp = NSWorkspace.shared.frontmostApplication,
               frontmostApp.bundleIdentifier == "com.google.Chrome" {
                print("[AccessibilityInjector] Chrome detected, trying alternative focus detection...")
                return tryChromeFocusDetection()
            }
            
            return nil
        }

        print("[AccessibilityInjector] Got focused element successfully")
        return (element as! AXUIElement)
    }

    private func isTextInputElement(_ element: AXUIElement) -> Bool {
        var role: CFTypeRef?
        let roleResult = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        guard roleResult == .success, let roleString = role as? String else {
            print("[AccessibilityInjector] Could not get element role")
            return false
        }

        print("[AccessibilityInjector] Element role: \(roleString)")
        
        let textInputRoles = [
            kAXTextFieldRole as String,
            kAXTextAreaRole as String,
            // kAXSearchFieldRole, // Not available on macOS
            kAXComboBoxRole as String,
            kAXStaticTextRole as String
        ]

        let isTextInput = textInputRoles.contains(roleString)
        if !isTextInput {
            print("[AccessibilityInjector] Role '\(roleString)' is not in text input roles: \(textInputRoles)")
        }
        
        return isTextInput
    }

    private func tryDirectValueSet(element: AXUIElement, text: String) -> String? {
        // Get current value
        var currentValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &currentValue)

        let currentText = (currentValue as? String) ?? ""

        // Get selection range
        var selectedRange: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRange)

        if rangeResult == .success, let range = selectedRange {
            // Insert at selection
            var cfRange = CFRange()
            if AXValueGetValue(range as! AXValue, .cfRange, &cfRange) {
                let nsRange = NSRange(location: cfRange.location, length: cfRange.length)
                let mutableText = NSMutableString(string: currentText)
                
                // Validate range bounds
                let textLength = mutableText.length
                if nsRange.location >= 0 && 
                   nsRange.location <= textLength && 
                   nsRange.location + nsRange.length <= textLength {
                    mutableText.replaceCharacters(in: nsRange, with: text)
                    
                    let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, mutableText as CFString)
                    return result == .success ? nil : "Failed to set value"
                } else {
                    // Range is out of bounds, append to end instead
                    let newText = currentText + text
                    let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFString)
                    return result == .success ? nil : "Failed to set value (invalid range)"
                }
            }
        } else {
            // Append to end
            let newText = currentText + text
            let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newText as CFString)
            return result == .success ? nil : "Failed to set value"
        }

        return "Failed to process selection range"
    }

    private func trySelectedTextReplacement(element: AXUIElement, text: String) -> String? {
        // First, try to set selected text directly
        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)

        if result == .success {
            return nil
        }

        // If that fails, try to select all and replace
        var selectAllAction: CFTypeRef?
        let actionResult = AXUIElementCopyAttributeValue(element, "AXActions" as CFString, &selectAllAction)

        if actionResult == .success, let actions = selectAllAction as? [String], actions.contains("AXSelectAll") {
            AXUIElementPerformAction(element, "AXSelectAll" as CFString)
            Thread.sleep(forTimeInterval: 0.1)

            let replaceResult = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)
            return replaceResult == .success ? nil : "Failed to replace selected text"
        }

        return "Selected text replacement not available"
    }

    private func tryKeystrokeSimulation(text: String) -> String? {
        // This is a last resort - simulate actual keystrokes
        // Note: This method is slower and may have issues with special characters

        let source = CGEventSource(stateID: .combinedSessionState)

        for character in text {
            if let keyCode = keyCodeForCharacter(character) {
                let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
                let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

                keyDown?.post(tap: .cghidEventTap)
                keyUp?.post(tap: .cghidEventTap)

                Thread.sleep(forTimeInterval: 0.001) // Small delay between keystrokes
            } else {
                // For characters without a simple key code, use Unicode events
                let utf16Chars = Array(String(character).utf16)
                var event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
                event?.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: utf16Chars)
                event?.post(tap: .cghidEventTap)
            }
        }

        return nil
    }

    // Simplified key code mapping - in production, this would be more comprehensive
    private func keyCodeForCharacter(_ character: Character) -> CGKeyCode? {
        let keyMap: [Character: CGKeyCode] = [
            "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
            "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B, "q": 0x0C,
            "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11, "1": 0x12,
            "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17, "=": 0x18,
            "9": 0x19, "7": 0x1A, "-": 0x1B, "8": 0x1C, "0": 0x1D, "]": 0x1E,
            "o": 0x1F, "u": 0x20, "[": 0x21, "i": 0x22, "p": 0x23, "l": 0x25,
            "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29, "\\": 0x2A, ",": 0x2B,
            "/": 0x2C, "n": 0x2D, "m": 0x2E, ".": 0x2F, " ": 0x31, "`": 0x32,
            "\n": 0x24, "\r": 0x24, "\t": 0x30
        ]

        return keyMap[character]
    }
    
    private func tryChromeFocusDetection() -> AXUIElement? {
        print("[AccessibilityInjector] Attempting Chrome-specific focus detection...")
        
        guard let chromeApp = NSWorkspace.shared.frontmostApplication,
              let pid = chromeApp.processIdentifier as? pid_t else {
            print("[AccessibilityInjector] Could not get Chrome process ID")
            return nil
        }
        
        let appElement = AXUIElementCreateApplication(pid)
        
        // Try to get the focused window
        var focusedWindow: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        
        if windowResult == .success, let window = focusedWindow {
            print("[AccessibilityInjector] Got Chrome focused window")
            
            // Try to get focused element from window
            var focusedElement: CFTypeRef?
            let elementResult = AXUIElementCopyAttributeValue(window as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
            
            if elementResult == .success, let element = focusedElement {
                print("[AccessibilityInjector] Got focused element from Chrome window")
                return (element as! AXUIElement)
            } else {
                print("[AccessibilityInjector] Could not get focused element from Chrome window. Result: \(elementResult.rawValue)")
            }
        } else {
            print("[AccessibilityInjector] Could not get Chrome focused window. Result: \(windowResult.rawValue)")
        }
        
        return nil
    }
}

// Extension to safely get AXValue
extension AXValue {
    func getValue<T>() -> T? {
        let type = AXValueGetType(self)

        switch type {
        case .cfRange:
            var range = CFRange()
            if AXValueGetValue(self, type, &range) {
                return range as? T
            }
        default:
            break
        }

        return nil
    }
}
