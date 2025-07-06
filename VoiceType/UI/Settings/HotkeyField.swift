import SwiftUI
import Carbon

/// Custom text field for capturing and displaying hotkey combinations
struct HotkeyField: View {
    @Binding var hotkey: Hotkey?
    @State private var isRecording = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            // Display current hotkey or prompt
            Text(displayText)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isRecording ? .accentColor : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(backgroundColor)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(borderColor, lineWidth: 1)
                )
                .onTapGesture {
                    if !isRecording {
                        startRecording()
                    }
                }
            
            // Clear button
            if hotkey != nil && !isRecording {
                Button(action: clearHotkey) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            setupKeyboardMonitor()
        }
    }
    
    private var displayText: String {
        if isRecording {
            return "Press a key combination..."
        } else if let hotkey = hotkey {
            return hotkey.displayString
        } else {
            return "Click to set hotkey"
        }
    }
    
    private var backgroundColor: Color {
        if isRecording {
            return Color.accentColor.opacity(0.1)
        } else {
            return Color(NSColor.controlBackgroundColor)
        }
    }
    
    private var borderColor: Color {
        if isRecording {
            return Color.accentColor
        } else {
            return Color(NSColor.separatorColor)
        }
    }
    
    private func startRecording() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isRecording = true
            isFocused = true
        }
    }
    
    private func stopRecording() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isRecording = false
            isFocused = false
        }
    }
    
    private func clearHotkey() {
        hotkey = nil
    }
    
    private func setupKeyboardMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if isRecording {
                if let hotkey = Hotkey(from: event) {
                    self.hotkey = hotkey
                    stopRecording()
                    return nil // Consume the event
                }
            }
            return event
        }
    }
}

/// Represents a keyboard hotkey combination
struct Hotkey: Codable, Equatable {
    let keyCode: UInt16
    let modifierFlags: NSEvent.ModifierFlags
    
    init?(from event: NSEvent) {
        // Require at least one modifier key
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !flags.isEmpty else { return nil }
        
        self.keyCode = event.keyCode
        self.modifierFlags = flags
    }
    
    init(keyCode: UInt16, modifierFlags: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }
    
    var displayString: String {
        var parts: [String] = []
        
        // Add modifiers in standard order
        if modifierFlags.contains(.control) {
            parts.append("⌃")
        }
        if modifierFlags.contains(.option) {
            parts.append("⌥")
        }
        if modifierFlags.contains(.shift) {
            parts.append("⇧")
        }
        if modifierFlags.contains(.command) {
            parts.append("⌘")
        }
        
        // Add the key
        if let keyString = keyStringFromKeyCode(keyCode) {
            parts.append(keyString)
        } else {
            parts.append("Key \(keyCode)")
        }
        
        return parts.joined()
    }
    
    private func keyStringFromKeyCode(_ keyCode: UInt16) -> String? {
        // Common key mappings
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default: return nil
        }
    }
}

// MARK: - Codable Support

extension NSEvent.ModifierFlags: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(UInt.self)
        self.init(rawValue: rawValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

// MARK: - Global Hotkey Registration

class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var currentHotkey: Hotkey?
    private var action: (() -> Void)?
    
    func register(hotkey: Hotkey, action: @escaping () -> Void) {
        self.currentHotkey = hotkey
        self.action = action
        
        // Remove existing tap if any
        unregister()
        
        // Create event tap
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()
                return manager.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        guard let eventTap = eventTap else { return }
        
        // Create run loop source and add to current run loop
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }
    
    func unregister() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        
        eventTap = nil
        runLoopSource = nil
        currentHotkey = nil
        action = nil
    }
    
    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let currentHotkey = currentHotkey,
              let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passRetained(event)
        }
        
        // Check if this event matches our hotkey
        if nsEvent.keyCode == currentHotkey.keyCode &&
           nsEvent.modifierFlags.intersection([.command, .control, .option, .shift]) == currentHotkey.modifierFlags {
            // Execute action on main thread
            DispatchQueue.main.async {
                self.action?()
            }
            return nil // Consume the event
        }
        
        return Unmanaged.passRetained(event)
    }
}

// MARK: - Preview

struct HotkeyField_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Default state
            HotkeyField(hotkey: .constant(nil))
                .frame(width: 300)
            
            // With hotkey set
            HotkeyField(hotkey: .constant(
                Hotkey(keyCode: UInt16(kVK_ANSI_V), modifierFlags: [.control, .shift])
            ))
            .frame(width: 300)
        }
        .padding()
    }
}