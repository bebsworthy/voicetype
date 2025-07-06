import Foundation
import AVFoundation
import AppKit

/// Manages application permissions for microphone and accessibility access
/// 
/// This manager handles:
/// - Microphone permission requests and monitoring
/// - Accessibility permission detection (AXIsProcessTrusted)
/// - Permission state tracking with @Published properties
/// - User guidance generation for manual permissions
/// - Permission state persistence
///
/// **Usage Example:**
/// ```swift
/// let permissionManager = PermissionManager()
/// 
/// // Check and request microphone permission
/// await permissionManager.requestMicrophonePermission()
/// 
/// // Check accessibility permission
/// if !permissionManager.hasAccessibilityPermission() {
///     permissionManager.showAccessibilityPermissionGuide()
/// }
/// ```
public class PermissionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current state of microphone permission
    @Published public private(set) var microphonePermission: PermissionState = .notRequested
    
    /// Current state of accessibility permission
    @Published public private(set) var accessibilityPermission: PermissionState = .notRequested
    
    /// Whether all required permissions are granted
    @Published public private(set) var allPermissionsGranted: Bool = false
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private var permissionCheckTimer: Timer?
    
    // MARK: - Constants
    
    private enum UserDefaultsKeys {
        static let microphonePermissionState = "VoiceType.MicrophonePermissionState"
        static let accessibilityPermissionState = "VoiceType.AccessibilityPermissionState"
        static let lastPermissionCheckDate = "VoiceType.LastPermissionCheckDate"
    }
    
    // MARK: - Initialization
    
    public init() {
        loadPersistedPermissionStates()
        startPermissionMonitoring()
        checkCurrentPermissions()
    }
    
    deinit {
        permissionCheckTimer?.invalidate()
    }
    
    // MARK: - Public Methods - Microphone
    
    /// Requests microphone permission from the user
    /// - Returns: True if permission was granted, false otherwise
    @MainActor
    public func requestMicrophonePermission() async -> Bool {
        // Check current authorization status
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch currentStatus {
        case .authorized:
            microphonePermission = .granted
            persistPermissionState()
            updateAllPermissionsStatus()
            return true
            
        case .denied, .restricted:
            microphonePermission = .denied
            persistPermissionState()
            updateAllPermissionsStatus()
            return false
            
        case .notDetermined:
            // Request permission
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                    Task { @MainActor in
                        self?.microphonePermission = granted ? .granted : .denied
                        self?.persistPermissionState()
                        self?.updateAllPermissionsStatus()
                        continuation.resume(returning: granted)
                    }
                }
            }
            
        @unknown default:
            microphonePermission = .denied
            persistPermissionState()
            updateAllPermissionsStatus()
            return false
        }
    }
    
    /// Checks the current microphone permission status without requesting
    public func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            microphonePermission = .granted
        case .denied, .restricted:
            microphonePermission = .denied
        case .notDetermined:
            microphonePermission = .notRequested
        @unknown default:
            microphonePermission = .notRequested
        }
        
        persistPermissionState()
        updateAllPermissionsStatus()
    }
    
    // MARK: - Public Methods - Accessibility
    
    /// Checks if the app has accessibility permission
    /// - Returns: True if accessibility permission is granted
    public func hasAccessibilityPermission() -> Bool {
        let trusted = AXIsProcessTrusted()
        accessibilityPermission = trusted ? .granted : .denied
        persistPermissionState()
        updateAllPermissionsStatus()
        return trusted
    }
    
    /// Shows a guide to help users enable accessibility permission
    @MainActor
    public func showAccessibilityPermissionGuide() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        VoiceType needs accessibility permission to insert transcribed text into other applications.
        
        To enable:
        1. Click "Open System Preferences" below
        2. Click the lock icon and enter your password
        3. Check the box next to VoiceType
        4. Restart VoiceType when prompted
        
        This permission allows VoiceType to:
        • Detect the focused text field
        • Insert transcribed text at the cursor position
        
        Your privacy is protected - VoiceType only inserts text you dictate.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            openAccessibilityPreferences()
        }
    }
    
    /// Opens System Preferences to the Accessibility > Privacy section
    public func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    /// Opens System Preferences to the Privacy & Security > Microphone section
    public func openMicrophonePreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }
    
    // MARK: - Public Methods - General
    
    /// Generates user-friendly instructions for enabling a specific permission
    /// - Parameter permission: The permission type to generate instructions for
    /// - Returns: A string containing step-by-step instructions
    public func generatePermissionInstructions(for permission: PermissionType) -> String {
        switch permission {
        case .microphone:
            return """
            To enable microphone access:
            1. Open System Preferences > Privacy & Security > Microphone
            2. Find VoiceType in the list
            3. Check the box next to VoiceType
            4. Restart VoiceType if prompted
            
            This permission is required to record your voice for transcription.
            """
            
        case .accessibility:
            return """
            To enable accessibility access:
            1. Open System Preferences > Privacy & Security > Accessibility
            2. Click the lock icon and enter your password
            3. Find VoiceType in the list
            4. Check the box next to VoiceType
            5. Restart VoiceType when prompted
            
            This permission is required to insert transcribed text into other applications.
            """
        }
    }
    
    /// Shows an alert explaining why a permission was denied and how to fix it
    /// - Parameter permission: The permission that was denied
    @MainActor
    public func showPermissionDeniedAlert(for permission: PermissionType) {
        let alert = NSAlert()
        
        switch permission {
        case .microphone:
            alert.messageText = "Microphone Permission Denied"
            alert.informativeText = """
            VoiceType needs microphone access to transcribe your speech.
            
            You previously denied this permission. To fix this:
            1. Click "Open Settings" below
            2. Find VoiceType and enable microphone access
            3. Restart VoiceType
            """
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            
            if alert.runModal() == .alertFirstButtonReturn {
                openMicrophonePreferences()
            }
            
        case .accessibility:
            showAccessibilityPermissionGuide()
        }
    }
    
    /// Resets permission states and checks current status
    public func refreshPermissionStates() {
        checkMicrophonePermission()
        _ = hasAccessibilityPermission()
    }
    
    // MARK: - Private Methods
    
    private func loadPersistedPermissionStates() {
        // Load microphone permission state
        if let savedMicState = userDefaults.string(forKey: UserDefaultsKeys.microphonePermissionState),
           let state = PermissionState(rawValue: savedMicState) {
            microphonePermission = state
        }
        
        // Load accessibility permission state
        if let savedAccState = userDefaults.string(forKey: UserDefaultsKeys.accessibilityPermissionState),
           let state = PermissionState(rawValue: savedAccState) {
            accessibilityPermission = state
        }
    }
    
    private func persistPermissionState() {
        userDefaults.set(microphonePermission.rawValue, forKey: UserDefaultsKeys.microphonePermissionState)
        userDefaults.set(accessibilityPermission.rawValue, forKey: UserDefaultsKeys.accessibilityPermissionState)
        userDefaults.set(Date(), forKey: UserDefaultsKeys.lastPermissionCheckDate)
    }
    
    private func startPermissionMonitoring() {
        // Check permissions every 5 seconds to detect changes
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkCurrentPermissions()
        }
    }
    
    private func checkCurrentPermissions() {
        checkMicrophonePermission()
        _ = hasAccessibilityPermission()
    }
    
    @MainActor
    private func updateAllPermissionsStatus() {
        allPermissionsGranted = microphonePermission == .granted && accessibilityPermission == .granted
    }
}

// MARK: - Supporting Types

/// Represents the state of a permission
public enum PermissionState: String, Codable {
    case notRequested = "notRequested"
    case denied = "denied"
    case granted = "granted"
    
    /// User-friendly description of the permission state
    public var description: String {
        switch self {
        case .notRequested:
            return "Not Requested"
        case .denied:
            return "Denied"
        case .granted:
            return "Granted"
        }
    }
    
    /// Icon name for the permission state
    public var iconName: String {
        switch self {
        case .notRequested:
            return "questionmark.circle"
        case .denied:
            return "xmark.circle"
        case .granted:
            return "checkmark.circle"
        }
    }
    
    /// Color for the permission state
    public var color: String {
        switch self {
        case .notRequested:
            return "gray"
        case .denied:
            return "red"
        case .granted:
            return "green"
        }
    }
}

/// Types of permissions managed by the app
public enum PermissionType {
    case microphone
    case accessibility
    
    /// User-friendly name for the permission
    public var displayName: String {
        switch self {
        case .microphone:
            return "Microphone"
        case .accessibility:
            return "Accessibility"
        }
    }
    
    /// Description of what the permission is used for
    public var purpose: String {
        switch self {
        case .microphone:
            return "Required to record and transcribe your speech"
        case .accessibility:
            return "Required to insert transcribed text into other applications"
        }
    }
}

// MARK: - Permission Status Extension

extension PermissionManager {
    /// Provides a summary of all permission states
    public var permissionSummary: PermissionSummary {
        PermissionSummary(
            microphone: microphonePermission,
            accessibility: accessibilityPermission,
            allGranted: allPermissionsGranted
        )
    }
}

/// Summary of all permission states
public struct PermissionSummary {
    public let microphone: PermissionState
    public let accessibility: PermissionState
    public let allGranted: Bool
    
    /// List of permissions that need attention (not granted)
    public var permissionsNeedingAttention: [PermissionType] {
        var needed: [PermissionType] = []
        
        if microphone != .granted {
            needed.append(.microphone)
        }
        
        if accessibility != .granted {
            needed.append(.accessibility)
        }
        
        return needed
    }
    
    /// Whether the app can function at all (at least microphone permission)
    public var canFunctionMinimally: Bool {
        microphone == .granted
    }
    
    /// Whether the app can function fully (all permissions granted)
    public var canFunctionFully: Bool {
        allGranted
    }
}