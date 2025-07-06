//
//  AppDelegate.swift
//  VoiceType
//
//  Handles app lifecycle events and background tasks
//

import Cocoa
import SwiftUI
import ServiceManagement

/// AppDelegate for handling macOS app lifecycle events
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    private var lifecycleManager: AppLifecycleManager?
    private var statusItem: NSStatusItem?
    
    // MARK: - NSApplicationDelegate
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure app to be menu bar only (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Additional setup after app launch
        setupBackgroundTasks()
        setupNotificationHandlers()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up before termination
        lifecycleManager?.handleAppTermination()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        // App became active (foreground)
        lifecycleManager?.handleEnterForeground()
    }
    
    func applicationDidResignActive(_ notification: Notification) {
        // App resigned active (background)
        lifecycleManager?.handleEnterBackground()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when windows are closed (menu bar app)
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Handle dock icon click
        if !flag {
            // Show settings window
            if #available(macOS 13.0, *) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } else {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }
        return true
    }
    
    // MARK: - Background Tasks
    
    private func setupBackgroundTasks() {
        // Schedule periodic tasks using Timer
        schedulePeriodicTasks()
        
        // Set up URLSession for background downloads
        setupBackgroundURLSession()
    }
    
    private func schedulePeriodicTasks() {
        // Schedule maintenance every 24 hours
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            Task {
                await self.performMaintenance()
            }
        }
        
        // Check for pending model downloads every 5 minutes
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            Task {
                await self.checkPendingDownloads()
            }
        }
    }
    
    private func setupBackgroundURLSession() {
        // Configure URLSession for background downloads
        let config = URLSessionConfiguration.background(withIdentifier: "com.voicetype.modeldownload")
        config.isDiscretionary = true
        config.sessionSendsLaunchEvents = true
        
        // This will be used by ModelDownloader for background downloads
    }
    
    private func checkPendingDownloads() async {
        // Check for pending model downloads
        // This would be implemented with ModelManager
    }
    
    private func performMaintenance() async {
        // Clean up cache
        let fileManager = FileManager.default
        try? fileManager.cleanupCache(olderThan: 7)
        
        // Clean up partial downloads
        try? fileManager.cleanupPartialDownloads()
        
        // Other maintenance tasks
    }
    
    // MARK: - Notification Handlers
    
    private func setupNotificationHandlers() {
        // Listen for system events
        let notificationCenter = NSWorkspace.shared.notificationCenter
        
        // System sleep
        notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        // System wake
        notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Screen lock
        notificationCenter.addObserver(
            self,
            selector: #selector(screenDidLock),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        
        // Screen unlock
        notificationCenter.addObserver(
            self,
            selector: #selector(screenDidUnlock),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
    }
    
    @MainActor @objc private func systemWillSleep(_ notification: Notification) {
        // Handle system sleep
        lifecycleManager?.handleEnterBackground()
    }
    
    @MainActor @objc private func systemDidWake(_ notification: Notification) {
        // Handle system wake
        lifecycleManager?.handleEnterForeground()
    }
    
    @MainActor @objc private func screenDidLock(_ notification: Notification) {
        // Handle screen lock - pause recording if active
    }
    
    @MainActor @objc private func screenDidUnlock(_ notification: Notification) {
        // Handle screen unlock
    }
    
    // MARK: - Login Item Management
    
    func setLaunchAtLogin(_ enabled: Bool) {
        // Use SMAppService for modern login item management
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to update login item: \(error)")
            }
        } else {
            // Fallback for older macOS versions
            setLegacyLoginItem(enabled)
        }
    }
    
    private func setLegacyLoginItem(_ enabled: Bool) {
        // Legacy login item management for macOS < 13.0
        // Using Launch Services for older systems
        let bundleURL = Bundle.main.bundleURL
        
        if enabled {
            // Add to login items using AppleScript
            let script = """
            tell application "System Events"
                make login item at end with properties {path:"\(bundleURL.path)", hidden:false}
            end tell
            """
            
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if let error = error {
                    print("Failed to add login item: \(error)")
                }
            }
        } else {
            // Remove from login items using AppleScript
            let script = """
            tell application "System Events"
                delete login item "VoiceType"
            end tell
            """
            
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                scriptObject.executeAndReturnError(&error)
                if let error = error {
                    print("Failed to remove login item: \(error)")
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    func setLifecycleManager(_ manager: AppLifecycleManager) {
        self.lifecycleManager = manager
    }
}

