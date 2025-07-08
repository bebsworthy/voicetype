import Foundation
import AppKit
import Combine

/// Example usage of the HotkeyManager
///
/// This example demonstrates:
/// - Basic hotkey registration
/// - Handling conflicts
/// - Dynamic updates
/// - Using presets
/// - Integration with SwiftUI
@MainActor
class HotkeyManagerExample {
    private let hotkeyManager = HotkeyManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupObservers()
        setupDefaultHotkeys()
    }

    // MARK: - Basic Setup

    private func setupObservers() {
        // Observe hotkey system status
        hotkeyManager.$isActive
            .sink { isActive in
                print("Hotkey system active: \(isActive)")
            }
            .store(in: &cancellables)

        // Observe errors
        hotkeyManager.$lastError
            .compactMap { $0 }
            .sink { error in
                print("Hotkey error: \(error.localizedDescription)")

                // Handle accessibility permission error
                if case .accessibilityPermissionRequired = error {
                    self.promptForAccessibilityPermission()
                }
            }
            .store(in: &cancellables)

        // Observe registered hotkeys
        hotkeyManager.$registeredHotkeys
            .sink { hotkeys in
                print("Registered hotkeys:")
                for (_, hotkey) in hotkeys {
                    print("  - \(hotkey.identifier): \(hotkey.displayString)")
                }
            }
            .store(in: &cancellables)
    }

    @MainActor
    private func setupDefaultHotkeys() {
        do {
            // Register toggle recording hotkey
            try hotkeyManager.registerPreset(.toggleRecording) { [weak self] in
                self?.handleToggleRecording()
            }

            // Register cancel recording hotkey
            try hotkeyManager.registerPreset(.cancelRecording) { [weak self] in
                self?.handleCancelRecording()
            }

            // Register custom hotkey
            try hotkeyManager.registerHotkey(
                identifier: "custom.test",
                keyCombo: "cmd+opt+t"
            )                { print("Custom hotkey triggered!") }
        } catch {
            print("Failed to register hotkey: \(error)")
        }
    }

    // MARK: - Hotkey Actions

    private func handleToggleRecording() {
        print("Toggle recording triggered")
        // Your recording toggle logic here
    }

    private func handleCancelRecording() {
        print("Cancel recording triggered")
        // Your cancel logic here
    }

    // MARK: - Dynamic Updates

    @MainActor
    func updateHotkey() {
        do {
            // Update existing hotkey
            try hotkeyManager.updateHotkey(
                identifier: HotkeyManager.HotkeyPreset.toggleRecording.identifier,
                newKeyCombo: "ctrl+space"
            )
            print("Hotkey updated successfully")
        } catch {
            print("Failed to update hotkey: \(error)")
        }
    }

    // MARK: - Validation Examples

    func validateUserInput(_ keyCombo: String) -> Bool {
        let result = hotkeyManager.validateKeyCombo(keyCombo)

        if result.isValid {
            print("Key combination '\(keyCombo)' is valid")
            return true
        } else {
            print("Invalid key combination: \(result.error ?? "Unknown error")")
            return false
        }
    }

    // MARK: - Conflict Resolution

    @MainActor
    func registerWithConflictHandling(identifier: String, keyCombo: String, action: @escaping () -> Void) {
        do {
            try hotkeyManager.registerHotkey(identifier: identifier, keyCombo: keyCombo, action: action)
        } catch let error as HotkeyError {
            switch error {
            case .conflictingHotkey(let existingId, _):
                // Show alert to user
                showConflictAlert(newId: identifier, existingId: existingId, keyCombo: keyCombo)
            default:
                print("Registration failed: \(error.localizedDescription)")
            }
        } catch {
            print("Unexpected error: \(error)")
        }
    }

    // MARK: - UI Integration

    private func showConflictAlert(newId: String, existingId: String, keyCombo: String) {
        let alert = NSAlert()
        alert.messageText = "Hotkey Conflict"
        alert.informativeText = "The key combination '\(keyCombo)' is already assigned to '\(existingId)'. Do you want to reassign it?"
        alert.addButton(withTitle: "Reassign")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            // Unregister old and register new
            hotkeyManager.unregisterHotkey(identifier: existingId)
            try? hotkeyManager.registerHotkey(identifier: newId, keyCombo: keyCombo) {}
        }
    }

    private func promptForAccessibilityPermission() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "VoiceType needs accessibility permission to use global hotkeys. Please grant access in System Preferences."
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        hotkeyManager.unregisterAllHotkeys()
        cancellables.removeAll()
    }
}

// MARK: - SwiftUI Integration Example

import SwiftUI

/// SwiftUI view for hotkey configuration
struct HotkeyConfigurationView: View {
    @StateObject private var hotkeyManager = HotkeyManager()
    @State private var selectedPreset: HotkeyManager.HotkeyPreset = .toggleRecording
    @State private var customKeyCombo: String = ""
    @State private var validationError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Status
            HStack {
                Circle()
                    .fill(hotkeyManager.isActive ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(hotkeyManager.isActive ? "Hotkey system active" : "Hotkey system inactive")
                    .font(.caption)
            }

            // Registered hotkeys
            GroupBox("Registered Hotkeys") {
                if hotkeyManager.registeredHotkeys.isEmpty {
                    Text("No hotkeys registered")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(Array(hotkeyManager.registeredHotkeys.values), id: \.identifier) { hotkey in
                        HStack {
                            Text(hotkey.identifier)
                            Spacer()
                            Text(hotkey.displayString)
                                .font(.system(.body, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            // Add new hotkey
            GroupBox("Add Hotkey") {
                VStack(alignment: .leading) {
                    // Preset selection
                    Picker("Preset", selection: $selectedPreset) {
                        Text("Toggle Recording").tag(HotkeyManager.HotkeyPreset.toggleRecording)
                        Text("Cancel Recording").tag(HotkeyManager.HotkeyPreset.cancelRecording)
                        Text("Show Overlay").tag(HotkeyManager.HotkeyPreset.showOverlay)
                    }

                    // Custom key combo
                    HStack {
                        TextField("Key combination (e.g., cmd+shift+r)", text: $customKeyCombo)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Button("Validate") {
                            validateKeyCombo()
                        }
                    }

                    if let error = validationError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button("Register Hotkey") {
                        registerSelectedHotkey()
                    }
                    .disabled(customKeyCombo.isEmpty)
                }
            }

            // Error display
            if let error = hotkeyManager.lastError {
                GroupBox("Error") {
                    Text(error.localizedDescription)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func validateKeyCombo() {
        let result = hotkeyManager.validateKeyCombo(customKeyCombo)
        validationError = result.isValid ? nil : result.error
    }

    private func registerSelectedHotkey() {
        do {
            try hotkeyManager.registerHotkey(
                identifier: selectedPreset.identifier,
                keyCombo: customKeyCombo.isEmpty ? selectedPreset.defaultKeyCombo : customKeyCombo
            )                {
                    print("\(selectedPreset.description) triggered")
                }
            customKeyCombo = ""
            validationError = nil
        } catch {
            validationError = error.localizedDescription
        }
    }
}

// MARK: - Usage in App

/// Example app delegate integration
class AppDelegateExample: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize hotkey manager
        hotkeyManager = HotkeyManager()

        // Register default hotkeys
        Task { @MainActor in
            setupHotkeys()
        }
    }

    @MainActor
    private func setupHotkeys() {
        do {
            // Main recording toggle
            try hotkeyManager.registerPreset(.toggleRecording) { [weak self] in
                self?.toggleRecording()
            }

            // Quick insert last transcription
            try hotkeyManager.registerHotkey(
                identifier: "quick_insert",
                keyCombo: "cmd+shift+space"
            )                { [weak self] in
                    self?.quickInsertTranscription()
                }
        } catch {
            print("Failed to setup hotkeys: \(error)")
        }
    }

    private func toggleRecording() {
        // Your recording logic
        print("Toggle recording from hotkey")
    }

    private func quickInsertTranscription() {
        // Your transcription insertion logic
        print("Quick insert transcription")
    }
}
