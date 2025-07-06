//
//  MockAudioProcessor.swift
//  VoiceType
//
//  Mock implementation of AudioProcessor for testing
//

import Foundation
import AVFoundation
import VoiceTypeCore

/// Mock audio processor for testing purposes
public final class MockAudioProcessor: AudioProcessor {
    
    // MARK: - Properties
    
    private let configuration: AudioProcessorConfiguration
    private var _recordingState: RecordingState = .idle
    private let stateQueue = DispatchQueue(label: "com.voicetype.mock.audio.state")
    
    // Publishers
    private let recordingStateContinuation: AsyncStream<RecordingState>.Continuation
    private let audioLevelContinuation: AsyncStream<Float>.Continuation
    
    public let recordingStatePublisher: AsyncStream<RecordingState>
    public let audioLevelPublisher: AsyncStream<Float>
    
    public var recordingState: RecordingState {
        stateQueue.sync { _recordingState }
    }
    
    // MARK: - Protocol Conformance
    
    public var isRecording: Bool {
        stateQueue.sync { _recordingState == .recording }
    }
    
    public var audioLevelChanged: AsyncStream<Float> {
        audioLevelPublisher
    }
    
    public var recordingStateChanged: AsyncStream<RecordingState> {
        recordingStatePublisher
    }
    
    // Mock control properties
    public var mockPermissionStatus: AVAuthorizationStatus = .authorized
    public var shouldFailToStart = false
    public var shouldFailDuringRecording = false
    public var mockAudioData: AudioData?
    public var simulateDeviceDisconnection = false
    public var simulatePermissionRevocation = false
    
    private var recordingTimer: Timer?
    private var audioLevelTimer: Timer?
    private var recordingCompletion: ((Result<AudioData, AudioProcessorError>) -> Void)?
    
    // MARK: - Initialization
    
    public init(configuration: AudioProcessorConfiguration = .voiceTypeMVP) {
        self.configuration = configuration
        
        // Initialize async streams
        var stateContinuation: AsyncStream<RecordingState>.Continuation!
        self.recordingStatePublisher = AsyncStream<RecordingState> { continuation in
            stateContinuation = continuation
        }
        self.recordingStateContinuation = stateContinuation
        
        var levelContinuation: AsyncStream<Float>.Continuation!
        self.audioLevelPublisher = AsyncStream<Float> { continuation in
            levelContinuation = continuation
        }
        self.audioLevelContinuation = levelContinuation
        
        // Generate default mock audio data
        generateDefaultMockData()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - AudioProcessor Protocol
    
    public func startRecording() async throws {
        try await startRecordingInternal(maxDuration: 5.0)
    }
    
    private func startRecordingInternal(maxDuration: TimeInterval = 5.0) async throws {
        // Check state
        guard recordingState == .idle else {
            throw AudioProcessorError.systemError("Recording already in progress")
        }
        
        // Check mock permission
        guard mockPermissionStatus == .authorized else {
            if mockPermissionStatus == .denied {
                throw AudioProcessorError.permissionDenied
            } else if mockPermissionStatus == .restricted {
                throw AudioProcessorError.permissionDenied
            } else {
                throw AudioProcessorError.permissionDenied
            }
        }
        
        // Simulate failure to start
        if shouldFailToStart {
            let error = NSError(domain: "VoiceType", code: -100, userInfo: [NSLocalizedDescriptionKey: "Mock audio engine start failure"])
            updateRecordingState(.error("Mock audio engine start failure"))
            throw AudioProcessorError.systemError("Audio engine start failed: \(error.localizedDescription)")
        }
        
        // Start recording
        updateRecordingState(.recording)
        // Recording started
        
        // Start timers
        startRecordingTimer(duration: min(maxDuration, 5.0))
        startAudioLevelSimulation()
        
        // Simulate device disconnection after 1 second
        if simulateDeviceDisconnection {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.simulateDeviceDisconnected()
            }
        }
        
        // Simulate permission revocation after 2 seconds
        if simulatePermissionRevocation {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.simulatePermissionRevoked()
            }
        }
        
        // Simulate recording failure after 1.5 seconds
        if shouldFailDuringRecording {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.simulateRecordingFailure()
            }
        }
    }
    
    public func stopRecording() async -> AudioData {
        guard recordingState == .recording else {
            return mockAudioData ?? generateDefaultAudioData()
        }
        
        stopRecordingInternal(success: true)
        return mockAudioData ?? generateDefaultAudioData()
    }
    
    public func requestMicrophonePermission() async -> Bool {
        // Simulate async permission request
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        if mockPermissionStatus == .notDetermined {
            mockPermissionStatus = .authorized // Grant permission by default in tests
        }
        
        return mockPermissionStatus == .authorized
    }
    
    public func checkMicrophonePermission() -> AVAuthorizationStatus {
        return mockPermissionStatus
    }
    
    public func cleanup() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        recordingStateContinuation.finish()
        audioLevelContinuation.finish()
    }
    
    // MARK: - Mock Helpers
    
    /// Load audio data from a test file
    public func loadTestAudioFile(named fileName: String, withExtension ext: String = "wav") -> Bool {
        // In a real implementation, this would load actual audio file data
        // For now, we'll generate synthetic data
        generateSyntheticAudioData(duration: 3.0)
        return true
    }
    
    /// Generate synthetic audio data for testing
    public func generateSyntheticAudioData(duration: TimeInterval, frequency: Double = 440.0) {
        let sampleCount = Int(configuration.sampleRate * duration)
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)
        
        // Generate a sine wave
        let amplitude: Double = 0.3
        let angularFrequency = 2.0 * Double.pi * frequency
        
        for i in 0..<sampleCount {
            let time = Double(i) / configuration.sampleRate
            let sample = amplitude * sin(angularFrequency * time)
            let int16Sample = Int16(sample * Double(Int16.max))
            samples.append(int16Sample)
        }
        
        mockAudioData = AudioData(
            samples: samples,
            sampleRate: configuration.sampleRate,
            channelCount: configuration.channelCount,
            timestamp: Date()
        )
    }
    
    /// Reset mock to initial state
    public func reset() {
        cleanup()
        updateRecordingState(.idle)
        mockPermissionStatus = .authorized
        shouldFailToStart = false
        shouldFailDuringRecording = false
        simulateDeviceDisconnection = false
        simulatePermissionRevocation = false
        generateDefaultMockData()
    }
    
    // MARK: - Private Methods
    
    private func generateDefaultMockData() {
        // Generate 2 seconds of test audio
        generateSyntheticAudioData(duration: 2.0, frequency: 440.0)
    }
    
    private func generateDefaultAudioData() -> AudioData {
        if mockAudioData == nil {
            generateDefaultMockData()
        }
        return mockAudioData!
    }
    
    private func updateRecordingState(_ newState: RecordingState) {
        stateQueue.async { [weak self] in
            self?._recordingState = newState
            self?.recordingStateContinuation.yield(newState)
        }
    }
    
    private func startRecordingTimer(duration: TimeInterval) {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.stopRecordingInternal(success: true)
        }
    }
    
    private func startAudioLevelSimulation() {
        var phase: Double = 0.0
        
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Simulate varying audio levels
            phase += 0.2
            let baseLevel = 0.3 + 0.2 * sin(phase)
            let noise = Double.random(in: -0.05...0.05)
            let level = Float(max(0.0, min(1.0, baseLevel + noise)))
            
            self.audioLevelContinuation.yield(level)
        }
    }
    
    private func stopRecordingInternal(success: Bool) {
        updateRecordingState(.processing)
        
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        if success, let audioData = mockAudioData {
            recordingCompletion?(.success(audioData))
        } else {
            recordingCompletion?(.failure(.systemError("Mock recording failed")))
        }
        
        updateRecordingState(.idle)
        recordingCompletion = nil
    }
    
    private func simulateDeviceDisconnected() {
        guard recordingState == .recording else { return }
        
        updateRecordingState(.error("Audio device not available"))
        recordingCompletion?(.failure(.deviceDisconnected))
        stopRecordingInternal(success: false)
    }
    
    private func simulatePermissionRevoked() {
        guard recordingState == .recording else { return }
        
        mockPermissionStatus = .denied
        updateRecordingState(.error("Permission revoked"))
        recordingCompletion?(.failure(.permissionDenied))
        stopRecordingInternal(success: false)
    }
    
    private func simulateRecordingFailure() {
        guard recordingState == .recording else { return }
        
        let error = NSError(domain: "VoiceType", code: -200, userInfo: [NSLocalizedDescriptionKey: "Simulated recording failure"])
        updateRecordingState(.error("Recording failed: \(error.localizedDescription)"))
        recordingCompletion?(.failure(.systemError(error.localizedDescription)))
        stopRecordingInternal(success: false)
    }
}

// MARK: - Testing Extensions

public extension MockAudioProcessor {
    
    /// Simulate various audio patterns for testing
    enum TestAudioPattern {
        case silence
        case sineWave(frequency: Double)
        case whiteNoise
        case speech
        case music
    }
    
    /// Generate audio data with specific test pattern
    func generateTestPattern(_ pattern: TestAudioPattern, duration: TimeInterval) {
        let sampleCount = Int(configuration.sampleRate * duration)
        var samples = [Int16]()
        samples.reserveCapacity(sampleCount)
        
        switch pattern {
        case .silence:
            samples = Array(repeating: 0, count: sampleCount)
            
        case .sineWave(let frequency):
            generateSyntheticAudioData(duration: duration, frequency: frequency)
            return
            
        case .whiteNoise:
            for _ in 0..<sampleCount {
                let noise = Double.random(in: -0.5...0.5)
                samples.append(Int16(noise * Double(Int16.max)))
            }
            
        case .speech:
            // Simulate speech-like pattern with formants
            for i in 0..<sampleCount {
                let time = Double(i) / configuration.sampleRate
                var sample = 0.0
                
                // Fundamental frequency (pitch)
                sample += 0.3 * sin(2 * Double.pi * 120 * time)
                
                // Formants
                sample += 0.2 * sin(2 * Double.pi * 700 * time)
                sample += 0.15 * sin(2 * Double.pi * 1220 * time)
                sample += 0.1 * sin(2 * Double.pi * 2600 * time)
                
                // Add some noise
                sample += 0.05 * Double.random(in: -1...1)
                
                samples.append(Int16(sample * Double(Int16.max) * 0.5))
            }
            
        case .music:
            // Simulate simple chord progression
            for i in 0..<sampleCount {
                let time = Double(i) / configuration.sampleRate
                var sample = 0.0
                
                // C major chord (C, E, G)
                sample += 0.3 * sin(2 * Double.pi * 261.63 * time) // C4
                sample += 0.3 * sin(2 * Double.pi * 329.63 * time) // E4
                sample += 0.3 * sin(2 * Double.pi * 392.00 * time) // G4
                
                samples.append(Int16(sample * Double(Int16.max) * 0.3))
            }
        }
        
        mockAudioData = AudioData(
            samples: samples,
            sampleRate: configuration.sampleRate,
            channelCount: configuration.channelCount,
            timestamp: Date()
        )
    }
}