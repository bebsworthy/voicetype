# VoiceType Settings Module

This module provides a comprehensive settings interface for the VoiceType application, following macOS design patterns and SwiftUI best practices.

## Components

### Main Views

- **SettingsView.swift**: The main settings window with tabbed navigation
- **SettingsScene.swift**: SwiftUI scene integration for the settings window

### Setting Components

- **ModelSelectionView.swift**: AI model selection with download progress tracking
- **HotkeyField.swift**: Custom hotkey capture and display field
- **LanguagePickerView.swift**: Language selection with search and regional grouping
- **AudioDevicePickerView.swift**: Audio input device selection with level monitoring
- **PermissionStatusSection.swift**: Permission status display and management

### Management

- **SettingsManager.swift**: Centralized settings persistence using UserDefaults and @AppStorage

## Features

### General Settings
- Language selection (30+ languages)
- Global hotkey configuration
- Launch at login
- Menu bar icon visibility
- Recording overlay toggle
- Feedback sounds

### Model Management
- Model selection (Fast/Balanced/Accurate)
- Download progress tracking
- Storage usage display
- Inline model downloads

### Permissions
- Microphone permission status
- Accessibility permission status
- Quick access to system preferences
- Real-time status updates

### Audio Settings
- Input device selection
- Real-time level monitoring
- Noise suppression
- Automatic gain control
- Silence threshold
- Recording duration limits

### Advanced Settings
- Processing thread configuration
- GPU acceleration toggle
- Low power mode
- Debug logging
- Performance metrics
- Settings reset

## Usage

### In Your App

```swift
@main
struct VoiceTypeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        // Add settings scene
        Settings {
            SettingsView()
        }
    }
}
```

### Opening Settings Programmatically

```swift
// Open settings window
NSApp.showSettingsWindow()

// Or use the keyboard shortcut: Cmd+,
```

### Accessing Settings Values

```swift
// Use the shared SettingsManager instance
let settingsManager = SettingsManager.shared

// Read settings
let language = settingsManager.selectedLanguage
let model = settingsManager.selectedModel

// Settings are automatically persisted when changed
settingsManager.enableNoiseSuppression = false
```

### Custom Hotkey Integration

```swift
// The hotkey is automatically registered when set
// Listen for the notification to trigger recording
NotificationCenter.default.addObserver(
    forName: .startVoiceRecording,
    object: nil,
    queue: .main
) { _ in
    // Start voice recording
}
```

## Design Principles

1. **Native macOS Feel**: Uses standard macOS preferences window design
2. **Real-time Updates**: All changes are applied immediately
3. **Visual Feedback**: Progress indicators, status badges, and hover effects
4. **Accessibility**: Full keyboard navigation and VoiceOver support
5. **Error Handling**: Graceful handling of permission denials and download failures

## Customization

### Adding New Settings

1. Add the property to `SettingsManager.swift`:
```swift
@AppStorage("myNewSetting") var myNewSetting: Bool = false
```

2. Add UI in the appropriate settings tab:
```swift
Toggle("My New Setting", isOn: $settingsManager.myNewSetting)
```

### Adding New Tabs

1. Add the tab case to `SettingsTab` enum in `SettingsView.swift`
2. Add the corresponding view in the switch statement
3. Create the new settings view

## Testing

The module includes preview providers for all components:

```swift
// Preview individual components
SettingsView_Previews.previews

// Test with mock data
let mockManager = PermissionManager()
PermissionStatusSection(permissionManager: mockManager)
```

## Requirements

- macOS 12.0+
- SwiftUI
- AVFoundation (for audio device management)
- Carbon framework (for hotkey support)