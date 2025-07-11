//
//  WindowController.swift
//  VoiceType
//
//  Manages window state and provides a bridge between AppKit and SwiftUI
//

import SwiftUI
import AppKit

/// Singleton controller for managing app windows
class WindowController: ObservableObject {
    static let shared = WindowController()
    
    @Published var shouldOpenSettings = false
    
    private init() {}
    
    /// Request to open the settings window
    func openSettings() {
        shouldOpenSettings = true
        
        // Activate the app and bring window to front
        DispatchQueue.main.async {
            // First activate the app
            NSApplication.shared.activate(ignoringOtherApps: true)
            
            // Find and activate the settings window
            for window in NSApp.windows {
                if window.title == "Settings" {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                    window.level = .floating // Temporarily make it floating
                    
                    // Reset level after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        window.level = .normal
                    }
                    break
                }
            }
        }
    }
    
    /// Called after settings window is opened
    func settingsDidOpen() {
        shouldOpenSettings = false
    }
}