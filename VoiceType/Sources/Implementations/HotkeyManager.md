# HotkeyManager Documentation

## Overview

The `HotkeyManager` is a modern, SwiftUI-compatible global hotkey system for macOS that handles keyboard shortcuts throughout the VoiceType application. It uses NSEvent monitoring instead of deprecated Carbon APIs, providing a clean and maintainable solution for macOS 12.0+.

## Features

- **Global Hotkey Registration**: Register system-wide keyboard shortcuts
- **Key Combination Parsing**: Supports standard formats like "cmd+shift+v"
- **Conflict Detection**: Automatically detects and prevents conflicting hotkeys
- **Dynamic Updates**: Change hotkeys at runtime without restart
- **SwiftUI Integration**: ObservableObject with @Published properties
- **Comprehensive Error Handling**: Clear error messages and recovery suggestions
- **Preset Support**: Built-in presets for common VoiceType actions

## Architecture

### Core Components

1. **HotkeyManager**: Main class that manages all hotkey operations
2. **RegisteredHotkey**: Public representation of a registered hotkey
3. **Hotkey**: Private internal representation with action callbacks
4. **HotkeyError**: Comprehensive error types for all failure cases
5. **HotkeyPreset**: Predefined hotkeys for common actions

### Design Decisions

- **NSEvent Monitoring**: Uses modern `NSEvent.addGlobalMonitorForEvents` instead of deprecated Carbon Event Manager
- **ObservableObject**: Integrates seamlessly with SwiftUI for reactive UI updates
- **Thread Safety**: Uses dispatch queue for thread-safe hotkey management
- **Permission Handling**: Checks for accessibility permissions and provides user guidance

## Usage Examples

### Basic Registration

```swift
let hotkeyManager = HotkeyManager()

// Register a simple hotkey
try hotkeyManager.registerHotkey(
    identifier: "my.hotkey",
    keyCombo: "cmd+shift+m",
    action: {
        print("Hotkey triggered!")
    }
)
```

### Using Presets

```swift
// Register a preset hotkey
try hotkeyManager.registerPreset(.toggleRecording) {
    // Toggle recording logic
}
```

### SwiftUI Integration

```swift
struct ContentView: View {
    @StateObject private var hotkeyManager = HotkeyManager()
    
    var body: some View {
        VStack {
            // Show registered hotkeys
            ForEach(Array(hotkeyManager.registeredHotkeys.values), id: \.identifier) { hotkey in
                Text("\(hotkey.identifier): \(hotkey.displayString)")
            }
            
            // Show status
            if hotkeyManager.isActive {
                Text("Hotkeys active").foregroundColor(.green)
            } else {
                Text("Hotkeys inactive").foregroundColor(.red)
            }
        }
    }
}
```

### Handling Conflicts

```swift
do {
    try hotkeyManager.registerHotkey(
        identifier: "new.hotkey",
        keyCombo: "cmd+shift+n",
        action: { }
    )
} catch let error as HotkeyError {
    switch error {
    case .conflictingHotkey(let existingId, _):
        // Handle conflict - maybe show dialog to user
        print("Conflicts with: \(existingId)")
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```

## Key Combination Format

The manager supports flexible key combination formats:

### Modifiers
- `cmd` or `command`: ⌘ Command key
- `ctrl` or `control`: ⌃ Control key
- `opt`, `option`, or `alt`: ⌥ Option key
- `shift`: ⇧ Shift key
- `fn` or `function`: Function key

### Keys
- Letters: `a-z`
- Numbers: `0-9`
- Function keys: `f1-f12`
- Special keys: `space`, `return`/`enter`, `escape`/`esc`, `tab`, `delete`/`backspace`
- Arrow keys: `up`, `down`, `left`, `right`

### Examples
- `cmd+shift+v`: Command + Shift + V
- `ctrl+opt+space`: Control + Option + Space
- `cmd+f1`: Command + F1
- `shift+escape`: Shift + Escape

## Error Handling

The manager provides specific error types for different scenarios:

```swift
enum HotkeyError: LocalizedError {
    case invalidKeyCombo(String)           // Invalid format
    case conflictingHotkey(identifier: String, keyCombo: String)  // Conflicts with existing
    case hotkeyNotFound(String)            // Hotkey doesn't exist
    case accessibilityPermissionRequired   // Needs accessibility permission
    case systemError(String)               // Other system errors
}
```

## Permissions

Global hotkeys require accessibility permissions on macOS. The manager:

1. Automatically checks for permissions
2. Sets `isActive` to false if permissions are missing
3. Provides `accessibilityPermissionRequired` error
4. Can guide users to System Preferences

Example permission handling:

```swift
hotkeyManager.$lastError
    .compactMap { $0 }
    .sink { error in
        if case .accessibilityPermissionRequired = error {
            // Show permission prompt to user
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
```

## Performance Considerations

- **Efficient Monitoring**: Uses single global event monitor for all hotkeys
- **Quick Lookup**: O(1) hotkey lookup using dictionary storage
- **Minimal Processing**: Only processes keyDown events
- **Thread Safety**: Dispatches actions to main queue to avoid blocking

## Testing

The implementation includes comprehensive unit tests covering:

- Key combination validation
- Registration and conflicts
- Updates and unregistration
- Preset functionality
- Edge cases and performance

## Integration with VoiceType

The HotkeyManager integrates with VoiceType's architecture:

1. **ConfigurationManager**: Stores user's hotkey preferences
2. **VoiceTypeCore**: Triggers recording actions
3. **UI Components**: Updates based on @Published properties
4. **PermissionManager**: Coordinates with accessibility permissions

## Best Practices

1. **Use Identifiers**: Use descriptive, namespaced identifiers (e.g., "voicetype.toggle_recording")
2. **Validate First**: Always validate user input before registration
3. **Handle Conflicts**: Provide clear UI for resolving conflicts
4. **Use Presets**: Leverage built-in presets for consistency
5. **Monitor Errors**: Subscribe to `lastError` for user feedback
6. **Clean Up**: Unregister hotkeys when no longer needed

## Limitations

- Requires macOS 12.0+ for modern NSEvent APIs
- Needs accessibility permissions for global monitoring
- Some key combinations may be reserved by the system
- Cannot override system-level shortcuts

## Future Enhancements

Potential improvements for future versions:

1. **Recording Mode**: Record key combinations from user input
2. **Import/Export**: Save and load hotkey configurations
3. **Profiles**: Multiple hotkey profiles for different contexts
4. **Visual Feedback**: Show overlay when hotkey is triggered
5. **Analytics**: Track hotkey usage for optimization