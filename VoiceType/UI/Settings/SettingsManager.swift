import SwiftUI
import Combine

/// Manages application settings and preferences
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - General Settings
    @AppStorage("selectedLanguage") private var selectedLanguageRaw: String = Language.english.rawValue
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("showMenuBarIcon") var showMenuBarIcon: Bool = true
    @AppStorage("showOverlay") var showOverlay: Bool = true
    @AppStorage("playFeedbackSounds") var playFeedbackSounds: Bool = true
    
    var selectedLanguage: Language {
        get { Language(rawValue: selectedLanguageRaw) ?? .english }
        set { selectedLanguageRaw = newValue.rawValue }
    }
    
    // MARK: - Hotkey Settings
    @Published var globalHotkey: Hotkey? {
        didSet {
            saveHotkey()
            registerHotkey()
        }
    }
    
    // MARK: - Model Settings
    @AppStorage("selectedModel") private var selectedModelRaw: String = ModelType.fast.rawValue
    
    var selectedModel: ModelType {
        get { ModelType(rawValue: selectedModelRaw) ?? .fast }
        set { selectedModelRaw = newValue.rawValue }
    }
    
    // MARK: - Audio Settings
    @AppStorage("selectedAudioDeviceID") private var selectedAudioDeviceID: String?
    @AppStorage("enableNoiseSuppression") var enableNoiseSuppression: Bool = true
    @AppStorage("enableAutomaticGainControl") var enableAutomaticGainControl: Bool = true
    @AppStorage("silenceThreshold") var silenceThreshold: Double = 0.1
    @AppStorage("maxRecordingDuration") var maxRecordingDuration: Int = 30
    @AppStorage("stopOnSilence") var stopOnSilence: Bool = true
    
    var selectedAudioDevice: AudioDevice? {
        get {
            guard let deviceID = selectedAudioDeviceID else { return nil }
            // In a real implementation, this would look up the device by ID
            return nil
        }
        set {
            selectedAudioDeviceID = newValue?.id
        }
    }
    
    // MARK: - Advanced Settings
    @AppStorage("processingThreads") var processingThreads: Int = 0 // 0 = Auto
    @AppStorage("enableGPUAcceleration") var enableGPUAcceleration: Bool = true
    @AppStorage("lowPowerMode") var lowPowerMode: Bool = false
    @AppStorage("enableDebugLogging") var enableDebugLogging: Bool = false
    @AppStorage("showPerformanceMetrics") var showPerformanceMetrics: Bool = false
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        loadHotkey()
        setupBindings()
        registerHotkey()
    }
    
    // MARK: - Public Methods
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        // General
        selectedLanguageRaw = Language.english.rawValue
        launchAtLogin = false
        showMenuBarIcon = true
        showOverlay = true
        playFeedbackSounds = true
        
        // Hotkey
        globalHotkey = Hotkey(keyCode: UInt16(kVK_ANSI_V), modifierFlags: [.control, .shift])
        
        // Model
        selectedModelRaw = ModelType.fast.rawValue
        
        // Audio
        selectedAudioDeviceID = nil
        enableNoiseSuppression = true
        enableAutomaticGainControl = true
        silenceThreshold = 0.1
        maxRecordingDuration = 30
        stopOnSilence = true
        
        // Advanced
        processingThreads = 0
        enableGPUAcceleration = true
        lowPowerMode = false
        enableDebugLogging = false
        showPerformanceMetrics = false
    }
    
    /// Export settings to a file
    func exportSettings(to url: URL) throws {
        let settings = ExportedSettings(
            general: GeneralSettings(
                selectedLanguage: selectedLanguage,
                launchAtLogin: launchAtLogin,
                showMenuBarIcon: showMenuBarIcon,
                showOverlay: showOverlay,
                playFeedbackSounds: playFeedbackSounds
            ),
            hotkey: globalHotkey,
            model: ModelSettings(selectedModel: selectedModel),
            audio: AudioSettings(
                enableNoiseSuppression: enableNoiseSuppression,
                enableAutomaticGainControl: enableAutomaticGainControl,
                silenceThreshold: silenceThreshold,
                maxRecordingDuration: maxRecordingDuration,
                stopOnSilence: stopOnSilence
            ),
            advanced: AdvancedSettings(
                processingThreads: processingThreads,
                enableGPUAcceleration: enableGPUAcceleration,
                lowPowerMode: lowPowerMode,
                enableDebugLogging: enableDebugLogging,
                showPerformanceMetrics: showPerformanceMetrics
            )
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: url)
    }
    
    /// Import settings from a file
    func importSettings(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let settings = try decoder.decode(ExportedSettings.self, from: data)
        
        // Apply imported settings
        selectedLanguage = settings.general.selectedLanguage
        launchAtLogin = settings.general.launchAtLogin
        showMenuBarIcon = settings.general.showMenuBarIcon
        showOverlay = settings.general.showOverlay
        playFeedbackSounds = settings.general.playFeedbackSounds
        
        globalHotkey = settings.hotkey
        selectedModel = settings.model.selectedModel
        
        enableNoiseSuppression = settings.audio.enableNoiseSuppression
        enableAutomaticGainControl = settings.audio.enableAutomaticGainControl
        silenceThreshold = settings.audio.silenceThreshold
        maxRecordingDuration = settings.audio.maxRecordingDuration
        stopOnSilence = settings.audio.stopOnSilence
        
        processingThreads = settings.advanced.processingThreads
        enableGPUAcceleration = settings.advanced.enableGPUAcceleration
        lowPowerMode = settings.advanced.lowPowerMode
        enableDebugLogging = settings.advanced.enableDebugLogging
        showPerformanceMetrics = settings.advanced.showPerformanceMetrics
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Update launch at login when setting changes
        $launchAtLogin
            .sink { [weak self] enabled in
                self?.updateLaunchAtLogin(enabled)
            }
            .store(in: &cancellables)
    }
    
    private func loadHotkey() {
        if let hotkeyData = userDefaults.data(forKey: "globalHotkey"),
           let hotkey = try? JSONDecoder().decode(Hotkey.self, from: hotkeyData) {
            self.globalHotkey = hotkey
        } else {
            // Default hotkey: Ctrl+Shift+V
            self.globalHotkey = Hotkey(keyCode: UInt16(kVK_ANSI_V), modifierFlags: [.control, .shift])
        }
    }
    
    private func saveHotkey() {
        if let hotkey = globalHotkey,
           let data = try? JSONEncoder().encode(hotkey) {
            userDefaults.set(data, forKey: "globalHotkey")
        } else {
            userDefaults.removeObject(forKey: "globalHotkey")
        }
    }
    
    private func registerHotkey() {
        HotkeyManager.shared.unregister()
        
        if let hotkey = globalHotkey {
            HotkeyManager.shared.register(hotkey: hotkey) {
                // This would trigger the voice recording in a real implementation
                NotificationCenter.default.post(name: .startVoiceRecording, object: nil)
            }
        }
    }
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        // In a real implementation, this would use SMLoginItemSetEnabled
        // or the new SMAppService API to manage launch at login
        print("Launch at login: \(enabled)")
    }
}

// MARK: - Settings Export Types

struct ExportedSettings: Codable {
    let general: GeneralSettings
    let hotkey: Hotkey?
    let model: ModelSettings
    let audio: AudioSettings
    let advanced: AdvancedSettings
}

struct GeneralSettings: Codable {
    let selectedLanguage: Language
    let launchAtLogin: Bool
    let showMenuBarIcon: Bool
    let showOverlay: Bool
    let playFeedbackSounds: Bool
}

struct ModelSettings: Codable {
    let selectedModel: ModelType
}

struct AudioSettings: Codable {
    let enableNoiseSuppression: Bool
    let enableAutomaticGainControl: Bool
    let silenceThreshold: Double
    let maxRecordingDuration: Int
    let stopOnSilence: Bool
}

struct AdvancedSettings: Codable {
    let processingThreads: Int
    let enableGPUAcceleration: Bool
    let lowPowerMode: Bool
    let enableDebugLogging: Bool
    let showPerformanceMetrics: Bool
}

// MARK: - Notifications

extension Notification.Name {
    static let startVoiceRecording = Notification.Name("startVoiceRecording")
}

// MARK: - AppStorage Extensions

extension ModelType: RawRepresentable {
    public init?(rawValue: String) {
        switch rawValue {
        case "fast": self = .fast
        case "balanced": self = .balanced
        case "accurate": self = .accurate
        default: return nil
        }
    }
    
    public var rawValue: String {
        switch self {
        case .fast: return "fast"
        case .balanced: return "balanced"
        case .accurate: return "accurate"
        }
    }
}

extension Language: RawRepresentable {
    public init?(rawValue: String) {
        switch rawValue {
        case "en": self = .english
        case "es": self = .spanish
        case "fr": self = .french
        case "de": self = .german
        case "it": self = .italian
        case "pt": self = .portuguese
        case "nl": self = .dutch
        case "pl": self = .polish
        case "ru": self = .russian
        case "zh": self = .chinese
        case "ja": self = .japanese
        case "ko": self = .korean
        case "ar": self = .arabic
        case "hi": self = .hindi
        case "tr": self = .turkish
        case "vi": self = .vietnamese
        case "id": self = .indonesian
        case "th": self = .thai
        case "sv": self = .swedish
        case "no": self = .norwegian
        case "da": self = .danish
        case "fi": self = .finnish
        case "el": self = .greek
        case "cs": self = .czech
        case "ro": self = .romanian
        case "hu": self = .hungarian
        case "uk": self = .ukrainian
        case "he": self = .hebrew
        case "ms": self = .malay
        case "tl": self = .tagalog
        default: return nil
        }
    }
    
    public var rawValue: String {
        return self.code
    }
}