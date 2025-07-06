//
//  AppLifecycleManager.swift
//  VoiceType
//
//  Manages app launch sequence, initialization, and lifecycle events
//

import Foundation
import SwiftUI
import os.log

/// Manages the application lifecycle, initialization, and setup
@MainActor
public class AppLifecycleManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Current initialization state
    @Published public var initializationState: InitializationState = .notStarted
    
    /// Initialization progress (0.0 to 1.0)
    @Published public var initializationProgress: Double = 0.0
    
    /// Current error if any
    @Published public var currentError: AppLifecycleError?
    
    /// Whether this is the first launch
    @Published public var isFirstLaunch: Bool = false
    
    /// Whether the app needs onboarding
    @Published public var needsOnboarding: Bool = false
    
    /// Settings migration status
    @Published public var settingsMigrationStatus: MigrationStatus = .notNeeded
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.voicetype.app", category: "AppLifecycle")
    private let fileManager = FileManager.default
    private let settingsManager: SettingsManager
    private let modelManager: ModelManager
    
    // Settings version tracking
    private let currentSettingsVersion = 3  // Updated to match migration system
    private let settingsVersionKey = "settingsVersion"
    private let hasLaunchedBeforeKey = "hasLaunchedBefore"
    
    // MARK: - Initialization State
    
    public enum InitializationState: String {
        case notStarted = "Not Started"
        case checkingEnvironment = "Checking Environment"
        case creatingDirectories = "Creating Directories"
        case loadingSettings = "Loading Settings"
        case migratingSettings = "Migrating Settings"
        case validatingModels = "Validating Models"
        case checkingPermissions = "Checking Permissions"
        case completed = "Completed"
        case failed = "Failed"
    }
    
    public enum MigrationStatus {
        case notNeeded
        case inProgress
        case completed
        case failed(Error)
    }
    
    // MARK: - Initialization
    
    public init(settingsManager: SettingsManager? = nil, modelManager: ModelManager? = nil) {
        self.settingsManager = settingsManager ?? SettingsManager()
        self.modelManager = modelManager ?? ModelManager()
        
        // Check first launch status
        self.isFirstLaunch = !UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
        self.needsOnboarding = isFirstLaunch
    }
    
    // MARK: - Public Methods
    
    /// Initialize the application on launch
    public func initializeApp() async {
        logger.info("Starting app initialization...")
        initializationState = .checkingEnvironment
        initializationProgress = 0.0
        
        do {
            // Step 1: Check environment and create directories
            try await setupEnvironment()
            initializationProgress = 0.2
            
            // Step 2: Load and migrate settings
            try await loadAndMigrateSettings()
            initializationProgress = 0.4
            
            // Step 3: Validate models
            try await validateModels()
            initializationProgress = 0.6
            
            // Step 4: Check permissions
            await checkPermissions()
            initializationProgress = 0.8
            
            // Step 5: Complete initialization
            await completeInitialization()
            initializationProgress = 1.0
            
            initializationState = .completed
            logger.info("App initialization completed successfully")
            
        } catch {
            logger.error("App initialization failed: \(error.localizedDescription)")
            currentError = AppLifecycleError.initializationFailed(error)
            initializationState = .failed
        }
    }
    
    /// Handle app termination
    public func handleAppTermination() {
        logger.info("App is terminating...")
        
        // Save current state
        saveAppState()
        
        // Clean up temporary files
        cleanupTempFiles()
        
        // Stop any background tasks
        stopBackgroundTasks()
    }
    
    /// Handle app entering background
    public func handleEnterBackground() {
        logger.info("App entering background...")
        
        // Save current state
        saveAppState()
        
        // Pause non-essential operations
        pauseNonEssentialOperations()
    }
    
    /// Handle app entering foreground
    public func handleEnterForeground() {
        logger.info("App entering foreground...")
        
        // Resume operations
        resumeOperations()
        
        // Check for updates or changes
        Task {
            await checkForUpdates()
        }
    }
    
    /// Mark first launch as completed
    public func completeFirstLaunch() {
        UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
        isFirstLaunch = false
        needsOnboarding = false
        logger.info("First launch completed")
    }
    
    // MARK: - Private Methods - Setup
    
    private func setupEnvironment() async throws {
        initializationState = .checkingEnvironment
        logger.info("Setting up environment...")
        
        // Check system requirements
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 13 else {
            throw AppLifecycleError.unsupportedOS
        }
        
        initializationState = .creatingDirectories
        logger.info("Creating required directories...")
        
        // Create required directories
        try createRequiredDirectories()
        
        // Set up logging
        setupLogging()
        
        // Configure app settings
        configureAppSettings()
    }
    
    private func createRequiredDirectories() throws {
        let directories = [
            try fileManager.voiceTypeDirectory,
            try fileManager.modelsDirectory,
            try fileManager.downloadsDirectory,
            try fileManager.cacheDirectory
        ]
        
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                logger.info("Created directory: \(directory.path)")
            }
        }
        
        // Create logs directory
        let logsDir = try fileManager.voiceTypeDirectory.appendingPathComponent("logs", isDirectory: true)
        if !fileManager.fileExists(atPath: logsDir.path) {
            try fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        }
    }
    
    private func setupLogging() {
        // Configure unified logging
        // This is already handled by the Logger instance
    }
    
    private func configureAppSettings() {
        // Configure app-wide settings
        NSApp.appearance = NSAppearance(named: .aqua)
    }
    
    // MARK: - Private Methods - Settings
    
    private func loadAndMigrateSettings() async throws {
        initializationState = .loadingSettings
        logger.info("Loading settings...")
        
        // Check settings version
        let savedVersion = UserDefaults.standard.integer(forKey: settingsVersionKey)
        
        if savedVersion < currentSettingsVersion {
            initializationState = .migratingSettings
            settingsMigrationStatus = .inProgress
            
            try await migrateSettings(from: savedVersion, to: currentSettingsVersion)
            
            settingsMigrationStatus = .completed
            UserDefaults.standard.set(currentSettingsVersion, forKey: settingsVersionKey)
        }
        
        // Validate settings
        try validateSettings()
    }
    
    private func migrateSettings(from oldVersion: Int, to newVersion: Int) async throws {
        logger.info("Migrating settings from version \(oldVersion) to \(newVersion)")
        
        let defaults = UserDefaults.standard
        
        // Run migrations in sequence
        var currentVersion = oldVersion
        
        while currentVersion < newVersion {
            switch currentVersion {
            case 0:
                SettingsMigration.migrateV0ToV1(defaults: defaults)
                currentVersion = 1
            case 1:
                SettingsMigration.migrateV1ToV2(defaults: defaults)
                currentVersion = 2
            case 2:
                SettingsMigration.migrateV2ToV3(defaults: defaults)
                currentVersion = 3
            default:
                logger.warning("No migration path from version \(currentVersion)")
                currentVersion = newVersion
            }
        }
        
        // Validate migrated settings
        let errors = SettingsMigration.validateSettings(defaults: defaults)
        if !errors.isEmpty {
            logger.warning("Settings validation errors after migration: \(errors)")
            // Continue with defaults for invalid settings
        }
    }
    
    private func setDefaultSettings() {
        // Set default values if not already set
        if UserDefaults.standard.object(forKey: "selectedModel") == nil {
            UserDefaults.standard.set("fast", forKey: "selectedModel")
        }
        
        if UserDefaults.standard.object(forKey: "globalHotkey") == nil {
            UserDefaults.standard.set("ctrl+shift+v", forKey: "globalHotkey")
        }
        
        if UserDefaults.standard.object(forKey: "showMenuBarIcon") == nil {
            UserDefaults.standard.set(true, forKey: "showMenuBarIcon")
        }
        
        if UserDefaults.standard.object(forKey: "maxRecordingDuration") == nil {
            UserDefaults.standard.set(5.0, forKey: "maxRecordingDuration")
        }
        
        if UserDefaults.standard.object(forKey: "autoStartAtLogin") == nil {
            UserDefaults.standard.set(false, forKey: "autoStartAtLogin")
        }
    }
    
    private func validateSettings() throws {
        // Validate critical settings
        let model = UserDefaults.standard.string(forKey: "selectedModel") ?? ""
        guard !model.isEmpty else {
            throw AppLifecycleError.invalidSettings("No model selected")
        }
        
        let hotkey = UserDefaults.standard.string(forKey: "globalHotkey") ?? ""
        guard !hotkey.isEmpty else {
            throw AppLifecycleError.invalidSettings("No hotkey configured")
        }
    }
    
    // MARK: - Private Methods - Models
    
    private func validateModels() async throws {
        initializationState = .validatingModels
        logger.info("Validating models...")
        
        // Check for embedded fast model
        let embeddedModelURL = Bundle.main.url(forResource: "whisper-fast", withExtension: "mlpackage")
        if embeddedModelURL == nil {
            logger.warning("Embedded fast model not found in bundle")
        }
        
        // Get installed models
        let installedModels = try await modelManager.getInstalledModels()
        logger.info("Found \(installedModels.count) installed models")
        
        // Check if we have at least one working model
        let selectedModel = UserDefaults.standard.string(forKey: "selectedModel") ?? "fast"
        var hasWorkingModel = false
        
        if selectedModel == "fast" && embeddedModelURL != nil {
            hasWorkingModel = true
        } else {
            hasWorkingModel = installedModels.contains { $0.name.lowercased().contains(selectedModel) }
        }
        
        if !hasWorkingModel {
            // Try to fallback to any available model
            if embeddedModelURL != nil {
                UserDefaults.standard.set("fast", forKey: "selectedModel")
                logger.info("Falling back to embedded fast model")
            } else if !installedModels.isEmpty {
                let firstModel = installedModels[0].name.lowercased()
                UserDefaults.standard.set(firstModel, forKey: "selectedModel")
                logger.info("Falling back to first available model: \(firstModel)")
            } else {
                throw AppLifecycleError.noModelsAvailable
            }
        }
        
        // Clean up partial downloads
        try fileManager.cleanupPartialDownloads()
    }
    
    // MARK: - Private Methods - Permissions
    
    private func checkPermissions() async {
        initializationState = .checkingPermissions
        logger.info("Checking permissions...")
        
        // Permission checking is handled by PermissionManager
        // This is just a placeholder for the initialization flow
    }
    
    // MARK: - Private Methods - Completion
    
    private func completeInitialization() async {
        logger.info("Completing initialization...")
        
        // Clean up old cache files
        try? fileManager.cleanupCache(olderThan: 7)
        
        // Set up crash reporting (if enabled)
        setupCrashReporting()
        
        // Schedule periodic maintenance
        schedulePeriodicMaintenance()
    }
    
    private func setupCrashReporting() {
        // Placeholder for crash reporting setup
        // Could integrate with services like Sentry or Crashlytics
    }
    
    private func schedulePeriodicMaintenance() {
        // Schedule daily maintenance tasks
        Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            Task { @MainActor in
                self.performMaintenance()
            }
        }
    }
    
    private func performMaintenance() {
        logger.info("Performing periodic maintenance...")
        
        // Clean up old cache files
        try? fileManager.cleanupCache(olderThan: 7)
        
        // Clean up old log files
        cleanupOldLogs()
        
        // Check disk space
        checkDiskSpace()
    }
    
    // MARK: - Private Methods - State Management
    
    private func saveAppState() {
        // Save current app state
        UserDefaults.standard.synchronize()
    }
    
    private func cleanupTempFiles() {
        // Clean up temporary files
        do {
            let tempDir = try fileManager.cacheDirectory
            let contents = try fileManager.contentsOfDirectory(at: tempDir,
                                                              includingPropertiesForKeys: nil)
            for file in contents {
                if file.pathExtension == "tmp" {
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            logger.error("Failed to cleanup temp files: \(error.localizedDescription)")
        }
    }
    
    private func stopBackgroundTasks() {
        // Stop any background download tasks
        URLSession.shared.invalidateAndCancel()
    }
    
    private func pauseNonEssentialOperations() {
        // Pause operations that aren't needed in background
    }
    
    private func resumeOperations() {
        // Resume paused operations
    }
    
    private func checkForUpdates() async {
        // Check for app updates
        // This would connect to your update server
    }
    
    private func cleanupOldLogs() {
        do {
            let logsDir = try fileManager.voiceTypeDirectory.appendingPathComponent("logs", isDirectory: true)
            let contents = try fileManager.contentsOfDirectory(at: logsDir,
                                                              includingPropertiesForKeys: [.contentModificationDateKey])
            
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            
            for file in contents {
                let resourceValues = try file.resourceValues(forKeys: [.contentModificationDateKey])
                if let modificationDate = resourceValues.contentModificationDate,
                   modificationDate < cutoffDate {
                    try fileManager.removeItem(at: file)
                }
            }
        } catch {
            logger.error("Failed to cleanup old logs: \(error.localizedDescription)")
        }
    }
    
    private func checkDiskSpace() {
        let availableSpace = fileManager.availableDiskSpace
        let formatter = ByteCountFormatter()
        let availableStr = formatter.string(fromByteCount: availableSpace)
        
        if availableSpace < 500_000_000 { // Less than 500MB
            logger.warning("Low disk space: \(availableStr)")
            // Could show a notification to the user
        }
    }
}

// MARK: - App Lifecycle Error

public enum AppLifecycleError: LocalizedError {
    case initializationFailed(Error)
    case unsupportedOS
    case directoryCreationFailed(URL, Error)
    case settingsMigrationFailed(Error)
    case invalidSettings(String)
    case noModelsAvailable
    case permissionDenied(String)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "App initialization failed: \(error.localizedDescription)"
        case .unsupportedOS:
            return "This version of macOS is not supported. Please update to macOS 13.0 or later."
        case .directoryCreationFailed(let url, let error):
            return "Failed to create directory at \(url.path): \(error.localizedDescription)"
        case .settingsMigrationFailed(let error):
            return "Failed to migrate settings: \(error.localizedDescription)"
        case .invalidSettings(let detail):
            return "Invalid settings: \(detail)"
        case .noModelsAvailable:
            return "No AI models are available. Please download a model to continue."
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .initializationFailed:
            return "Try restarting the app. If the problem persists, please reinstall."
        case .unsupportedOS:
            return "Update your macOS to version 13.0 or later."
        case .directoryCreationFailed:
            return "Check that you have write permissions to your home directory."
        case .settingsMigrationFailed:
            return "Your settings will be reset to defaults."
        case .invalidSettings:
            return "Check your settings and try again."
        case .noModelsAvailable:
            return "Download a model from the settings window."
        case .permissionDenied:
            return "Grant the required permission in System Settings."
        }
    }
}