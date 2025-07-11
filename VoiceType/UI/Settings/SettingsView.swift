import SwiftUI

/// Main settings window for VoiceType configuration
struct SettingsView: View {
    @StateObject private var settingsManager = SettingsManager()
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var modelManager = ModelManager()
    
    // Tab selection
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case models = "Models"
        case permissions = "Permissions"
        case audio = "Audio"
        case advanced = "Advanced"
        case about = "About"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .models: return "cpu"
            case .permissions: return "lock.shield"
            case .audio: return "waveform"
            case .advanced: return "slider.horizontal.3"
            case .about: return "info.circle"
            }
        }
    }
    
    var body: some View {
        HSplitView {
            // Sidebar
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(SidebarListStyle())
            .frame(width: 200)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsView(settingsManager: settingsManager)
                    case .models:
                        DynamicModelSettingsView()
                    case .permissions:
                        PermissionSettingsView(permissionManager: permissionManager)
                    case .audio:
                        AudioSettingsView(settingsManager: settingsManager)
                    case .advanced:
                        AdvancedSettingsView(settingsManager: settingsManager)
                    case .about:
                        AboutView()
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 700, height: 500)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.title)
                .fontWeight(.semibold)
            
            GroupBox(label: Label("Language", systemImage: "globe")) {
                LanguagePickerView(selectedLanguage: $settingsManager.selectedLanguage)
                    .padding(.vertical, 8)
            }
            
            GroupBox(label: Label("Hotkey", systemImage: "keyboard")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Press and hold a key combination for push-to-talk voice input.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HotkeyField(hotkey: $settingsManager.globalHotkey)
                    
                    Text("Hold down the keys to record, release to stop")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Default: ⌃⇧V (Control+Shift+V)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            GroupBox(label: Label("Behavior", systemImage: "square.and.arrow.up")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at login", isOn: $settingsManager.launchAtLogin)
                    Toggle("Show menu bar icon", isOn: $settingsManager.showMenuBarIcon)
                    Toggle("Show recording overlay", isOn: $settingsManager.showOverlay)
                    Toggle("Play feedback sounds", isOn: $settingsManager.playFeedbackSounds)
                }
                .padding(.vertical, 8)
            }
        }
    }
}


// MARK: - Permission Settings

struct PermissionSettingsView: View {
    @ObservedObject var permissionManager: PermissionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("VoiceType requires certain permissions to function properly.")
                .font(.callout)
                .foregroundColor(.secondary)
            
            // Permission Status View (reusing from existing implementation)
            PermissionStatusView(permissionManager: permissionManager)
                .padding(.top, 8)
        }
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Audio")
                .font(.title)
                .fontWeight(.semibold)
            
            GroupBox(label: Label("Input Device", systemImage: "mic")) {
                AudioDevicePickerView(selectedDevice: $settingsManager.selectedAudioDevice)
                    .padding(.vertical, 8)
            }
            
            GroupBox(label: Label("Audio Processing", systemImage: "waveform")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable noise suppression", isOn: $settingsManager.enableNoiseSuppression)
                    Toggle("Automatic gain control", isOn: $settingsManager.enableAutomaticGainControl)
                    
                    HStack {
                        Text("Silence threshold:")
                        Slider(value: $settingsManager.silenceThreshold, in: 0...1)
                            .frame(width: 200)
                        Text("\(Int(settingsManager.silenceThreshold * 100))%")
                            .foregroundColor(.secondary)
                            .frame(width: 40)
                    }
                }
                .padding(.vertical, 8)
            }
            
            GroupBox(label: Label("Recording", systemImage: "record.circle")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Maximum recording duration:")
                        Picker("", selection: $settingsManager.maxRecordingDuration) {
                            Text("5 seconds").tag(5)
                            Text("10 seconds").tag(10)
                            Text("30 seconds").tag(30)
                            Text("60 seconds").tag(60)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 120)
                    }
                    
                    Toggle("Stop on silence", isOn: $settingsManager.stopOnSilence)
                }
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var showingResetAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced")
                .font(.title)
                .fontWeight(.semibold)
            
            GroupBox(label: Label("Performance", systemImage: "speedometer")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Processing threads:")
                        Picker("", selection: $settingsManager.processingThreads) {
                            Text("Auto").tag(0)
                            Text("1").tag(1)
                            Text("2").tag(2)
                            Text("4").tag(4)
                            Text("8").tag(8)
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 100)
                    }
                    
                    Toggle("Enable GPU acceleration", isOn: $settingsManager.enableGPUAcceleration)
                    Toggle("Low power mode", isOn: $settingsManager.lowPowerMode)
                }
                .padding(.vertical, 8)
            }
            
            GroupBox(label: Label("Debugging", systemImage: "ant.circle")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable debug logging", isOn: $settingsManager.enableDebugLogging)
                    Toggle("Show performance metrics", isOn: $settingsManager.showPerformanceMetrics)
                    
                    HStack {
                        Button("Export Logs") {
                            exportLogs()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Open Log Folder") {
                            openLogFolder()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 8)
            }
            
            GroupBox(label: Label("Reset", systemImage: "arrow.counterclockwise")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reset all settings to their default values.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Reset All Settings") {
                        showingResetAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundColor(.red)
                }
                .padding(.vertical, 8)
            }
        }
        .alert("Reset Settings", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settingsManager.resetToDefaults()
            }
        } message: {
            Text("Are you sure you want to reset all settings to their default values? This action cannot be undone.")
        }
    }
    
    private func exportLogs() {
        // Implementation for exporting logs
        print("Exporting logs...")
    }
    
    private func openLogFolder() {
        // Implementation for opening log folder
        if let logURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?.appendingPathComponent("Logs/VoiceType") {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: logURL.path)
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // App Icon and Name
            HStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("VoiceType")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Description
            Text("Privacy-first voice dictation for macOS")
                .font(.title3)
            
            Text("VoiceType transcribes your speech to text using on-device AI models. Your audio never leaves your Mac.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Links
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Link(destination: URL(string: "https://voicetype.app")!) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Website")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                    
                    Divider()
                    
                    Link(destination: URL(string: "https://github.com/voicetype/voicetype")!) {
                        HStack {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                            Text("Source Code")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                    
                    Divider()
                    
                    Link(destination: URL(string: "https://voicetype.app/privacy")!) {
                        HStack {
                            Image(systemName: "hand.raised")
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
                .padding(8)
            }
            
            // Credits
            GroupBox(label: Text("Credits")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Built with Whisper by OpenAI")
                        .font(.caption)
                    Text("CoreML implementation by Apple")
                        .font(.caption)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
        }
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}