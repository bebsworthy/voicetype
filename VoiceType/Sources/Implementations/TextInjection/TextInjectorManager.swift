import Foundation
import AppKit
import VoiceTypeCore

/// Manages multiple text injection methods with automatic fallback
public class TextInjectorManager {
    private let injectors: [TextInjector]
    private let queue = DispatchQueue(label: "com.voicetype.textinjector", qos: .userInteractive)
    
    public init(injectors: [TextInjector]) {
        self.injectors = injectors
    }
    
    /// Inject text using the most appropriate method, with automatic fallback
    public func inject(text: String, completion: @escaping (InjectionResult) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(InjectionResult(success: false, method: "Unknown", error: .injectionFailed(reason: "Manager deallocated")))
                return
            }
            
            self.attemptInjection(text: text, injectorIndex: 0, completion: completion)
        }
    }
    
    private func attemptInjection(text: String, injectorIndex: Int, completion: @escaping (InjectionResult) -> Void) {
        guard injectorIndex < injectors.count else {
            completion(InjectionResult(
                success: false,
                method: "None",
                error: .injectionFailed(reason: "All injection methods failed")
            ))
            return
        }
        
        let injector = injectors[injectorIndex]
        
        // Check compatibility first
        if !injector.isCompatibleWithCurrentContext() {
            // Try next injector
            attemptInjection(text: text, injectorIndex: injectorIndex + 1, completion: completion)
            return
        }
        
        // Attempt injection
        injector.inject(text: text) { [weak self] result in
            switch result {
            case .success:
                completion(InjectionResult(
                    success: true,
                    method: injector.methodName,
                    fallbackUsed: injectorIndex > 0
                ))
            case .failure(_):
                // Try next injector
                self?.attemptInjection(text: text, injectorIndex: injectorIndex + 1, completion: completion)
            }
        }
    }
    
    /// Get the current application context
    public static func getCurrentApplicationContext() -> ApplicationContext {
        let workspace = NSWorkspace.shared
        let frontmostApp = workspace.frontmostApplication
        
        return ApplicationContext(
            bundleIdentifier: frontmostApp?.bundleIdentifier,
            name: frontmostApp?.localizedName ?? "Unknown",
            isRunning: frontmostApp != nil
        )
    }
    
    /// Check if accessibility permissions are enabled
    public static func checkAccessibilityPermissions() -> Bool {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options)
        }
        return trusted
    }
}