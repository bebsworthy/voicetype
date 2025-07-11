import Foundation
import AppKit
import VoiceTypeCore

/// Text injector using clipboard and paste simulation
public class ClipboardInjector: TextInjector {
    public var methodName: String { "Clipboard" }
    private let pasteboard = NSPasteboard.general
    private let pasteDelay: TimeInterval = 0.1

    public init() {}

    public func inject(text: String, completion: @escaping (Result<Void, TextInjectionError>) -> Void) {
        print("[ClipboardInjector] Starting clipboard injection")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("[ClipboardInjector] ERROR: Injector deallocated")
                completion(.failure(.injectionFailed(reason: "Injector deallocated")))
                return
            }

            do {
                try self.performClipboardInjection(text: text)
                print("[ClipboardInjector] Injection successful")
                completion(.success(()))
            } catch let error as TextInjectionError {
                print("[ClipboardInjector] Injection failed: \(error)")
                completion(.failure(error))
            } catch {
                print("[ClipboardInjector] Injection failed with unexpected error: \(error)")
                completion(.failure(.clipboardError(error.localizedDescription)))
            }
        }
    }

    public func isCompatibleWithCurrentContext() -> Bool {
        // Clipboard injection works almost everywhere
        // Just check if we have a frontmost application
        let hasFrontmostApp = NSWorkspace.shared.frontmostApplication != nil
        print("[ClipboardInjector] Has frontmost app: \(hasFrontmostApp)")
        return hasFrontmostApp
    }

    private func performClipboardInjection(text: String) throws {
        print("[ClipboardInjector] Performing clipboard injection...")
        
        // Save current clipboard contents
        print("[ClipboardInjector] Saving current clipboard contents...")
        let savedClipboard = saveClipboard()

        // Set new clipboard content
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)

        guard success else {
            print("[ClipboardInjector] ERROR: Failed to set clipboard")
            throw TextInjectionError.clipboardError("Failed to set clipboard")
        }

        print("[ClipboardInjector] Text copied to clipboard, waiting 0.05s...")
        // Small delay to ensure clipboard is ready
        Thread.sleep(forTimeInterval: 0.05)

        // Simulate Cmd+V
        print("[ClipboardInjector] Simulating Cmd+V paste...")
        simulatePaste()

        // Wait for paste to complete
        print("[ClipboardInjector] Waiting \(pasteDelay)s for paste to complete...")
        Thread.sleep(forTimeInterval: pasteDelay)

        // Restore original clipboard contents
        print("[ClipboardInjector] Restoring original clipboard contents...")
        restoreClipboard(savedClipboard)
        
        print("[ClipboardInjector] Clipboard injection completed")
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
    override public var methodName: String { "SmartClipboard" }

    private let appSpecificDelays: [String: TimeInterval] = [
        "com.apple.Safari": 0.15,
        "com.google.Chrome": 0.15,
        "com.microsoft.Word": 0.2,
        "com.apple.mail": 0.15,
        "org.mozilla.firefox": 0.15
    ]

    override public func inject(text: String, completion: @escaping (Result<Void, TextInjectionError>) -> Void) {
        print("[SmartClipboardInjector] Starting smart clipboard injection")
        
        // Adjust delay based on current application
        if let frontmostApp = NSWorkspace.shared.frontmostApplication,
           let bundleId = frontmostApp.bundleIdentifier {
            print("[SmartClipboardInjector] Current app: \(frontmostApp.localizedName ?? "Unknown") (\(bundleId))")
            
            if let customDelay = appSpecificDelays[bundleId] {
                print("[SmartClipboardInjector] Using custom delay of \(customDelay)s for \(bundleId)")
                DispatchQueue.main.asyncAfter(deadline: .now() + customDelay) {
                    super.inject(text: text, completion: completion)
                }
            } else {
                print("[SmartClipboardInjector] No custom delay for \(bundleId), using default")
                super.inject(text: text, completion: completion)
            }
        } else {
            print("[SmartClipboardInjector] No frontmost app detected, using default delay")
            super.inject(text: text, completion: completion)
        }
    }
}
