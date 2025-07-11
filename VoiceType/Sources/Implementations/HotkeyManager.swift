import Foundation
import AppKit
import Combine
import os

/// Manages global hotkeys for the VoiceType application
///
/// This manager handles:
/// - Global hotkey registration using NSEvent monitoring
/// - Key combination parsing and validation
/// - Hotkey conflict detection
/// - Dynamic hotkey updates
/// - Proper cleanup on deregistration
///
/// **Usage Example:**
/// ```swift
/// let hotkeyManager = HotkeyManager()
/// 
/// // Register a hotkey
/// hotkeyManager.registerHotkey(
///     identifier: "toggleRecording",
///     keyCombo: "cmd+shift+v",
///     action: { print("Toggle recording") }
/// )
/// 
/// // Update a hotkey
/// hotkeyManager.updateHotkey(identifier: "toggleRecording", newKeyCombo: "ctrl+space")
/// 
/// // Unregister a hotkey
/// hotkeyManager.unregisterHotkey(identifier: "toggleRecording")
/// ```
public class HotkeyManager: ObservableObject {
    // MARK: - Published Properties

    /// Currently registered hotkeys
    @Published public private(set) var registeredHotkeys: [String: RegisteredHotkey] = [:]

    /// Whether the hotkey system is active
    @Published public private(set) var isActive: Bool = false

    /// Last error that occurred
    @Published public private(set) var lastError: HotkeyError?

    // MARK: - Private Properties

    private var eventMonitor: Any?
    private var hotkeys: [String: Hotkey] = [:]
    private let queue = DispatchQueue(label: "com.voicetype.hotkeymanager", qos: .userInteractive)

    // MARK: - Initialization

    public init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// Registers a global hotkey
    /// - Parameters:
    ///   - identifier: Unique identifier for the hotkey
    ///   - keyCombo: Key combination string (e.g., "cmd+shift+v")
    ///   - action: Closure to execute when hotkey is pressed
    /// - Throws: HotkeyError if registration fails
    @MainActor
    public func registerHotkey(identifier: String, keyCombo: String, action: @escaping () -> Void) throws {
        // Parse the key combination first
        guard let parsedHotkey = parseKeyCombo(keyCombo) else {
            throw HotkeyError.invalidKeyCombo(keyCombo)
        }

        // No restrictions - allow any key with or without modifiers
        // Users should be able to use whatever key they prefer

        // Check for conflicts excluding this identifier (in case of update)
        if let conflict = checkForConflict(parsedHotkey, excludingIdentifier: identifier) {
            throw HotkeyError.conflictingHotkey(identifier: conflict.identifier, keyCombo: keyCombo)
        }

        // Create hotkey
        let hotkey = Hotkey(
            identifier: identifier,
            keyCode: parsedHotkey.keyCode,
            modifiers: parsedHotkey.modifiers,
            action: action
        )

        // Register
        queue.sync {
            hotkeys[identifier] = hotkey
        }

        // Update published state
        registeredHotkeys[identifier] = RegisteredHotkey(
            identifier: identifier,
            keyCombo: keyCombo,
            keyCode: parsedHotkey.keyCode,
            modifiers: parsedHotkey.modifiers
        )

        lastError = nil
    }

    /// Updates an existing hotkey
    /// - Parameters:
    ///   - identifier: Identifier of the hotkey to update
    ///   - newKeyCombo: New key combination string
    /// - Throws: HotkeyError if update fails
    @MainActor
    public func updateHotkey(identifier: String, newKeyCombo: String) throws {
        guard let existingHotkey = hotkeys[identifier] else {
            throw HotkeyError.hotkeyNotFound(identifier)
        }

        // Parse new combination
        guard let parsedHotkey = parseKeyCombo(newKeyCombo) else {
            throw HotkeyError.invalidKeyCombo(newKeyCombo)
        }

        // Check for conflicts
        if let conflict = checkForConflict(parsedHotkey, excludingIdentifier: identifier) {
            throw HotkeyError.conflictingHotkey(identifier: conflict.identifier, keyCombo: newKeyCombo)
        }

        // Update hotkey
        let updatedHotkey = Hotkey(
            identifier: identifier,
            keyCode: parsedHotkey.keyCode,
            modifiers: parsedHotkey.modifiers,
            action: existingHotkey.action
        )

        queue.sync {
            hotkeys[identifier] = updatedHotkey
        }

        // Update published state
        registeredHotkeys[identifier] = RegisteredHotkey(
            identifier: identifier,
            keyCombo: newKeyCombo,
            keyCode: parsedHotkey.keyCode,
            modifiers: parsedHotkey.modifiers
        )

        lastError = nil
    }

    /// Unregisters a hotkey
    /// - Parameter identifier: Identifier of the hotkey to unregister
    @MainActor
    public func unregisterHotkey(identifier: String) {
        queue.sync {
            hotkeys.removeValue(forKey: identifier)
        }
        registeredHotkeys.removeValue(forKey: identifier)
    }

    /// Unregisters all hotkeys
    @MainActor
    public func unregisterAllHotkeys() {
        queue.sync {
            hotkeys.removeAll()
        }
        registeredHotkeys.removeAll()
    }
    
    /// Registers a push-to-talk hotkey that responds to both press and release
    /// - Parameters:
    ///   - identifier: Unique identifier for the hotkey
    ///   - keyCombo: Key combination string (e.g., "cmd+shift+v")
    ///   - onPress: Closure to execute when hotkey is pressed down
    ///   - onRelease: Closure to execute when hotkey is released
    /// - Throws: HotkeyError if registration fails
    @MainActor
    public func registerPushToTalkHotkey(identifier: String, keyCombo: String, onPress: @escaping () -> Void, onRelease: @escaping () -> Void) throws {
        // Parse the key combination first
        guard let parsedHotkey = parseKeyCombo(keyCombo) else {
            throw HotkeyError.invalidKeyCombo(keyCombo)
        }
        
        // No restrictions - allow any key with or without modifiers
        // Users should be able to use whatever key they prefer
        
        // Check for conflicts excluding this identifier (in case of update)
        if let conflict = checkForConflict(parsedHotkey, excludingIdentifier: identifier) {
            throw HotkeyError.conflictingHotkey(identifier: conflict.identifier, keyCombo: keyCombo)
        }
        
        // Create push-to-talk hotkey
        let hotkey = PushToTalkHotkey(
            identifier: identifier,
            keyCode: parsedHotkey.keyCode,
            modifiers: parsedHotkey.modifiers,
            onPress: onPress,
            onRelease: onRelease
        )
        
        // Register
        queue.sync {
            hotkeys[identifier] = hotkey
        }
        
        // Update published state
        registeredHotkeys[identifier] = RegisteredHotkey(
            identifier: identifier,
            keyCombo: keyCombo,
            keyCode: parsedHotkey.keyCode,
            modifiers: parsedHotkey.modifiers
        )
        
        lastError = nil
    }

    /// Validates a key combination string
    /// - Parameter keyCombo: Key combination string to validate
    /// - Returns: Validation result with error if invalid
    public func validateKeyCombo(_ keyCombo: String) -> ValidationResult {
        guard let parsed = parseKeyCombo(keyCombo) else {
            return ValidationResult(isValid: false, error: "Invalid key combination format")
        }

        // No restrictions - allow any key with or without modifiers
        // Users should be able to use whatever key they prefer

        if let conflict = checkForConflict(parsed, excludingIdentifier: nil) {
            return ValidationResult(isValid: false, error: "Conflicts with '\(conflict.identifier)'")
        }

        return ValidationResult(isValid: true, error: nil)
    }

    /// Gets a human-readable description of a hotkey
    /// - Parameter identifier: Hotkey identifier
    /// - Returns: Description string or nil if not found
    public func getHotkeyDescription(for identifier: String) -> String? {
        registeredHotkeys[identifier]?.displayString
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        guard eventMonitor == nil else { return }

        // Request accessibility permissions if needed
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if !trusted {
            DispatchQueue.main.async { [weak self] in
                self?.lastError = .accessibilityPermissionRequired
                self?.isActive = false
            }
            return
        }

        // Create global event monitor for keyDown, keyUp, and flagsChanged (for modifier keys alone)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        DispatchQueue.main.async { [weak self] in
            self?.isActive = true
        }
    }

    private func stopMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        DispatchQueue.main.async { [weak self] in
            self?.isActive = false
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = Int(event.keyCode)
        let modifiers = event.modifierFlags
        let eventType = event.type

        // Special handling for flagsChanged events (modifier keys pressed alone)
        if eventType == .flagsChanged {
            handleFlagsChangedEvent(event)
            return
        }

        queue.sync {
            // Find matching hotkey
            for (_, hotkey) in hotkeys {
                if hotkey.keyCode == keyCode && hotkey.matches(modifiers: modifiers) {
                    // Execute action on main queue based on event type
                    DispatchQueue.main.async {
                        switch eventType {
                        case .keyDown:
                            hotkey.handleKeyDown()
                        case .keyUp:
                            hotkey.handleKeyUp()
                        default:
                            break
                        }
                    }
                    break
                }
            }
        }
    }
    
    private func handleFlagsChangedEvent(_ event: NSEvent) {
        // Globe/Fn key has keyCode 63
        if event.keyCode == 63 {
            let isPressed = event.modifierFlags.contains(.function)
            
            queue.sync {
                // Find hotkeys registered for Globe key alone
                for (_, hotkey) in hotkeys {
                    if hotkey.keyCode == 63 && hotkey.modifiers.isEmpty {
                        // Execute action on main queue
                        DispatchQueue.main.async {
                            if isPressed {
                                hotkey.handleKeyDown()
                            } else {
                                hotkey.handleKeyUp()
                            }
                        }
                        break
                    }
                }
            }
        }
        // Could add support for other modifier keys alone here (Option, Control, etc.)
    }

    private func parseKeyCombo(_ combo: String) -> (keyCode: Int, modifiers: NSEvent.ModifierFlags)? {
        let trimmedCombo = combo.trimmingCharacters(in: .whitespaces)
        guard !trimmedCombo.isEmpty else { return nil }
        
        print("🔍 Parsing key combo: '\(trimmedCombo)'")

        // Check for invalid formats
        if trimmedCombo.hasPrefix("+") || trimmedCombo.hasSuffix("+") || trimmedCombo.contains("++") {
            return nil
        }

        let parts = trimmedCombo.lowercased().split(separator: "+").map { String($0).trimmingCharacters(in: .whitespaces) }
        guard !parts.isEmpty else { return nil }

        var modifiers: NSEvent.ModifierFlags = []
        var keyPart: String?
        let validModifiers = Set(["cmd", "command", "ctrl", "control", "opt", "option", "alt", "shift", "globe", "fn", "function"])
        
        // Special case: if there's only one part and it's a special key, treat it as the key, not a modifier
        if parts.count == 1 {
            let singlePart = parts[0]
            if ["globe", "fn", "microphone", "mic", "dictation"].contains(singlePart) {
                keyPart = singlePart
            } else {
                // Otherwise, process normally
                for part in parts {
                    switch part {
                    case "cmd", "command":
                        modifiers.insert(.command)
                    case "ctrl", "control":
                        modifiers.insert(.control)
                    case "opt", "option", "alt":
                        modifiers.insert(.option)
                    case "shift":
                        modifiers.insert(.shift)
                    default:
                        if keyPart == nil {
                            keyPart = part
                        } else {
                            return nil
                        }
                    }
                }
            }
        } else {
            // Multiple parts - process each part
            for part in parts {
                switch part {
                case "cmd", "command":
                    modifiers.insert(.command)
                case "ctrl", "control":
                    modifiers.insert(.control)
                case "opt", "option", "alt":
                    modifiers.insert(.option)
                case "shift":
                    modifiers.insert(.shift)
                case "globe", "fn":
                    modifiers.insert(.function)  // Globe/Fn key sets the function modifier
                case "function":
                    modifiers.insert(.function)
                default:
                    // This must be the key part
                    if keyPart == nil {
                        keyPart = part
                    } else {
                        // Multiple non-modifier parts - invalid
                        return nil
                    }
                }
            }
        }

        // Check if all parts except the key part are valid modifiers
        for part in parts {
            if part != keyPart && !validModifiers.contains(part) {
                // Invalid modifier found
                return nil
            }
        }

        guard let key = keyPart, let keyCode = keyCodeForString(key) else {
            print("🔴 Failed to get keyCode for key: '\(keyPart ?? "nil")'")
            return nil
        }

        let result = (keyCode, modifiers)
        print("✅ Parsed key combo: keyCode=\(keyCode), modifiers=\(modifiers), keyPart='\(key)'")
        return result
    }

    private func keyCodeForString(_ key: String) -> Int? {
        // Common key mappings
        let keyMap: [String: Int] = [
            // Letters
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
            "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 32, "u": 32,
            "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,

            // Numbers
            "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28,
            "9": 25, "0": 29,

            // Special keys
            "return": 36, "enter": 36,
            "tab": 48,
            "space": 49,
            "delete": 51, "backspace": 51,
            "escape": 53, "esc": 53,
            "left": 123, "right": 124, "down": 125, "up": 126,

            // Function keys
            "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
            "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
            "f13": 105, "f14": 107, "f15": 113, "f16": 106, "f17": 64, "f18": 79, "f19": 80, "f20": 90,
            
            // Special keys
            "globe": 63, "fn": 63, // Globe/Fn key
            "microphone": 79, "mic": 79, "dictation": 79, // Microphone key (mapped to F18)
            
            // Media keys (these may vary by keyboard)
            "volumeup": 72, "volumedown": 73, "mute": 74,
            "play": 16, "pause": 16, "playpause": 16,
            "next": 17, "previous": 18, "forward": 17, "rewind": 18,

            // Punctuation
            ",": 43, ".": 47, "/": 44, ";": 41, "'": 39, "[": 33, "]": 30,
            "\\": 42, "-": 27, "=": 24, "`": 50
        ]

        return keyMap[key.lowercased()]
    }

    private func checkForConflict(_ hotkey: (keyCode: Int, modifiers: NSEvent.ModifierFlags), excludingIdentifier: String?) -> RegisteredHotkey? {
        for (identifier, registered) in registeredHotkeys {
            if identifier == excludingIdentifier { continue }

            if registered.keyCode == hotkey.keyCode && registered.modifiers == hotkey.modifiers {
                return registered
            }
        }
        return nil
    }
}

// MARK: - Supporting Types

/// Represents a registered hotkey
public struct RegisteredHotkey {
    public let identifier: String
    public let keyCombo: String
    public let keyCode: Int
    public let modifiers: NSEvent.ModifierFlags

    /// Human-readable display string for the hotkey
    public var displayString: String {
        var parts: [String] = []

        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.function) { parts.append("fn") }

        if let keyString = keyStringForCode(keyCode) {
            parts.append(keyString.uppercased())
        }

        return parts.joined()
    }

    private func keyStringForCode(_ code: Int) -> String? {
        // Reverse mapping for display
        let codeMap: [Int: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 31: "O", 32: "U",
            34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
            98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]

        return codeMap[code]
    }
}

/// Internal hotkey representation
private class Hotkey {
    let identifier: String
    let keyCode: Int
    let modifiers: NSEvent.ModifierFlags
    let action: () -> Void

    init(identifier: String, keyCode: Int, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        self.identifier = identifier
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
    }

    func matches(modifiers: NSEvent.ModifierFlags) -> Bool {
        // Check if all required modifiers are present
        let requiredModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift, .function]
        let relevantEventModifiers = modifiers.intersection(requiredModifiers)
        let relevantHotkeyModifiers = self.modifiers.intersection(requiredModifiers)

        return relevantEventModifiers == relevantHotkeyModifiers
    }
    
    func handleKeyDown() {
        action()
    }
    
    func handleKeyUp() {
        // Default hotkey doesn't do anything on key up
    }
}

/// Push-to-talk hotkey that responds to both press and release
private class PushToTalkHotkey: Hotkey {
    let onPress: () -> Void
    let onRelease: () -> Void
    private var isPressed = false
    
    init(identifier: String, keyCode: Int, modifiers: NSEvent.ModifierFlags, onPress: @escaping () -> Void, onRelease: @escaping () -> Void) {
        self.onPress = onPress
        self.onRelease = onRelease
        super.init(identifier: identifier, keyCode: keyCode, modifiers: modifiers, action: onPress)
    }
    
    override func handleKeyDown() {
        if !isPressed {
            isPressed = true
            onPress()
        }
    }
    
    override func handleKeyUp() {
        if isPressed {
            isPressed = false
            onRelease()
        }
    }
}

/// Validation result for key combinations
public struct ValidationResult {
    public let isValid: Bool
    public let error: String?
}

/// Errors that can occur during hotkey operations
public enum HotkeyError: LocalizedError {
    case invalidKeyCombo(String)
    case conflictingHotkey(identifier: String, keyCombo: String)
    case hotkeyNotFound(String)
    case accessibilityPermissionRequired
    case systemError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidKeyCombo(let combo):
            return "Invalid key combination: '\(combo)'. Use a single key (e.g., 'space', 'globe') or combine modifiers with a key (e.g., 'cmd+shift+v', 'globe+p')"
        case .conflictingHotkey(let identifier, let combo):
            return "Key combination '\(combo)' conflicts with existing hotkey '\(identifier)'"
        case .hotkeyNotFound(let identifier):
            return "Hotkey '\(identifier)' not found"
        case .accessibilityPermissionRequired:
            return "Accessibility permission required for global hotkeys"
        case .systemError(let message):
            return "System error: \(message)"
        }
    }
}

// MARK: - Hotkey Presets

extension HotkeyManager {
    /// Common hotkey presets for VoiceType
    public enum HotkeyPreset {
        case toggleRecording
        case cancelRecording
        case insertLastTranscription
        case showOverlay
        case togglePauseResume

        public var defaultKeyCombo: String {
            switch self {
            case .toggleRecording:
                return "cmd+shift+v"
            case .cancelRecording:
                return "escape"
            case .insertLastTranscription:
                return "cmd+shift+i"
            case .showOverlay:
                return "cmd+shift+o"
            case .togglePauseResume:
                return "cmd+shift+p"
            }
        }

        public var identifier: String {
            switch self {
            case .toggleRecording:
                return "voicetype.toggle_recording"
            case .cancelRecording:
                return "voicetype.cancel_recording"
            case .insertLastTranscription:
                return "voicetype.insert_last"
            case .showOverlay:
                return "voicetype.show_overlay"
            case .togglePauseResume:
                return "voicetype.toggle_pause"
            }
        }

        public var description: String {
            switch self {
            case .toggleRecording:
                return "Toggle voice recording"
            case .cancelRecording:
                return "Cancel current recording"
            case .insertLastTranscription:
                return "Insert last transcription"
            case .showOverlay:
                return "Show/hide overlay"
            case .togglePauseResume:
                return "Pause/resume recording"
            }
        }
    }

    /// Registers a preset hotkey
    @MainActor
    public func registerPreset(_ preset: HotkeyPreset, action: @escaping () -> Void) throws {
        try registerHotkey(
            identifier: preset.identifier,
            keyCombo: preset.defaultKeyCombo,
            action: action
        )
    }
}
