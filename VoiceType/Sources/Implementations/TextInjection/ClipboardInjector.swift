import Foundation
import AppKit

/// Text injector using clipboard and paste simulation
public class ClipboardInjector: TextInjector {
    public let methodName = "Clipboard"
    private let pasteboard = NSPasteboard.general
    private let pasteDelay: TimeInterval = 0.1
    
    public init() {}
    
    public func inject(text: String, completion: @escaping (Result<Void, TextInjectionError>) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion(.failure(.injectionFailed(reason: "Injector deallocated")))
                return
            }
            
            do {
                try self.performClipboardInjection(text: text)
                completion(.success(()))
            } catch let error as TextInjectionError {
                completion(.failure(error))
            } catch {
                completion(.failure(.clipboardError(error)))
            }
        }
    }
    
    public func isCompatibleWithCurrentContext() -> Bool {
        // Clipboard injection works almost everywhere
        // Just check if we have a frontmost application
        return NSWorkspace.shared.frontmostApplication != nil
    }
    
    private func performClipboardInjection(text: String) throws {
        // Save current clipboard contents
        let savedClipboard = saveClipboard()
        
        // Set new clipboard content
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        
        guard success else {
            throw TextInjectionError.clipboardError(
                NSError(domain: "VoiceType", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to set clipboard"])
            )
        }
        
        // Small delay to ensure clipboard is ready
        Thread.sleep(forTimeInterval: 0.05)
        
        // Simulate Cmd+V
        simulatePaste()
        
        // Wait for paste to complete
        Thread.sleep(forTimeInterval: pasteDelay)
        
        // Restore original clipboard contents
        restoreClipboard(savedClipboard)
    }
    
    private func saveClipboard() -> ClipboardBackup {
        var backup = ClipboardBackup()
        
        // Save all available types
        for type in pasteboard.types ?? [] {
            if let data = pasteboard.data(forType: type) {
                backup.items.append(ClipboardItem(type: type, data: data))
            }
        }
        
        return backup
    }
    
    private func restoreClipboard(_ backup: ClipboardBackup) {
        // Only restore if there was content
        guard !backup.items.isEmpty else { return }
        
        pasteboard.clearContents()
        
        for item in backup.items {
            pasteboard.setData(item.data, forType: item.type)
        }
    }
    
    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        
        // Create Cmd+V key events
        let vKeyCode: CGKeyCode = 0x09 // 'v' key
        
        // Key down event with Cmd modifier
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        
        // Key up event
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }
}

// Helper structures for clipboard backup
private struct ClipboardBackup {
    var items: [ClipboardItem] = []
}

private struct ClipboardItem {
    let type: NSPasteboard.PasteboardType
    let data: Data
}

/// Enhanced clipboard injector with app-specific optimizations
public class SmartClipboardInjector: ClipboardInjector {
    public override let methodName = "SmartClipboard"
    
    private let appSpecificDelays: [String: TimeInterval] = [
        "com.apple.Safari": 0.15,
        "com.google.Chrome": 0.15,
        "com.microsoft.Word": 0.2,
        "com.apple.mail": 0.15,
        "org.mozilla.firefox": 0.15
    ]
    
    public override func inject(text: String, completion: @escaping (Result<Void, TextInjectionError>) -> Void) {
        // Adjust delay based on current application
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontmostApp.bundleIdentifier,
           let customDelay = appSpecificDelays[bundleId] {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + customDelay) {
                super.inject(text: text, completion: completion)
            }
        } else {
            super.inject(text: text, completion: completion)
        }
    }
}