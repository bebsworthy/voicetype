import SwiftUI
import AppKit
import VoiceTypeCore
import VoiceTypeImplementations

/// A view that allows users to record and set custom hotkey combinations
public struct HotkeyRecorderView: View {
    @Binding var hotkey: String
    @State private var isRecording = false
    @State private var recordedKeys: String = ""
    @State private var errorMessage: String?
    
    var onHotkeyChanged: ((String) -> Void)?
    
    public init(hotkey: Binding<String>, onHotkeyChanged: ((String) -> Void)? = nil) {
        self._hotkey = hotkey
        self.onHotkeyChanged = onHotkeyChanged
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if isRecording {
                    Text("Press keys...")
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                        .cornerRadius(6)
                } else {
                    Text(formatHotkey(hotkey))
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(6)
                        .onTapGesture {
                            startRecording()
                        }
                }
                
                if isRecording {
                    Button("Cancel") {
                        stopRecording(save: false)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .background(KeyEventHandler(isRecording: $isRecording, onKeyPress: handleKeyPress))
    }
    
    private func formatHotkey(_ hotkey: String) -> String {
        // Special formatting for Globe key
        if hotkey.lowercased() == "globe" {
            return "🌐"
        }
        
        // Format other keys with nice symbols
        let formatted = hotkey
            .replacingOccurrences(of: "cmd", with: "⌘", options: .caseInsensitive)
            .replacingOccurrences(of: "ctrl", with: "⌃", options: .caseInsensitive)
            .replacingOccurrences(of: "option", with: "⌥", options: .caseInsensitive)
            .replacingOccurrences(of: "shift", with: "⇧", options: .caseInsensitive)
            .replacingOccurrences(of: "microphone", with: "🎙", options: .caseInsensitive)
            .replacingOccurrences(of: "mic", with: "🎙", options: .caseInsensitive)
            .replacingOccurrences(of: "+", with: " + ")
        
        return formatted.uppercased()
    }
    
    private func startRecording() {
        isRecording = true
        recordedKeys = ""
        errorMessage = nil
    }
    
    private func stopRecording(save: Bool) {
        isRecording = false
        
        if save && !recordedKeys.isEmpty {
            // Validate the hotkey
            if validateHotkey(recordedKeys) {
                hotkey = recordedKeys
                errorMessage = nil
                onHotkeyChanged?(recordedKeys)
            } else {
                errorMessage = "Invalid key combination. Use modifier keys (⌘, ⌥, ⌃, ⇧) with a regular key, or use Globe/Microphone key alone."
            }
        }
        
        recordedKeys = ""
    }
    
    private func handleKeyPress(event: NSEvent) {
        guard isRecording else { return }
        
        // Handle flagsChanged events for Globe key
        if event.type == .flagsChanged {
            // Globe/Fn key
            if event.keyCode == 63 {
                recordedKeys = "globe"
                
                // Auto-save after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                    if self.isRecording {
                        self.stopRecording(save: true)
                    }
                }
                return
            }
        }
        
        // Get modifier flags
        var modifiers: [String] = []
        let flags = event.modifierFlags
        
        if flags.contains(.command) { modifiers.append("cmd") }
        if flags.contains(.option) { modifiers.append("option") }
        if flags.contains(.control) { modifiers.append("ctrl") }
        if flags.contains(.shift) { modifiers.append("shift") }
        if flags.contains(.function) && event.keyCode != 63 { modifiers.append("fn") } // Don't add fn for Globe key alone
        
        // Get the key
        if event.type == .keyDown {
            if let characters = event.charactersIgnoringModifiers {
                let keyString = keyCodeToString(event.keyCode) ?? characters.lowercased()
                
                if (!modifiers.isEmpty && !keyString.isEmpty) || isSpecialKeyAllowedAlone(keyString) {
                    // Build the hotkey string
                    var hotkeyParts = modifiers
                    hotkeyParts.append(keyString)
                    recordedKeys = hotkeyParts.joined(separator: "+")
                    
                    // Auto-save after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                        if self.isRecording {
                            self.stopRecording(save: true)
                        }
                    }
                }
            }
        }
    }
    
    private func isSpecialKeyAllowedAlone(_ key: String) -> Bool {
        ["globe", "fn", "microphone", "mic", "dictation", "f18"].contains(key)
    }
    
    private func validateHotkey(_ hotkey: String) -> Bool {
        let parts = hotkey.split(separator: "+").map { String($0) }
        
        // Special keys allowed alone
        if parts.count == 1 && isSpecialKeyAllowedAlone(String(parts[0])) {
            return true
        }
        
        // Otherwise, must have at least one modifier and one key
        guard parts.count >= 2 else { return false }
        
        let modifiers = ["cmd", "ctrl", "option", "shift", "fn"]
        let hasModifier = parts.dropLast().contains { modifiers.contains($0) }
        let hasKey = !parts.last!.isEmpty
        
        return hasModifier && hasKey
    }
    
    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        switch keyCode {
        case 0: return "a"
        case 1: return "s"
        case 2: return "d"
        case 3: return "f"
        case 4: return "h"
        case 5: return "g"
        case 6: return "z"
        case 7: return "x"
        case 8: return "c"
        case 9: return "v"
        case 11: return "b"
        case 12: return "q"
        case 13: return "w"
        case 14: return "e"
        case 15: return "r"
        case 16: return "y"
        case 17: return "t"
        case 31: return "o"
        case 32: return "u"
        case 34: return "i"
        case 35: return "p"
        case 37: return "l"
        case 38: return "j"
        case 40: return "k"
        case 45: return "n"
        case 46: return "m"
        case 49: return "space"
        case 51: return "delete"
        case 53: return "escape"
        case 36: return "return"
        case 48: return "tab"
        case 63: return "globe"  // Globe/Fn key
        case 79: return "microphone"  // Microphone key (F18)
        case 123: return "left"
        case 124: return "right"
        case 125: return "down"
        case 126: return "up"
        default: return nil
        }
    }
}

/// NSViewRepresentable to handle key events
struct KeyEventHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onKeyPress: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyPress = onKeyPress
        view.isRecording = isRecording
        return view
    }
    
    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.isRecording = isRecording
        
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
    
    class KeyCaptureView: NSView {
        var onKeyPress: ((NSEvent) -> Void)?
        var isRecording = false
        
        override var acceptsFirstResponder: Bool {
            isRecording
        }
        
        override func keyDown(with event: NSEvent) {
            if isRecording {
                onKeyPress?(event)
            } else {
                super.keyDown(with: event)
            }
        }
        
        override func flagsChanged(with event: NSEvent) {
            if isRecording {
                onKeyPress?(event)
            } else {
                super.flagsChanged(with: event)
            }
        }
    }
}