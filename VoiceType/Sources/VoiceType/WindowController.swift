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
        
        // Also activate the app
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    /// Called after settings window is opened
    func settingsDidOpen() {
        shouldOpenSettings = false
    }
}