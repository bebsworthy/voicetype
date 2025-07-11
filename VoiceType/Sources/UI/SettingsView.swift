import SwiftUI
import VoiceTypeCore
import VoiceTypeImplementations

/// Main settings window with tabbed interface
public struct SettingsView: View {
    @EnvironmentObject var coordinator: VoiceTypeCoordinator
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case models = "Models"
        case permission = "Permission"
        case test = "Test"
        case about = "About"
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .models: return "cpu"
            case .permission: return "lock.shield"
            case .test: return "mic.circle"
            case .about: return "info.circle"
            }
        }
    }
    
    public init() {}
    
    public var body: some View {
        HSplitView {
            // Sidebar
            VStack(spacing: 0) {
                List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
                .listStyle(.sidebar)
            }
            .frame(width: 200)
            
            // Content
            VStack {
                // Title bar
                HStack {
                    Text(selectedTab.rawValue)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding()
                
                Divider()
                
                // Content area
                Group {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsView()
                    case .models:
                        DynamicModelSettingsView()
                            .id("models-view") // Force unique identity
                    case .permission:
                        PermissionSettingsView()
                    case .test:
                        TestTranscriptionView()
                            .id("test-view") // Force unique identity
                    case .about:
                        AboutView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 400)
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var coordinator: VoiceTypeCoordinator
    @StateObject private var launchAtLoginManager = LaunchAtLoginManager.shared
    @StateObject private var settingsManager = SettingsManager()
    @AppStorage("playFeedbackSounds") private var playFeedbackSounds = true
    @AppStorage("globalHotkey") private var globalHotkey = "ctrl+shift+v"
    @AppStorage("maxRecordingDuration") private var maxRecordingDuration = 30
    
    private var languageBinding: Binding<Language?> {
        Binding(
            get: { settingsManager.selectedLanguage },
            set: { settingsManager.selectedLanguage = $0 }
        )
    }
    
    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: launchAtLoginManager.binding)
            }
            
            Section("Behavior") {
                Toggle("Play feedback sounds", isOn: $playFeedbackSounds)
            }
            
            Section("Recording") {
                VStack(alignment: .leading, spacing: 12) {
                    // Global Hotkey
                    HStack {
                        Text("Global Hotkey:")
                        Spacer()
                        HotkeyRecorderView(hotkey: $globalHotkey) { newHotkey in
                            // Update the hotkey in the coordinator
                            Task {
                                await coordinator.updateHotkey(newHotkey)
                            }
                        }
                    }
                    Text("Hold down to record, release to stop")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    // Maximum Recording Duration
                    HStack {
                        Text("Maximum Recording Duration:")
                        Spacer()
                        Picker("", selection: $maxRecordingDuration) {
                            Text("5 seconds").tag(5)
                            Text("10 seconds").tag(10)
                            Text("30 seconds").tag(30)
                            Text("60 seconds").tag(60)
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                        .onChange(of: maxRecordingDuration) { newValue in
                            // Reinitialize audio processor with new buffer size
                            Task {
                                await coordinator.reinitializeAudioProcessor()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Translation") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Translation Language", selection: languageBinding) {
                        Text("Keep Original Language").tag(Language?.none)
                        Divider()
                        ForEach(Language.allCases, id: \.self) { language in
                            Text("Translate to \(language.displayName)").tag(Language?.some(language))
                        }
                    }
                    Text("Keep Original Language: Transcribe in whatever language you speak\nSelect a language: Translate all speech to that language")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 600)
        .padding()
    }
}

// MARK: - Permission Settings View

struct PermissionSettingsView: View {
    @StateObject private var permissionManager = PermissionManager()
    
    var body: some View {
        PermissionStatusView(permissionManager: permissionManager)
            .padding()
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            // App Icon and Name
            VStack(spacing: 12) {
                Image(systemName: "mic.square.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                
                Text("VoiceType")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            Text("Privacy-first voice dictation for macOS")
                .font(.title3)
            
            Text("VoiceType transcribes your speech to text using on-device AI models. Your audio never leaves your Mac.")
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
            
            Spacer()
            
            // Links
            VStack(spacing: 12) {
                Link("GitHub Repository", destination: URL(string: "https://github.com/voicetype/voicetype")!)
                    .buttonStyle(.link)
                
                Link("Privacy Policy", destination: URL(string: "https://voicetype.app/privacy")!)
                    .buttonStyle(.link)
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: 600, maxHeight: .infinity)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(VoiceTypeCoordinator())
            .frame(width: 800, height: 600)
    }
}