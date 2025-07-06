import SwiftUI

/// Settings window scene for macOS
struct SettingsScene: Scene {
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

/// Extension to open settings programmatically
extension NSApplication {
    @objc func showSettingsWindow() {
        // Try to bring existing settings window to front
        for window in windows {
            if window.identifier?.rawValue == "com.apple.SwiftUI.Settings" {
                window.makeKeyAndOrderFront(nil)
                return
            }
        }
        
        // If no settings window exists, send the showPreferencesWindow action
        if #available(macOS 13.0, *) {
            NSApp.sendAction(#selector(NSApplication.showSettingsWindow), to: nil, from: nil)
        } else {
            NSApp.sendAction(#selector(NSApplication.showPreferencesWindow), to: nil, from: nil)
        }
    }
}

/// Settings toolbar item for easy access
struct SettingsToolbarItem: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem {
            Button(action: {
                NSApp.showSettingsWindow()
            }) {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

/// Menu bar command for settings
struct SettingsCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                NSApp.showSettingsWindow()
            }
            .keyboardShortcut(",", modifiers: .command)
        }
    }
}