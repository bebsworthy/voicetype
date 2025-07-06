//
//  AVFoundationAudio.swift
//  VoiceType
//
//  AVFoundation-based implementation of AudioProcessor for real audio recording
//

import Foundation
import AVFoundation
import Combine

/// AVFoundation-based audio processor implementation
public final class AVFoundationAudio: AudioProcessor {
    
    // MARK: - Properties
    
    private let configuration: AudioProcessorConfiguration
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    
    private var recordingTimer: Timer?
    private var recordingCompletion: ((Result<AudioData, AudioProcessorError>) -> Void)?
    private var recordingStartTime: Date?
    
    // Audio buffer management
    private var audioBuffer: CircularBuffer<Int16>
    private let bufferQueue = DispatchQueue(label: "com.voicetype.audio.buffer", attributes: .concurrent)
    
    // State management
    private var _recordingState: RecordingState = .idle
    private let stateQueue = DispatchQueue(label: "com.voicetype.audio.state")
    
    // Publishers
    private let recordingStateContinuation: AsyncStream<RecordingState>.Continuation
    private let audioLevelContinuation: AsyncStream<Float>.Continuation
    
    public let recordingStatePublisher: AsyncStream<RecordingState>
    public let audioLevelPublisher: AsyncStream<Float>
    
    public var recordingState: RecordingState {
        stateQueue.sync { _recordingState }
    }
    
    // Audio level tracking
    private var audioLevelTimer: Timer?
    private var currentAudioLevel: Float = 0.0
    
    // MARK: - Initialization
    
    public init(configuration: AudioProcessorConfiguration = .voiceTypeMVP) {
        self.configuration = configuration
        
        // Calculate buffer size for max recording duration
        let maxSamples = Int(configuration.sampleRate * configuration.maxRecordingDuration) * configuration.channelCount
        self.audioBuffer = CircularBuffer<Int16>(capacity: maxSamples)
        
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
        
        setupAudioSession()
        setupNotifications()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(false)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupNotifications() {
        // Monitor audio route changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
        
        // Monitor interruptions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
    }
    
    // MARK: - AudioProcessor Protocol
    
    public func startRecording(maxDuration: TimeInterval = 5.0, completion: @escaping (Result<AudioData, AudioProcessorError>) -> Void) async throws {
        // Check state
        guard recordingState == .idle else {
            throw AudioProcessorError.recordingFailed(NSError(domain: "VoiceType", code: -1, userInfo: [NSLocalizedDescriptionKey: "Recording already in progress"]))
        }
        
        // Check permission
        let permission = checkMicrophonePermission()
        guard permission == .authorized else {
            if permission == .denied {
                throw AudioProcessorError.microphoneAccessDenied
            } else if permission == .restricted {
                throw AudioProcessorError.microphoneAccessRestricted
            } else {
                let granted = await requestMicrophonePermission()
                if !granted {
                    throw AudioProcessorError.microphoneAccessDenied
                }
            }
        }
        
        // Update state
        updateRecordingState(.recording)
        recordingCompletion = completion
        recordingStartTime = Date()
        
        // Clear buffer
        bufferQueue.async(flags: .barrier) {
            self.audioBuffer.clear()
        }
        
        do {
            // Activate audio session
            try audioSession.setActive(true)
            
            // Configure audio format
            let inputNode = audioEngine.inputNode
            let recordingFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: configuration.sampleRate,
                channels: AVAudioChannelCount(configuration.channelCount),
                interleaved: true
            )
            
            guard let format = recordingFormat else {
                throw AudioProcessorError.invalidAudioFormat
            }
            
            // Install tap on input node
            inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(configuration.bufferSize), format: format) { [weak self] buffer, time in
                self?.processAudioBuffer(buffer)
            }
            
            // Start audio engine
            audioEngine.prepare()
            try audioEngine.start()
            
            // Start timers
            startRecordingTimer(duration: maxDuration)
            startAudioLevelTimer()
            
        } catch {
            // Clean up on error
            stopRecordingInternal()
            updateRecordingState(.error(.audioEngineStartFailed(error)))
            throw AudioProcessorError.audioEngineStartFailed(error)
        }
    }
    
    public func stopRecording() {
        stopRecordingInternal()
    }
    
    public func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    public func checkMicrophonePermission() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .audio)
    }
    
    public func cleanup() {
        stopRecordingInternal()
        recordingStateContinuation.finish()
        audioLevelContinuation.finish()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Private Methods
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let int16ChannelData = buffer.int16ChannelData else { return }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        // Convert to Int16 array
        var samples = [Int16]()
        samples.reserveCapacity(frameLength * channelCount)
        
        for frame in 0..<frameLength {
            for channel in 0..<channelCount {
                let sample = int16ChannelData[channel][frame]
                samples.append(sample)
            }
        }
        
        // Add to circular buffer
        bufferQueue.async(flags: .barrier) {
            self.audioBuffer.write(samples)
        }
        
        // Calculate audio level
        let level = calculateAudioLevel(samples: samples)
        currentAudioLevel = level
    }
    
    private func calculateAudioLevel(samples: [Int16]) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        
        // Calculate RMS (Root Mean Square)
        let sumOfSquares = samples.reduce(0) { sum, sample in
            let floatSample = Float(sample) / Float(Int16.max)
            return sum + (floatSample * floatSample)
        }
        
        let meanSquare = sumOfSquares / Float(samples.count)
        let rms = sqrt(meanSquare)
        
        // Convert to decibels and normalize to 0-1 range
        let db = 20 * log10(max(rms, 0.00001))
        let normalizedDb = (db + 60) / 60 // Assuming -60dB to 0dB range
        
        return max(0.0, min(1.0, normalizedDb))
    }
    
    private func stopRecordingInternal() {
        // Update state
        updateRecordingState(.stopping)
        
        // Stop timers
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        
        // Deactivate audio session
        try? audioSession.setActive(false)
        
        // Process recorded data
        let recordedSamples = bufferQueue.sync {
            audioBuffer.readAll()
        }
        
        if !recordedSamples.isEmpty {
            let audioData = AudioData(
                samples: recordedSamples,
                sampleRate: configuration.sampleRate,
                channelCount: configuration.channelCount,
                timestamp: recordingStartTime ?? Date()
            )
            recordingCompletion?(.success(audioData))
        } else {
            recordingCompletion?(.failure(.bufferAllocationFailed))
        }
        
        // Reset state
        updateRecordingState(.idle)
        recordingCompletion = nil
        recordingStartTime = nil
    }
    
    private func updateRecordingState(_ newState: RecordingState) {
        stateQueue.async { [weak self] in
            self?._recordingState = newState
            self?.recordingStateContinuation.yield(newState)
        }
    }
    
    // MARK: - Timers
    
    private func startRecordingTimer(duration: TimeInterval) {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.stopRecording()
        }
    }
    
    private func startAudioLevelTimer() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.audioLevelContinuation.yield(self.currentAudioLevel)
        }
    }
    
    // MARK: - Notifications
    
    @objc private func handleRouteChange(notification: Notification) {
        guard recordingState == .recording else { return }
        
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSession.routeChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // Audio device was disconnected
            stopRecordingInternal()
            updateRecordingState(.error(.audioDeviceNotAvailable))
            recordingCompletion?(.failure(.audioDeviceNotAvailable))
            
        default:
            break
        }
    }
    
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSession.interruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began && recordingState == .recording {
            // Recording was interrupted
            stopRecordingInternal()
            updateRecordingState(.error(.recordingFailed(NSError(domain: "VoiceType", code: -2, userInfo: [NSLocalizedDescriptionKey: "Recording was interrupted"]))))
        }
    }
}

// MARK: - Circular Buffer

/// Thread-safe circular buffer for audio samples
private final class CircularBuffer<T> {
    private var buffer: [T?]
    private var writeIndex = 0
    private var readIndex = 0
    private var count = 0
    private let capacity: Int
    private let lock = NSLock()
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }
    
    func write(_ elements: [T]) {
        lock.lock()
        defer { lock.unlock() }
        
        for element in elements {
            buffer[writeIndex] = element
            writeIndex = (writeIndex + 1) % capacity
            
            if count < capacity {
                count += 1
            } else {
                // Buffer is full, move read index
                readIndex = (readIndex + 1) % capacity
            }
        }
    }
    
    func readAll() -> [T] {
        lock.lock()
        defer { lock.unlock() }
        
        var result = [T]()
        result.reserveCapacity(count)
        
        var index = readIndex
        for _ in 0..<count {
            if let element = buffer[index] {
                result.append(element)
            }
            index = (index + 1) % capacity
        }
        
        return result
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        buffer = Array(repeating: nil, count: capacity)
        writeIndex = 0
        readIndex = 0
        count = 0
    }
}