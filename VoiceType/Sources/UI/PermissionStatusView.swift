import SwiftUI
import VoiceTypeCore
import VoiceTypeImplementations

// MARK: - PermissionState Extensions

extension PermissionState {
    /// Icon name for the permission state
    var iconName: String {
        switch self {
        case .notRequested, .undetermined:
            return "questionmark.circle"
        case .denied:
            return "xmark.circle"
        case .granted:
            return "checkmark.circle"
        }
    }

    /// User-friendly description of the permission state
    var description: String {
        switch self {
        case .notRequested, .undetermined:
            return "Not Requested"
        case .denied:
            return "Denied"
        case .granted:
            return "Granted"
        }
    }
}

/// A SwiftUI view that displays the current permission status and provides actions to request permissions
///
/// This view can be used in the Settings panel or during onboarding to show users
/// the current state of permissions and guide them through the setup process.
///
/// **Usage Example:**
/// ```swift
/// struct SettingsView: View {
///     @StateObject private var permissionManager = PermissionManager()
///     
///     var body: some View {
///         PermissionStatusView(permissionManager: permissionManager)
///     }
/// }
/// ```
public struct PermissionStatusView: View {
    @ObservedObject var permissionManager: PermissionManager

    public init(permissionManager: PermissionManager) {
        self.permissionManager = permissionManager
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.headline)

            VStack(spacing: 12) {
                // Microphone Permission Row
                PermissionRowView(
                    permissionType: .microphone,
                    permissionState: permissionManager.microphonePermission,
                    onRequestPermission: {
                        Task {
                            await permissionManager.requestMicrophonePermission()
                        }
                    },
                    onOpenSettings: {
                        permissionManager.openMicrophonePreferences()
                    }
                )

                Divider()

                // Accessibility Permission Row
                PermissionRowView(
                    permissionType: .accessibility,
                    permissionState: permissionManager.accessibilityPermission,
                    onRequestPermission: {
                        if !permissionManager.hasAccessibilityPermission() {
                            permissionManager.showAccessibilityPermissionGuide()
                        }
                    },
                    onOpenSettings: {
                        permissionManager.openAccessibilityPreferences()
                    }
                )
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Status Summary
            if permissionManager.allPermissionsGranted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All permissions granted - VoiceType is ready to use!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Some permissions are missing - VoiceType may not work properly")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Refresh Button
            Button(action: {
                permissionManager.refreshPermissionStates()
            }) {
                Label("Check Permissions", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding()
        .onAppear {
            permissionManager.refreshPermissionStates()
        }
    }
}

/// A single row displaying a permission's status and actions
struct PermissionRowView: View {
    let permissionType: PermissionType
    let permissionState: PermissionState
    let onRequestPermission: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            // Permission Icon and Name
            HStack(spacing: 8) {
                Image(systemName: permissionState.iconName)
                    .foregroundColor(color(for: permissionState))
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(permissionType.displayName)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.medium)

                    Text(permissionType.purpose)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Permission Status and Action
            HStack(spacing: 8) {
                Text(permissionState.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                switch permissionState {
                case .notRequested, .undetermined:
                    Button("Request") {
                        onRequestPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                case .denied:
                    Button("Open Settings") {
                        onOpenSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                case .granted:
                    // No action needed
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func color(for state: PermissionState) -> Color {
        switch state {
        case .notRequested, .undetermined:
            return .gray
        case .denied:
            return .red
        case .granted:
            return .green
        }
    }
}

/// A compact permission indicator for use in the menu bar
struct PermissionIndicatorView: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        HStack(spacing: 4) {
            if !permissionManager.allPermissionsGranted {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.caption)

                Text("Permissions Required")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// A full-screen onboarding view for initial permission setup
struct PermissionOnboardingView: View {
    @ObservedObject var permissionManager: PermissionManager
    @Binding var isPresented: Bool

    @State private var currentStep: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome
        case microphone
        case accessibility
        case complete
    }

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)

                Text("VoiceType Setup")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(subtitle(for: currentStep))
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)

            Spacer()

            // Content
            Group {
                switch currentStep {
                case .welcome:
                    WelcomeStepView()

                case .microphone:
                    MicrophoneStepView(permissionManager: permissionManager)

                case .accessibility:
                    AccessibilityStepView(permissionManager: permissionManager)

                case .complete:
                    CompleteStepView()
                }
            }
            .frame(maxWidth: 500)

            Spacer()

            // Navigation
            HStack {
                if currentStep != .welcome {
                    Button("Back") {
                        withAnimation {
                            currentStep = previousStep(from: currentStep)
                        }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentStep == .complete {
                    Button("Done") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(currentStep == .welcome ? "Get Started" : "Next") {
                        withAnimation {
                            currentStep = nextStep(from: currentStep)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentStep == .microphone && permissionManager.microphonePermission != .granted)
                }
            }
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 40)
        .frame(width: 600, height: 500)
    }

    private func subtitle(for step: OnboardingStep) -> String {
        switch step {
        case .welcome:
            return "Let's set up VoiceType for first use"
        case .microphone:
            return "Grant microphone access to transcribe your speech"
        case .accessibility:
            return "Enable accessibility to insert text into other apps"
        case .complete:
            return "You're all set!"
        }
    }

    private func nextStep(from step: OnboardingStep) -> OnboardingStep {
        switch step {
        case .welcome:
            return .microphone
        case .microphone:
            return .accessibility
        case .accessibility:
            return .complete
        case .complete:
            return .complete
        }
    }

    private func previousStep(from step: OnboardingStep) -> OnboardingStep {
        switch step {
        case .welcome:
            return .welcome
        case .microphone:
            return .welcome
        case .accessibility:
            return .microphone
        case .complete:
            return .accessibility
        }
    }
}

// MARK: - Onboarding Step Views

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to VoiceType")
                .font(.title2)
                .fontWeight(.semibold)

            Text("VoiceType is a privacy-first dictation tool that converts your speech to text using local AI models.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "lock.fill", text: "100% Private - All processing happens on your device")
                FeatureRow(icon: "waveform", text: "Fast & Accurate - Real-time transcription")
                FeatureRow(icon: "keyboard", text: "Works Everywhere - Insert text into any app")
            }
            .padding(.vertical)

            Text("We'll need to set up a few permissions to get started.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct MicrophoneStepView: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundColor(color(for: permissionManager.microphonePermission))

            Text("Microphone Access")
                .font(.title2)
                .fontWeight(.semibold)

            Text("VoiceType needs access to your microphone to record and transcribe your speech.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if permissionManager.microphonePermission == .notRequested {
                Button("Grant Microphone Access") {
                    Task {
                        await permissionManager.requestMicrophonePermission()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if permissionManager.microphonePermission == .denied {
                VStack(spacing: 8) {
                    Text("Microphone access was denied.")
                        .foregroundColor(.red)

                    Button("Open System Preferences") {
                        permissionManager.openMicrophonePreferences()
                    }
                    .buttonStyle(.bordered)
                }
            } else if permissionManager.microphonePermission == .granted {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Microphone access granted!")
                        .foregroundColor(.green)
                }
            }
        }
    }

    private func color(for state: PermissionState) -> Color {
        switch state {
        case .notRequested, .undetermined:
            return .gray
        case .denied:
            return .red
        case .granted:
            return .green
        }
    }
}

struct AccessibilityStepView: View {
    @ObservedObject var permissionManager: PermissionManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "accessibility")
                .font(.system(size: 48))
                .foregroundColor(permissionManager.accessibilityPermission == .granted ? .green : .gray)

            Text("Accessibility Access")
                .font(.title2)
                .fontWeight(.semibold)

            Text("VoiceType needs accessibility permission to insert transcribed text into other applications.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if permissionManager.accessibilityPermission != .granted {
                VStack(spacing: 12) {
                    Text("This permission must be enabled manually in System Preferences.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("Open Accessibility Settings") {
                        permissionManager.showAccessibilityPermissionGuide()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Check Permission Status") {
                        _ = permissionManager.hasAccessibilityPermission()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Accessibility permission granted!")
                        .foregroundColor(.green)
                }
            }
        }
    }
}

struct CompleteStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Setup Complete!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("VoiceType is ready to use. Press ⌃⇧V (or your custom hotkey) to start dictating.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Tips:")
                    .font(.headline)

                Text("• Press your hotkey to start recording")
                Text("• Speak clearly for best results")
                Text("• Recording stops automatically after 5 seconds")
                Text("• Your text will appear at the cursor position")
            }
            .font(.caption)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 20)

            Text(text)
                .font(.callout)
        }
    }
}

// MARK: - Preview Provider

struct PermissionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PermissionStatusView(permissionManager: PermissionManager())
                .frame(width: 400)
                .previewDisplayName("Permission Status")

            PermissionIndicatorView(permissionManager: PermissionManager())
                .previewDisplayName("Permission Indicator")

            PermissionOnboardingView(
                permissionManager: PermissionManager(),
                isPresented: .constant(true)
            )
            .previewDisplayName("Onboarding View")
        }
    }
}
