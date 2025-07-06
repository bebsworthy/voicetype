import SwiftUI
import VoiceTypeCore
import VoiceTypeImplementations
import VoiceTypeUI

/// Main VoiceType application
@main
struct VoiceTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var coordinator = VoiceTypeCoordinator()
    @StateObject private var lifecycleManager = AppLifecycleManager()
    @State private var showingOnboarding = false
    @State private var showingInitializationError = false
    @State private var isInitialized = false
    
    init() {
        // Init
    }
    
    var body: some Scene {
        // Menu Bar Extra
        MenuBarExtra {
            MenuBarView(coordinator: coordinator)
                .task {
                    guard !isInitialized else { return }
                    isInitialized = true
                    await initializeApp()
                }
        } label: {
            MenuBarExtraIcon(coordinator: coordinator)
                .help("VoiceType - \(coordinator.recordingState.description)")
        }
        .menuBarExtraStyle(.window)
        
        // Settings Window
        Settings {
            SettingsView()
                .environmentObject(coordinator)
        }
        .defaultSize(width: 600, height: 400)
        .commands {
            // Custom commands
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    checkForUpdates()
                }
                .keyboardShortcut("U", modifiers: [.command])
            }
        }
        
        // Window Group for onboarding (hidden by default)
        WindowGroup("Welcome to VoiceType") {
            if lifecycleManager.initializationState == .failed {
                InitializationErrorView(lifecycleManager: lifecycleManager) {
                    Task {
                        await initializeApp()
                    }
                }
                .frame(width: 500, height: 400)
                .fixedSize()
            } else if showingOnboarding || lifecycleManager.needsOnboarding {
                OnboardingView(coordinator: coordinator) {
                    showingOnboarding = false
                    lifecycleManager.completeFirstLaunch()
                }
                .frame(width: 600, height: 500)
                .fixedSize()
            }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
    
    private func checkForUpdates() {
        // TODO: Implement update checking
        print("Checking for updates...")
    }
    
    // MARK: - App Initialization
    
    private func initializeApp() async {
        // Pass lifecycle manager to app delegate
        appDelegate.setLifecycleManager(lifecycleManager)
        
        await lifecycleManager.initializeApp()
        
        // Show onboarding if needed
        if lifecycleManager.needsOnboarding {
            showingOnboarding = true
        }
        
        // Handle initialization errors
        if lifecycleManager.initializationState == .failed {
            showingInitializationError = true
        }
    }
}

// MARK: - Initialization Error View

struct InitializationErrorView: View {
    @ObservedObject var lifecycleManager: AppLifecycleManager
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)
                .symbolRenderingMode(.hierarchical)
            
            Text("Initialization Failed")
                .font(.title)
                .fontWeight(.semibold)
            
            if let error = lifecycleManager.currentError {
                VStack(spacing: 16) {
                    Text(error.localizedDescription)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: 400)
            }
            
            HStack(spacing: 16) {
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                
                Button("Retry") {
                    onRetry()
                }
                .keyboardShortcut(.defaultAction)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @ObservedObject var coordinator: VoiceTypeCoordinator
    let onComplete: () -> Void
    
    @State private var currentStep = 0
    @StateObject private var permissionManager = PermissionManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                
                VStack(alignment: .leading) {
                    Text("Welcome to VoiceType")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Let's get you set up in just a few steps")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Content
            TabView(selection: $currentStep) {
                // Step 1: Introduction
                IntroductionStep()
                    .tag(0)
                
                // Step 2: Permissions
                PermissionsStep(permissionManager: permissionManager)
                    .tag(1)
                
                // Step 3: Test Recording
                TestRecordingStep(coordinator: coordinator)
                    .tag(2)
                
                // Step 4: Complete
                CompletionStep()
                    .tag(3)
            }
            .tabViewStyle(.automatic)
            .padding()
            
            Divider()
            
            // Footer
            HStack {
                if currentStep > 0 {
                    Button("Previous") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(index == currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                Spacer()
                
                if currentStep < 3 {
                    Button("Next") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Get Started") {
                        onComplete()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
    }
}

// MARK: - Onboarding Steps

struct IntroductionStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "mic.badge.checkmark")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)
            
            Text("Privacy-First Voice Dictation")
                .font(.title)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "lock.shield",
                    title: "100% Private",
                    description: "All processing happens on your Mac. Your voice never leaves your device."
                )
                
                FeatureRow(
                    icon: "cpu",
                    title: "Powered by AI",
                    description: "Advanced Whisper models provide accurate transcription in 99+ languages."
                )
                
                FeatureRow(
                    icon: "keyboard",
                    title: "Works Everywhere",
                    description: "Insert text into any application with a simple keyboard shortcut."
                )
            }
            .frame(maxWidth: 400)
            
            Spacer()
        }
        .padding()
    }
}

struct PermissionsStep: View {
    @ObservedObject var permissionManager: PermissionManager
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)
            
            Text("Required Permissions")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("VoiceType needs your permission to access the microphone and optionally to interact with other applications.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 400)
            
            // Permission Status View
            PermissionStatusView(permissionManager: permissionManager)
                .frame(maxWidth: 500)
            
            Spacer()
        }
        .padding()
    }
}

struct TestRecordingStep: View {
    @ObservedObject var coordinator: VoiceTypeCoordinator
    @State private var testText = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .symbolRenderingMode(.hierarchical)
            
            Text("Test Your Setup")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Let's make sure everything is working correctly.")
                .foregroundColor(.secondary)
            
            // Test area
            GroupBox {
                VStack(spacing: 16) {
                    Text("Click the button below and say something:")
                        .font(.callout)
                    
                    Button(action: {
                        Task {
                            if coordinator.recordingState == .idle {
                                await coordinator.startDictation()
                            } else if coordinator.recordingState == .recording {
                                await coordinator.stopDictation()
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: coordinator.recordingState == .recording ? "stop.fill" : "mic.fill")
                            Text(coordinator.recordingState == .recording ? "Stop Recording" : "Start Test Recording")
                        }
                        .frame(width: 200)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                    .disabled(coordinator.recordingState == .processing)
                    
                    if coordinator.recordingState == .recording {
                        RecordingIndicator()
                    }
                    
                    if !coordinator.lastTranscription.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transcribed text:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(coordinator.lastTranscription)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}

struct CompletionStep: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .symbolRenderingMode(.hierarchical)
            
            Text("You're All Set!")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("VoiceType is ready to use. Here's how to get started:")
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                InstructionRow(
                    number: "1",
                    text: "Click on any text field in any application"
                )
                
                InstructionRow(
                    number: "2",
                    text: "Press ⌃⇧V (or your custom hotkey) to start recording"
                )
                
                InstructionRow(
                    number: "3",
                    text: "Speak clearly for up to 5 seconds"
                )
                
                InstructionRow(
                    number: "4",
                    text: "Your text will appear automatically!"
                )
            }
            .frame(maxWidth: 400)
            
            Text("You can always change settings or get help from the menu bar icon.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Helper Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct InstructionRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            Text(text)
                .font(.callout)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @EnvironmentObject var coordinator: VoiceTypeCoordinator
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            PermissionStatusView(permissionManager: PermissionManager())
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 600, height: 400)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("globalHotkey") private var globalHotkey = "ctrl+shift+v"
    @AppStorage("selectedModel") private var selectedModel = "fast"
    
    var body: some View {
        Form {
            Section("Recording") {
                Picker("AI Model", selection: $selectedModel) {
                    Text("Fast").tag("fast")
                    Text("Balanced").tag("balanced")
                    Text("Accurate").tag("accurate")
                }
                
                HStack {
                    Text("Global Hotkey:")
                    TextField("Hotkey", text: $globalHotkey)
                        .frame(width: 120)
                }
            }
        }
        .padding()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
            
            Text("VoiceType")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Version 1.0.0")
                .foregroundColor(.secondary)
            
            Text("Voice-to-text input for macOS")
                .font(.headline)
            
            Spacer()
            
            Link("GitHub Repository", destination: URL(string: "https://github.com/VoiceType/VoiceType")!)
                .buttonStyle(.link)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}