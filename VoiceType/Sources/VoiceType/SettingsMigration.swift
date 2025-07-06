//
//  SettingsMigration.swift
//  VoiceType
//
//  Handles migration of user settings between app versions
//

import Foundation

/// Manages settings migration between app versions
public struct SettingsMigration {
    
    // MARK: - Migration Functions
    
    /// Migrate settings from version 0 to version 1
    /// - Parameter defaults: UserDefaults instance to migrate
    public static func migrateV0ToV1(defaults: UserDefaults) {
        // Version 0 -> 1: Initial setup with default values
        
        // Migrate old keys to new keys
        if let oldHotkey = defaults.string(forKey: "hotkey") {
            defaults.set(oldHotkey, forKey: "globalHotkey")
            defaults.removeObject(forKey: "hotkey")
        }
        
        // Set default values for new settings
        if defaults.object(forKey: "maxRecordingDuration") == nil {
            defaults.set(5.0, forKey: "maxRecordingDuration")
        }
        
        if defaults.object(forKey: "autoStartAtLogin") == nil {
            defaults.set(false, forKey: "autoStartAtLogin")
        }
        
        if defaults.object(forKey: "showDockIcon") == nil {
            defaults.set(false, forKey: "showDockIcon")
        }
        
        if defaults.object(forKey: "transcriptionQuality") == nil {
            defaults.set("balanced", forKey: "transcriptionQuality")
        }
        
        if defaults.object(forKey: "enableSoundEffects") == nil {
            defaults.set(true, forKey: "enableSoundEffects")
        }
    }
    
    /// Migrate settings from version 1 to version 2
    /// - Parameter defaults: UserDefaults instance to migrate
    public static func migrateV1ToV2(defaults: UserDefaults) {
        // Version 1 -> 2: Add language preferences
        
        // Migrate model selection format
        if let oldModel = defaults.string(forKey: "selectedModel") {
            // Convert old model names to new format
            let newModel = convertModelName(oldModel)
            defaults.set(newModel, forKey: "selectedModel")
        }
        
        // Add language detection preference
        if defaults.object(forKey: "autoDetectLanguage") == nil {
            defaults.set(true, forKey: "autoDetectLanguage")
        }
        
        if defaults.object(forKey: "preferredLanguages") == nil {
            defaults.set(["en"], forKey: "preferredLanguages")
        }
    }
    
    /// Migrate settings from version 2 to version 3
    /// - Parameter defaults: UserDefaults instance to migrate
    public static func migrateV2ToV3(defaults: UserDefaults) {
        // Version 2 -> 3: Add advanced features
        
        // Add punctuation preferences
        if defaults.object(forKey: "autoPunctuation") == nil {
            defaults.set(true, forKey: "autoPunctuation")
        }
        
        if defaults.object(forKey: "smartFormatting") == nil {
            defaults.set(false, forKey: "smartFormatting")
        }
        
        // Add privacy preferences
        if defaults.object(forKey: "collectAnalytics") == nil {
            defaults.set(false, forKey: "collectAnalytics")
        }
        
        if defaults.object(forKey: "shareUsageData") == nil {
            defaults.set(false, forKey: "shareUsageData")
        }
    }
    
    // MARK: - Helper Methods
    
    private static func convertModelName(_ oldName: String) -> String {
        // Convert old model names to new standardized format
        switch oldName.lowercased() {
        case "tiny", "whisper-tiny":
            return "tiny"
        case "base", "whisper-base":
            return "base"
        case "small", "whisper-small":
            return "small"
        case "medium", "whisper-medium":
            return "medium"
        case "large", "whisper-large":
            return "large"
        default:
            return "fast" // Default to fast model
        }
    }
    
    /// Validate settings after migration
    /// - Parameter defaults: UserDefaults instance to validate
    /// - Returns: Array of validation errors, empty if all valid
    public static func validateSettings(defaults: UserDefaults) -> [String] {
        var errors: [String] = []
        
        // Validate hotkey
        if let hotkey = defaults.string(forKey: "globalHotkey"), hotkey.isEmpty {
            errors.append("Global hotkey is not set")
        }
        
        // Validate model selection
        if let model = defaults.string(forKey: "selectedModel") {
            let validModels = ["tiny", "base", "small", "medium", "large", "fast"]
            if !validModels.contains(model) {
                errors.append("Invalid model selection: \(model)")
            }
        } else {
            errors.append("No model selected")
        }
        
        // Validate recording duration
        let duration = defaults.double(forKey: "maxRecordingDuration")
        if duration <= 0 || duration > 30 {
            errors.append("Invalid recording duration: \(duration) seconds")
        }
        
        return errors
    }
    
    /// Reset settings to defaults
    /// - Parameter defaults: UserDefaults instance to reset
    public static func resetToDefaults(defaults: UserDefaults) {
        // Remove all VoiceType settings
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        
        // Set fresh defaults
        defaults.set(1, forKey: "settingsVersion")
        defaults.set("fast", forKey: "selectedModel")
        defaults.set("ctrl+shift+v", forKey: "globalHotkey")
        defaults.set(true, forKey: "showMenuBarIcon")
        defaults.set(5.0, forKey: "maxRecordingDuration")
        defaults.set(false, forKey: "autoStartAtLogin")
        defaults.set(true, forKey: "autoDetectLanguage")
        defaults.set(true, forKey: "autoPunctuation")
        defaults.set(true, forKey: "enableSoundEffects")
        defaults.set(false, forKey: "collectAnalytics")
        
        defaults.synchronize()
    }
    
    /// Export settings to a dictionary
    /// - Parameter defaults: UserDefaults instance to export from
    /// - Returns: Dictionary containing all settings
    public static func exportSettings(defaults: UserDefaults) -> [String: Any] {
        var settings: [String: Any] = [:]
        
        // Export all relevant keys
        let keysToExport = [
            "settingsVersion",
            "selectedModel",
            "globalHotkey",
            "showMenuBarIcon",
            "maxRecordingDuration",
            "autoStartAtLogin",
            "autoDetectLanguage",
            "selectedLanguage",
            "preferredLanguages",
            "autoPunctuation",
            "smartFormatting",
            "enableSoundEffects",
            "transcriptionQuality",
            "collectAnalytics",
            "shareUsageData"
        ]
        
        for key in keysToExport {
            if let value = defaults.object(forKey: key) {
                settings[key] = value
            }
        }
        
        // Add export metadata
        settings["exportDate"] = Date()
        settings["appVersion"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        return settings
    }
    
    /// Import settings from a dictionary
    /// - Parameters:
    ///   - settings: Dictionary containing settings to import
    ///   - defaults: UserDefaults instance to import to
    /// - Returns: Success status and optional error message
    public static func importSettings(_ settings: [String: Any], to defaults: UserDefaults) -> (success: Bool, error: String?) {
        // Validate settings format
        guard let version = settings["settingsVersion"] as? Int else {
            return (false, "Invalid settings format: missing version")
        }
        
        // Check version compatibility
        let currentVersion = 3
        if version > currentVersion {
            return (false, "Settings are from a newer version of VoiceType")
        }
        
        // Import settings
        for (key, value) in settings {
            // Skip metadata keys
            if key == "exportDate" || key == "appVersion" {
                continue
            }
            
            defaults.set(value, forKey: key)
        }
        
        // Run migrations if needed
        if version < currentVersion {
            // Run appropriate migrations
            // This would be handled by AppLifecycleManager
        }
        
        defaults.synchronize()
        
        // Validate imported settings
        let errors = validateSettings(defaults)
        if !errors.isEmpty {
            return (false, "Validation errors: \(errors.joined(separator: ", "))")
        }
        
        return (true, nil)
    }
}