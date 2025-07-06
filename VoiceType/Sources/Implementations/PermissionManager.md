# PermissionManager Implementation

## Overview

The `PermissionManager` class is responsible for managing all application permissions required by VoiceType, including microphone access and accessibility permissions. It provides a centralized way to request, monitor, and guide users through the permission setup process.

## Features

- **Microphone Permission Management**: Request and monitor microphone access using AVFoundation
- **Accessibility Permission Detection**: Check and guide users to enable AXIsProcessTrusted
- **State Tracking**: Observable properties for reactive UI updates
- **User Guidance**: Generate clear instructions for manual permission setup
- **Persistence**: Save permission states across app launches
- **Automatic Monitoring**: Periodically check permission status for changes

## Usage

### Basic Setup

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var permissionManager = PermissionManager()
    
    var body: some View {
        VStack {
            if permissionManager.allPermissionsGranted {
                Text("Ready to use VoiceType!")
            } else {
                PermissionStatusView(permissionManager: permissionManager)
            }
        }
    }
}
```

### Requesting Microphone Permission

```swift
func setupMicrophone() async {
    let granted = await permissionManager.requestMicrophonePermission()
    
    if granted {
        // Start audio recording
    } else {
        // Show permission denied UI
        permissionManager.showPermissionDeniedAlert(for: .microphone)
    }
}
```

### Checking Accessibility Permission

```swift
func checkAccessibility() {
    if !permissionManager.hasAccessibilityPermission() {
        permissionManager.showAccessibilityPermissionGuide()
    }
}
```

### Monitoring Permission Changes

The `PermissionManager` automatically monitors permission changes every 5 seconds. You can also manually refresh:

```swift
permissionManager.refreshPermissionStates()
```

## Permission States

Each permission can be in one of three states:

- **`.notRequested`**: Permission has not been requested yet
- **`.denied`**: User denied the permission
- **`.granted`**: Permission is granted and active

## UI Components

The implementation includes several SwiftUI views for permission management:

### PermissionStatusView

A complete permission status display with action buttons:

```swift
PermissionStatusView(permissionManager: permissionManager)
```

### PermissionIndicatorView

A compact indicator for menu bar usage:

```swift
PermissionIndicatorView(permissionManager: permissionManager)
```

### PermissionOnboardingView

A full onboarding flow for first-time setup:

```swift
PermissionOnboardingView(
    permissionManager: permissionManager,
    isPresented: $showOnboarding
)
```

## Testing

The implementation includes a `MockPermissionManager` for testing:

```swift
let mockManager = MockPermissionManager()
mockManager.setMockMicrophonePermission(.granted)
mockManager.setMockAccessibilityPermission(.denied)

// Use mockManager in tests without triggering real permission requests
```

## Privacy Considerations

- No permission status is transmitted over the network
- Permission states are stored locally in UserDefaults
- The implementation respects user choices and provides clear guidance
- All permission requests include clear explanations of why they're needed

## Error Handling

The PermissionManager handles various error scenarios:

- Permission previously denied: Shows guidance to open System Preferences
- System audio unavailable: Provides clear error messaging
- Accessibility not trusted: Shows step-by-step setup instructions

## Integration with VoiceTypeCoordinator

The PermissionManager should be integrated with the main app coordinator:

```swift
class VoiceTypeCoordinator: ObservableObject {
    @Published private(set) var permissionManager = PermissionManager()
    
    func startDictation() async {
        guard permissionManager.microphonePermission == .granted else {
            await permissionManager.requestMicrophonePermission()
            return
        }
        
        guard permissionManager.accessibilityPermission == .granted else {
            permissionManager.showAccessibilityPermissionGuide()
            return
        }
        
        // Proceed with dictation...
    }
}
```

## System Requirements

- macOS 12.0+ (for modern AVFoundation APIs)
- Accessibility framework for AXIsProcessTrusted
- AppKit for NSAlert and NSWorkspace

## Future Enhancements

Potential improvements for future versions:

1. **Permission Analytics**: Local-only analytics on permission grant rates
2. **Alternative Workflows**: Clipboard-only mode when accessibility is denied
3. **Permission Preflighting**: Check permissions before critical operations
4. **Deep Linking**: Direct links to specific System Preferences panes
5. **Notification Permissions**: For transcription complete notifications

## Contributing

When modifying the PermissionManager:

1. Maintain backward compatibility with existing permission states
2. Update both the implementation and mock for testing
3. Ensure all UI components reflect new permission types
4. Add comprehensive tests for new functionality
5. Update this documentation with new features