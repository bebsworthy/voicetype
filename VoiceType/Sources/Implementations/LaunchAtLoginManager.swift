//
//  LaunchAtLoginManager.swift
//  VoiceType
//
//  Manages the app's launch at login functionality
//

import Foundation
import ServiceManagement
import SwiftUI

/// Manages launch at login functionality using the modern SMAppService API
@MainActor
public class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()
    
    @AppStorage("launchAtLogin") private var storedLaunchAtLogin = false
    
    /// Whether the app is set to launch at login
    public var isEnabled: Bool {
        get {
            // Get the actual status from the system
            SMAppService.mainApp.status == .enabled
        }
        set {
            // Update the system setting
            do {
                if newValue {
                    if SMAppService.mainApp.status == .enabled {
                        // Already enabled, nothing to do
                        return
                    }
                    try SMAppService.mainApp.register()
                } else {
                    if SMAppService.mainApp.status == .notRegistered {
                        // Already disabled, nothing to do
                        return
                    }
                    try SMAppService.mainApp.unregister()
                }
                
                // Update stored value to match
                storedLaunchAtLogin = newValue
            } catch {
                print("Failed to update launch at login: \(error)")
            }
        }
    }
    
    /// Binding for SwiftUI toggle
    public var binding: Binding<Bool> {
        Binding(
            get: { self.isEnabled },
            set: { self.isEnabled = $0 }
        )
    }
    
    private init() {
        // Sync stored value with actual system state on init
        syncStoredValue()
    }
    
    /// Syncs the stored AppStorage value with the actual system state
    private func syncStoredValue() {
        storedLaunchAtLogin = (SMAppService.mainApp.status == .enabled)
    }
}