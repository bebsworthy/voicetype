import Foundation
import Combine
import SwiftUI
import AVFoundation
import AppKit
import VoiceTypeCore

/// Main coordinator that manages app state and orchestrates all operations
///
/// This coordinator is responsible for:
/// - Managing the complete dictation workflow (hotkey → record → process → inject)
/// - Coordinating all components (audio, transcription, text injection)
/// - Managing app state with atomic transitions
/// - Handling errors with recovery strategies
/// - Managing component lifecycle and dependencies
@MainActor
public class VoiceTypeCoordinator: ObservableObject {
    // MARK: - Published Properties

    /// Current state of the recording/transcription process
    @Published public private(set) var recordingState: RecordingState = .idle

    /// Selected dynamic model ID for transcription
    @Published public var selectedModelId: String?
    

    /// Last successful transcription result
    @Published public private(set) var lastTranscription: String = ""

    /// Current error message (if any)
    @Published public private(set) var errorMessage: String?

    /// Recording progress (0.0 to 1.0)
    @Published public private(set) var recordingProgress: Double = 0.0

    /// Whether the app is ready to record
    @Published public private(set) var isReady: Bool = false

    /// Audio level for visual feedback (0.0 to 1.0)
    @Published public private(set) var audioLevel: Float = 0.0

    /// Whether accessibility permission is granted
    @Published public private(set) var hasAccessibilityPermission: Bool = false

    /// Whether microphone permission is granted
    @Published public private(set) var hasMicrophonePermission: Bool = false

    /// Current audio device being used
    @Published public private(set) var currentAudioDevice: String?

    /// Model loading state
    @Published public private(set) var isLoadingModel: Bool = false

    /// Model loading progress (0.0 to 1.0)
    @Published public private(set) var modelLoadingProgress: Double = 0.0

    /// Model loading status message
    @Published public private(set) var modelLoadingStatus: String?

    // MARK: - Dependencies

    private var audioProcessor: AudioProcessor
    private let transcriber: Transcriber
    private let textInjector: TextInjector
    private let permissionManager: PermissionManager
    private let hotkeyManager: HotkeyManager
    private let modelManager: ModelManager

    // MARK: - Private Properties

    private var recordingTimer: Timer?
    private var recordingStartTime: Date?
    private var settingsManager: SettingsManager?
    private var cancellables = Set<AnyCancellable>()

    // State management
    private let stateQueue = DispatchQueue(label: "com.voicetype.coordinator.state")
    private var isProcessing = false

    // Error recovery
    private var errorRecoveryAttempts = 0
    private let maxErrorRecoveryAttempts = 3

    // Component health monitoring
    private var componentHealthTimer: Timer?
    private var lastHealthCheck = Date()
    
    // Computed property for max recording duration
    private var maxRecordingDuration: TimeInterval {
        TimeInterval(settingsManager?.maxRecordingDuration ?? 30)
    }

    // MARK: - Initialization

    public init(
        audioProcessor: AudioProcessor? = nil,
        transcriber: Transcriber? = nil,
        textInjector: TextInjector? = nil,
        permissionManager: PermissionManager? = nil,
        hotkeyManager: HotkeyManager? = nil,
        modelManager: ModelManager? = nil
    ) {
        // Use real implementations by default, allow injection for testing
        // Create audio processor with extended buffer for longer recordings
        let audioConfig = AudioProcessorConfiguration(
            sampleRate: 16000,
            channelCount: 1,
            bitDepth: 16,
            bufferSize: 1024,
            maxRecordingDuration: 60.0  // Support up to 60 seconds
        )
        self.audioProcessor = audioProcessor ?? AVFoundationAudio(configuration: audioConfig)
        self.transcriber = transcriber ?? TranscriberFactory.createDefault()
        self.textInjector = textInjector ?? AccessibilityInjector()
        self.permissionManager = permissionManager ?? PermissionManager()
        self.hotkeyManager = hotkeyManager ?? HotkeyManager()
        self.modelManager = modelManager ?? ModelManager()

        setupBindings()
        Task {
            await initialize()
        }
    }

    // MARK: - Public Methods
    
    /// Reinitialize the audio processor with updated configuration
    public func reinitializeAudioProcessor() async {
        // Don't reinitialize during active operations
        guard recordingState == .idle else {
            errorMessage = "Cannot change audio settings while recording or processing"
            return
        }
        
        // Get the updated max recording duration
        let maxDuration = TimeInterval(settingsManager?.maxRecordingDuration ?? 30)
        
        // Create new audio processor with updated configuration
        let audioConfig = AudioProcessorConfiguration(
            sampleRate: 16000,
            channelCount: 1,
            bitDepth: 16,
            bufferSize: 1024,
            maxRecordingDuration: maxDuration
        )
        
        // Clean up old audio processor
        audioProcessor.cleanup()
        
        // Create new instance
        audioProcessor = AVFoundationAudio(configuration: audioConfig)
        
        // Re-setup audio processor bindings
        Task {
            for await state in audioProcessor.recordingStateChanged {
                await MainActor.run {
                    handleAudioStateChange(state)
                }
            }
        }
        
        Task {
            for await level in audioProcessor.audioLevelChanged {
                await MainActor.run {
                    audioLevel = level
                }
            }
        }
        
        // Update ready state
        updateReadyState()
    }

    /// Start voice dictation
    public func startDictation() async {
        // Ensure atomic state transition
        guard await transitionToState(.recording) else {
            return
        }

        do {
            // Reset state
            errorMessage = nil
            recordingProgress = 0.0
            errorRecoveryAttempts = 0

            // Check permissions
            guard await checkPermissions() else {
                await transitionToState(.error("Microphone permission required"))
                errorMessage = "Microphone permission is required to record audio"
                return
            }

            // Verify model is loaded
            guard transcriber.isModelLoaded else {
                await transitionToState(.error("No model loaded"))
                errorMessage = "Please wait for the AI model to load"
                // Attempt to load model
                Task {
                    await loadSelectedModel()
                }
                return
            }

            // Update state
            recordingStartTime = Date()

            // Start recording
            try await audioProcessor.startRecording()

            // Start progress timer
            startProgressTimer()
        } catch {
            await handleError(error, duringOperation: .recording)
        }
    }

    /// Stop voice dictation and process the audio
    public func stopDictation() async {
        guard recordingState == .recording else { return }

        // Stop progress timer
        stopProgressTimer()

        // Transition to processing state
        guard await transitionToState(.processing) else {
            return
        }

        do {
            // Stop recording and get audio data
            let audioData = await audioProcessor.stopRecording()

            // Validate audio data
            guard !audioData.samples.isEmpty else {
                throw VoiceTypeError.invalidAudioData
            }

            // Transcribe audio
            let result = try await transcriber.transcribe(audioData, language: selectedLanguage)

            // Validate transcription quality
            if result.confidence < 0.5 {
                throw VoiceTypeError.lowConfidenceTranscription(result.confidence)
            }

            // Store transcription
            lastTranscription = result.text

            // Inject text into focused application
            await injectTranscription(result.text)
        } catch {
            await handleError(error, duringOperation: .transcription)
        }
    }

    /// Change the selected model
    public func changeModel(_ modelId: String) async {
        // Don't change model during active operations
        guard case .idle = recordingState else {
            errorMessage = "Cannot change model while recording or processing"
            return
        }

        selectedModelId = modelId
        UserDefaults.standard.set(modelId, forKey: "selectedModelId")

        // Load the new model
        await loadSelectedModel()
    }

    /// Load the currently selected model
    public func loadSelectedModel() async {
        guard let modelId = selectedModelId else {
            // Try to load default model
            selectedModelId = "openai_whisper-tiny"
            await loadSelectedModel()
            return
        }
        
        await loadDynamicModel(modelId: modelId)
    }
    
    /// Load a dynamic WhisperKit model by ID
    public func loadDynamicModel(modelId: String) async {
        // Don't change model during active operations
        guard case .idle = recordingState else {
            errorMessage = "Cannot change model while recording or processing"
            return
        }
        
        selectedModelId = modelId
        UserDefaults.standard.set(modelId, forKey: "selectedModelId")
        
        // Set loading state
        isLoadingModel = true
        modelLoadingProgress = 0.0
        modelLoadingStatus = "Loading model \(modelId)..."
        
        defer {
            isLoadingModel = false
            modelLoadingProgress = 0.0
            modelLoadingStatus = nil
        }
        
        // Check if model needs to be downloaded
        let modelManager = WhisperKitModelManager()
        if !modelManager.isDynamicModelDownloaded(modelId: modelId) {
            modelLoadingStatus = "Model needs to be downloaded"
            errorMessage = "Model \(modelId) needs to be downloaded first. Please go to Settings > Models to download it."
            isReady = false
            return
        }
        
        do {
            modelLoadingStatus = "Loading \(modelId) model..."
            modelLoadingProgress = 0.3
            
            // Load the model using the transcriber
            try await transcriber.loadModel(modelId)
            
            modelLoadingProgress = 1.0
            modelLoadingStatus = "Model loaded successfully"
            
            // Brief pause to show completion
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            errorMessage = nil
            updateReadyState()
        } catch {
            await handleError(error, duringOperation: .modelLoading)
        }
    }

    /// Check if all required permissions are granted
    public func checkAllPermissions() async -> Bool {
        permissionManager.checkMicrophonePermission()
        let micPermission = permissionManager.microphonePermission == .granted
        let accessPermission = permissionManager.hasAccessibilityPermission()

        hasMicrophonePermission = micPermission
        hasAccessibilityPermission = accessPermission

        // Microphone is required, accessibility is optional (fallback to clipboard)
        return micPermission
    }

    /// Request all necessary permissions
    public func requestPermissions() async {
        // Request microphone permission
        if !hasMicrophonePermission {
            _ = await permissionManager.requestMicrophonePermission()
        }

        // Check accessibility (don't request, just check)
        _ = permissionManager.hasAccessibilityPermission()
    }
    
    /// Update the global hotkey
    public func updateHotkey(_ newHotkey: String) async {
        // Stop any active recording first
        if recordingState == .recording {
            await stopDictation()
            // Wait a moment for cleanup
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Save to UserDefaults
        UserDefaults.standard.set(newHotkey, forKey: "globalHotkey")
        
        // Unregister old hotkey
        hotkeyManager.unregisterHotkey(identifier: HotkeyManager.HotkeyPreset.toggleRecording.identifier)
        
        // Register new hotkey
        do {
            try hotkeyManager.registerPushToTalkHotkey(
                identifier: HotkeyManager.HotkeyPreset.toggleRecording.identifier,
                keyCombo: newHotkey,
                onPress: { [weak self] in
                    Task { @MainActor in
                        await self?.handleHotkeyPress()
                    }
                },
                onRelease: { [weak self] in
                    Task { @MainActor in
                        await self?.handleHotkeyRelease()
                    }
                }
            )
            errorMessage = nil
        } catch {
            errorMessage = "Failed to register hotkey: \(error.localizedDescription)"
            
            // If it's an accessibility permission issue, guide the user
            if case HotkeyError.accessibilityPermissionRequired = error {
                await MainActor.run {
                    permissionManager.showAccessibilityPermissionGuide()
                }
            }
            
            // Try to re-register the old hotkey
            let oldHotkey = UserDefaults.standard.string(forKey: "globalHotkey") ?? HotkeyManager.HotkeyPreset.toggleRecording.defaultKeyCombo
            UserDefaults.standard.set(oldHotkey, forKey: "globalHotkey")
            await setupHotkey()
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Listen to audio processor state changes
        Task {
            for await state in audioProcessor.recordingStateChanged {
                await MainActor.run {
                    handleAudioStateChange(state)
                }
            }
        }

        // Listen to audio level changes for visual feedback
        Task {
            for await level in audioProcessor.audioLevelChanged {
                await MainActor.run {
                    audioLevel = level
                }
            }
        }

        // Monitor permission changes
        permissionManager.$microphonePermission
            .sink { [weak self] state in
                Task { @MainActor in
                    self?.hasMicrophonePermission = state == .granted
                    self?.updateReadyState()
                }
            }
            .store(in: &cancellables)

        permissionManager.$accessibilityPermission
            .sink { [weak self] state in
                Task { @MainActor in
                    self?.hasAccessibilityPermission = state == .granted
                }
            }
            .store(in: &cancellables)

        // Monitor model changes
        modelManager.$installedModels
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateReadyState()
                }
            }
            .store(in: &cancellables)

        // Start component health monitoring
        startHealthMonitoring()
    }

    private func initialize() async {
        // Initialize settings manager
        settingsManager = SettingsManager()
        
        // Load saved model ID
        if let savedModelId = UserDefaults.standard.string(forKey: "selectedModelId") {
            selectedModelId = savedModelId
        } else {
            // Default to fast model
            selectedModelId = "openai_whisper-tiny"
        }

        // Load the selected model
        await loadSelectedModel()

        // Setup hotkey
        await setupHotkey()

        // Update ready state
        updateReadyState()
    }


    private func checkPermissions() async -> Bool {
        permissionManager.checkMicrophonePermission()
        if permissionManager.microphonePermission != .granted {
            let granted = await permissionManager.requestMicrophonePermission()
            if !granted {
                // Show permission guide
                await MainActor.run {
                    permissionManager.showPermissionDeniedAlert(for: .microphone)
                }
            }
            return granted
        }
        return true
    }

    private func setupHotkey() async {
        let hotkey = UserDefaults.standard.string(forKey: "globalHotkey") ?? HotkeyManager.HotkeyPreset.toggleRecording.defaultKeyCombo

        do {
            try hotkeyManager.registerPushToTalkHotkey(
                identifier: HotkeyManager.HotkeyPreset.toggleRecording.identifier,
                keyCombo: hotkey,
                onPress: { [weak self] in
                    Task { @MainActor in
                        await self?.handleHotkeyPress()
                    }
                },
                onRelease: { [weak self] in
                    Task { @MainActor in
                        await self?.handleHotkeyRelease()
                    }
                }
            )
        } catch {
            errorMessage = "Failed to register hotkey: \(error.localizedDescription)"

            // If it's an accessibility permission issue, guide the user
            if case HotkeyError.accessibilityPermissionRequired = error {
                await MainActor.run {
                    permissionManager.showAccessibilityPermissionGuide()
                }
            }
        }
    }

    /// Handle hotkey press (push-to-talk start)
    private func handleHotkeyPress() async {
        switch recordingState {
        case .idle, .success, .error:
            // Start recording when key is pressed
            await startDictation()
        case .recording:
            // Already recording, ignore
            break
        case .processing:
            // Ignore during processing
            break
        }
    }
    
    /// Handle hotkey release (push-to-talk stop)
    private func handleHotkeyRelease() async {
        switch recordingState {
        case .recording:
            // Stop recording when key is released
            await stopDictation()
        case .idle, .success, .error, .processing:
            // Not recording, ignore
            break
        }
    }

    private func startProgressTimer() {
        recordingProgress = 0.0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      let startTime = self.recordingStartTime else { return }

                let elapsed = Date().timeIntervalSince(startTime)
                self.recordingProgress = min(elapsed / self.maxRecordingDuration, 1.0)

                // Auto-stop after max duration
                if elapsed >= self.maxRecordingDuration {
                    await self.stopDictation()
                }
            }
        }
    }

    private func stopProgressTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingProgress = 0.0
        recordingStartTime = nil
    }

    // MARK: - State Management

    /// Atomically transition to a new state
    private func transitionToState(_ newState: RecordingState) async -> Bool {
        await withCheckedContinuation { continuation in
            stateQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: false)
                    return
                }

                // Validate state transition
                let isValidTransition = self.isValidStateTransition(from: self.recordingState, to: newState)

                if isValidTransition {
                    Task { @MainActor in
                        self.recordingState = newState
                    }
                }

                continuation.resume(returning: isValidTransition)
            }
        }
    }

    /// Check if a state transition is valid
    private func isValidStateTransition(from currentState: RecordingState, to newState: RecordingState) -> Bool {
        switch (currentState, newState) {
        case (.idle, .recording),
             (.recording, .processing),
             (.recording, .idle),
             (.recording, .error),
             (.processing, .success),
             (.processing, .error),
             (.success, .idle),
             (.success, .recording),  // Allow starting new recording from success
             (.error, .idle),
             (.error, .recording):
            return true
        default:
            return false
        }
    }

    /// Handle audio state changes from the audio processor
    private func handleAudioStateChange(_ state: RecordingState) {
        // Only update if we're not already processing
        if recordingState != .processing {
            Task {
                await transitionToState(state)
            }
        }
    }

    // MARK: - Error Handling

    /// Operation types for error handling
    private enum Operation {
        case recording
        case transcription
        case textInjection
        case modelLoading
    }

    /// Handle errors with recovery strategies
    private func handleError(_ error: Error, duringOperation operation: Operation) async {
        errorRecoveryAttempts += 1

        // Convert to VoiceTypeError if needed
        let voiceTypeError: VoiceTypeError
        if let vte = error as? VoiceTypeError {
            voiceTypeError = vte
        } else {
            voiceTypeError = .unknown(error.localizedDescription)
        }

        // Log error for debugging
        print("[VoiceTypeCoordinator] Error during \(operation): \(voiceTypeError)")

        // Apply recovery strategy
        switch voiceTypeError {
        case .microphonePermissionDenied:
            await transitionToState(.error(voiceTypeError.localizedDescription))
            errorMessage = voiceTypeError.localizedDescription
            await MainActor.run {
                permissionManager.showPermissionDeniedAlert(for: .microphone)
            }

        case .audioDeviceDisconnected:
            await transitionToState(.error("Audio device disconnected"))
            errorMessage = "Your audio device was disconnected. Please reconnect and try again."
            // Monitor for device reconnection
            startAudioDeviceMonitoring()

        case .modelNotFound, .modelLoadingFailed:
            await transitionToState(.error("Model loading failed"))
            errorMessage = voiceTypeError.localizedDescription
            // Try fallback model
            if selectedModelId != "openai_whisper-tiny" && errorRecoveryAttempts < maxErrorRecoveryAttempts {
                await changeModel("openai_whisper-tiny")
            }

        case .noFocusedApplication, .unsupportedApplication:
            // Don't transition to error state, just use clipboard fallback
            errorMessage = "Text copied to clipboard. Press ⌘V to paste."
            // Copy to clipboard
            if !lastTranscription.isEmpty {
                await copyToClipboard(lastTranscription)
            }
            await transitionToState(.success)

        case .networkUnavailable:
            await transitionToState(.error("Network unavailable"))
            errorMessage = "Network is required for model downloads. Please check your connection."

        default:
            await transitionToState(.error(voiceTypeError.localizedDescription))
            errorMessage = voiceTypeError.recoverySuggestion ?? voiceTypeError.localizedDescription
        }

        // Reset to idle after delay if in error state
        if case .error = recordingState {
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                if case .error = recordingState {
                    await transitionToState(.idle)
                }
            }
        }
    }

    // MARK: - Text Injection

    /// Inject transcription with fallback strategies
    private func injectTranscription(_ text: String) async {
        await withCheckedContinuation { continuation in
            textInjector.inject(text: text) { [weak self] result in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }

                    switch result {
                    case .success:
                        await self.transitionToState(.success)
                        self.errorMessage = nil

                        // Reset to idle after brief success display
                        Task {
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            if self.recordingState == .success {
                                await self.transitionToState(.idle)
                            }
                        }

                    case .failure(let error):
                        // If injection fails, fallback to clipboard
                        await self.copyToClipboard(text)

                        if case .noFocusedElement = error {
                            self.errorMessage = "Text copied to clipboard. Press ⌘V to paste."
                        } else {
                            self.errorMessage = "Text injection failed. Text copied to clipboard instead."
                        }

                        await self.transitionToState(.success)

                        // Still count as success since user has the text
                        Task {
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            if self.recordingState == .success {
                                await self.transitionToState(.idle)
                            }
                        }
                    }

                    continuation.resume()
                }
            }
        }
    }

    /// Copy text to clipboard
    private func copyToClipboard(_ text: String) async {
        await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }
    }

    // MARK: - Component Health Monitoring

    /// Start monitoring component health
    private func startHealthMonitoring() {
        componentHealthTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkComponentHealth()
            }
        }
    }

    /// Check health of all components
    private func checkComponentHealth() async {
        lastHealthCheck = Date()

        // Check audio processor
        if audioProcessor.isRecording && recordingState != .recording {
            // State mismatch, reset
            await audioProcessor.stopRecording()
        }

        // Check model status
        if !transcriber.isModelLoaded && isReady {
            isReady = false
            await loadSelectedModel()
        }

        // Check permissions periodically
        _ = await checkAllPermissions()
    }

    /// Start monitoring for audio device reconnection
    private func startAudioDeviceMonitoring() {
        // Monitor audio device changes on macOS
        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasConnected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleAudioRouteChange(notification)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .AVCaptureDeviceWasDisconnected,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                await self?.handleAudioRouteChange(notification)
            }
        }

        // Update current device on startup
        updateCurrentAudioDevice()
    }

    /// Handle audio route changes
    private func handleAudioRouteChange(_ notification: Notification) async {
        // On macOS, handle device changes differently
        if notification.name == .AVCaptureDeviceWasConnected {
            // New device connected
            if case .error = recordingState {
                errorMessage = "Audio device reconnected. Ready to record."
                await transitionToState(.idle)
            }
            updateCurrentAudioDevice()
        } else if notification.name == .AVCaptureDeviceWasDisconnected {
            // Device disconnected
            currentAudioDevice = nil
        }
    }

    /// Update current audio device name
    private func updateCurrentAudioDevice() {
        // On macOS, use AVCaptureDevice
        let devices = AVCaptureDevice.devices(for: .audio)
        currentAudioDevice = devices.first { $0.isConnected }?.localizedName
    }

    /// Update the ready state based on component status
    private func updateReadyState() {
        guard let modelId = selectedModelId else {
            isReady = false
            return
        }
        
        let modelManager = WhisperKitModelManager()
        isReady = hasMicrophonePermission &&
                  transcriber.isModelLoaded &&
                  modelManager.isDynamicModelDownloaded(modelId: modelId)
    }

    // MARK: - Public Properties

    /// Selected language for transcription
    public var selectedLanguage: Language? {
        get {
            if let languageString = UserDefaults.standard.string(forKey: "selectedLanguage"),
               let language = Language(rawValue: languageString) {
                return language
            }
            return nil
        }
        set {
            if let language = newValue {
                UserDefaults.standard.set(language.rawValue, forKey: "selectedLanguage")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedLanguage")
            }
        }
    }

    /// Get a summary of the current app state
    public var stateSummary: String {
        switch recordingState {
        case .idle:
            return isReady ? "Ready to record" : "Preparing..."
        case .recording:
            return "Recording... (\(Int(recordingProgress * 100))%)"
        case .processing:
            return "Processing audio..."
        case .success:
            return "Transcription complete"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - Settings Manager Reference

/// Simple settings manager for menu bar view
@MainActor
public class SettingsManager: ObservableObject {
    @Published public var selectedModelId: String? {
        didSet {
            if let modelId = selectedModelId {
                UserDefaults.standard.set(modelId, forKey: "selectedModelId")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedModelId")
            }
        }
    }

    @Published public var globalHotkey: String {
        didSet {
            UserDefaults.standard.set(globalHotkey, forKey: "globalHotkey")
        }
    }

    @Published public var selectedLanguage: Language? {
        didSet {
            if let language = selectedLanguage {
                UserDefaults.standard.set(language.rawValue, forKey: "selectedLanguage")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedLanguage")
            }
        }
    }
    
    @Published public var maxRecordingDuration: Int {
        didSet {
            UserDefaults.standard.set(maxRecordingDuration, forKey: "maxRecordingDuration")
        }
    }

    public init() {
        // Load saved preferences
        self.selectedModelId = UserDefaults.standard.string(forKey: "selectedModelId") ?? "openai_whisper-tiny"

        self.globalHotkey = UserDefaults.standard.string(forKey: "globalHotkey") ?? "ctrl+shift+v"
        
        // Load max recording duration with default of 30 seconds
        self.maxRecordingDuration = UserDefaults.standard.object(forKey: "maxRecordingDuration") as? Int ?? 30

        if let languageString = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = Language(rawValue: languageString) {
            self.selectedLanguage = language
        } else {
            self.selectedLanguage = nil // Auto-detect
        }
    }
}
