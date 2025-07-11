import Foundation
import AppKit
import VoiceTypeCore

/// Manages multiple text injection methods with automatic fallback
public class TextInjectorManager: TextInjector {
    public var methodName: String { "Manager" }
    private let injectors: [TextInjector]
    private let queue = DispatchQueue(label: "com.voicetype.textinjector", qos: .userInteractive)

    public init(injectors: [TextInjector]) {
        self.injectors = injectors
    }

    /// Inject text using the most appropriate method, with automatic fallback
    public func inject(text: String, completion: @escaping (Result<Void, TextInjectionError>) -> Void) {
        print("[TextInjectorManager] Starting injection process with \(injectors.count) available injectors")
        
        // Check if Chrome is the frontmost application
        let workspace = NSWorkspace.shared
        let frontmostApp = workspace.frontmostApplication
        let bundleId = frontmostApp?.bundleIdentifier ?? ""
        let appName = frontmostApp?.localizedName ?? "Unknown"
        
        // Reorder injectors for Chrome to prioritize clipboard methods
        let effectiveInjectors: [TextInjector]
        if bundleId == "com.google.Chrome" {
            print("[TextInjectorManager] Chrome detected - reordering injectors to prioritize clipboard methods")
            
            // For Chrome, prioritize clipboard methods
            var chromeInjectors: [TextInjector] = []
            var otherInjectors: [TextInjector] = []
            
            for injector in injectors {
                if injector.methodName == "SmartClipboard" || injector.methodName == "Clipboard" {
                    chromeInjectors.append(injector)
                } else {
                    otherInjectors.append(injector)
                }
            }
            
            // Put clipboard methods first for Chrome
            effectiveInjectors = chromeInjectors + otherInjectors
        } else {
            effectiveInjectors = injectors
        }
        
        print("[TextInjectorManager] Target app: \(appName) (\(bundleId))")
        print("[TextInjectorManager] Effective injectors: \(effectiveInjectors.map { $0.methodName }.joined(separator: ", "))")
        
        queue.async { [weak self] in
            guard let self = self else {
                print("[TextInjectorManager] ERROR: Manager deallocated")
                completion(.failure(.injectionFailed(reason: "Manager deallocated")))
                return
            }

            self.attemptInjection(text: text, injectorIndex: 0, injectors: effectiveInjectors) { result in
                if result.success {
                    completion(.success(()))
                } else {
                    completion(.failure(result.error ?? .injectionFailed(reason: "Unknown error")))
                }
            }
        }
    }

    private func attemptInjection(text: String, injectorIndex: Int, injectors: [TextInjector], completion: @escaping (InjectionResult) -> Void) {
        guard injectorIndex < injectors.count else {
            print("[TextInjectorManager] ERROR: All injection methods failed")
            completion(InjectionResult(
                success: false,
                method: "None",
                error: .injectionFailed(reason: "All injection methods failed")
            ))
            return
        }

        let injector = injectors[injectorIndex]
        print("[TextInjectorManager] Attempting injection method \(injectorIndex + 1)/\(injectors.count): \(injector.methodName)")

        // Check compatibility first
        if !injector.isCompatibleWithCurrentContext() {
            print("[TextInjectorManager] \(injector.methodName) is not compatible with current context")
            // Try next injector
            attemptInjection(text: text, injectorIndex: injectorIndex + 1, injectors: injectors, completion: completion)
            return
        }

        print("[TextInjectorManager] \(injector.methodName) is compatible, attempting injection...")
        
        // Attempt injection
        injector.inject(text: text) { [weak self] result in
            switch result {
            case .success:
                print("[TextInjectorManager] SUCCESS: \(injector.methodName) injection succeeded")
                completion(InjectionResult(
                    success: true,
                    method: injector.methodName,
                    fallbackUsed: injectorIndex > 0
                ))
            case .failure(let error):
                print("[TextInjectorManager] FAILED: \(injector.methodName) injection failed with error: \(error)")
                // Try next injector
                self?.attemptInjection(text: text, injectorIndex: injectorIndex + 1, injectors: injectors, completion: completion)
            }
        }
    }

    /// Get the current application context
    public static func getCurrentApplicationContext() -> ApplicationContext {
        let workspace = NSWorkspace.shared
        let frontmostApp = workspace.frontmostApplication

        let context = ApplicationContext(
            bundleIdentifier: frontmostApp?.bundleIdentifier,
            name: frontmostApp?.localizedName ?? "Unknown",
            isRunning: frontmostApp != nil
        )
        
        print("[TextInjectorManager] Current application context: \(context.name) (bundle: \(context.bundleIdentifier ?? "nil"))")
        
        return context
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
    
    /// Check if compatible with current context - at least one injector should be compatible
    public func isCompatibleWithCurrentContext() -> Bool {
        for injector in injectors {
            if injector.isCompatibleWithCurrentContext() {
                return true
            }
        }
        return false
    }
}
