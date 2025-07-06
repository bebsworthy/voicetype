import SwiftUI
import AVFoundation

/// Audio device selection picker
struct AudioDevicePickerView: View {
    @Binding var selectedDevice: AudioDevice?
    @StateObject private var audioDeviceManager = AudioDeviceManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current device info
            if let device = selectedDevice ?? audioDeviceManager.defaultInputDevice {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.body)
                        if device.isDefault {
                            Text("System Default")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Level meter
                    AudioLevelMeter(device: device)
                        .frame(width: 100, height: 20)
                }
            }
            
            // Device picker
            Picker("Audio Input", selection: $selectedDevice) {
                Text("System Default")
                    .tag(nil as AudioDevice?)
                
                Divider()
                
                ForEach(audioDeviceManager.inputDevices) { device in
                    HStack {
                        Text(device.name)
                        if device.isDefault {
                            Text("(Default)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(device as AudioDevice?)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedDevice) { _ in
                audioDeviceManager.setPreferredDevice(selectedDevice)
            }
            
            // Test button
            HStack {
                Button(action: { audioDeviceManager.startTestRecording() }) {
                    Label("Test Recording", systemImage: "mic.circle")
                }
                .buttonStyle(.bordered)
                .disabled(audioDeviceManager.isTestRecording)
                
                if audioDeviceManager.isTestRecording {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Recording...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            audioDeviceManager.refreshDevices()
        }
    }
}

/// Audio level meter visualization
struct AudioLevelMeter: View {
    let device: AudioDevice
    @StateObject private var levelMonitor = AudioLevelMonitor()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                
                // Level bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(levelGradient)
                    .frame(width: geometry.size.width * CGFloat(levelMonitor.level))
                    .animation(.linear(duration: 0.05), value: levelMonitor.level)
            }
        }
        .onAppear {
            levelMonitor.startMonitoring(device: device)
        }
        .onDisappear {
            levelMonitor.stopMonitoring()
        }
    }
    
    private var levelGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.green,
                Color.yellow,
                Color.orange,
                Color.red
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// Represents an audio input device
struct AudioDevice: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let uid: String
    let isDefault: Bool
    
    static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Manages audio devices and monitoring
class AudioDeviceManager: ObservableObject {
    @Published var inputDevices: [AudioDevice] = []
    @Published var defaultInputDevice: AudioDevice?
    @Published var isTestRecording = false
    
    private var audioEngine = AVAudioEngine()
    
    init() {
        refreshDevices()
        setupNotifications()
    }
    
    func refreshDevices() {
        var devices: [AudioDevice] = []
        
        // Get all audio input devices
        let audioDevices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        ).devices
        
        for device in audioDevices {
            let audioDevice = AudioDevice(
                id: device.uniqueID,
                name: device.localizedName,
                uid: device.uniqueID,
                isDefault: device == AVCaptureDevice.default(for: .audio)
            )
            devices.append(audioDevice)
        }
        
        DispatchQueue.main.async {
            self.inputDevices = devices
            self.defaultInputDevice = devices.first { $0.isDefault }
        }
    }
    
    func setPreferredDevice(_ device: AudioDevice?) {
        // In a real implementation, this would configure the audio session
        // to use the selected device
        print("Setting preferred device: \(device?.name ?? "System Default")")
    }
    
    func startTestRecording() {
        isTestRecording = true
        
        // Stop after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.isTestRecording = false
        }
    }
    
    private func setupNotifications() {
        // Listen for device changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceChange),
            name: .AVCaptureDeviceWasConnected,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeviceChange),
            name: .AVCaptureDeviceWasDisconnected,
            object: nil
        )
    }
    
    @objc private func handleDeviceChange() {
        refreshDevices()
    }
}

/// Monitors audio input levels
class AudioLevelMonitor: ObservableObject {
    @Published var level: Float = 0
    
    private var audioEngine = AVAudioEngine()
    private var timer: Timer?
    
    func startMonitoring(device: AudioDevice) {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let channelData = buffer.floatChannelData else { return }
            
            let channelDataValue = channelData.pointee
            let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride)
                .map { channelDataValue[$0] }
            
            let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
            let avgPower = 20 * log10(rms)
            
            let level = self?.scaledPower(avgPower) ?? 0
            
            DispatchQueue.main.async {
                self?.level = level
            }
        }
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func stopMonitoring() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        level = 0
    }
    
    private func scaledPower(_ power: Float) -> Float {
        guard power.isFinite else { return 0 }
        
        let minDb: Float = -80
        
        if power < minDb {
            return 0
        } else if power >= 0 {
            return 1
        } else {
            return (abs(minDb) - abs(power)) / abs(minDb)
        }
    }
}

// MARK: - Preview

struct AudioDevicePickerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AudioDevicePickerView(selectedDevice: .constant(nil))
                .padding()
                .frame(width: 400)
            
            Divider()
            
            // Level meter preview
            AudioLevelMeter(device: AudioDevice(
                id: "preview",
                name: "Built-in Microphone",
                uid: "preview",
                isDefault: true
            ))
            .frame(width: 200, height: 20)
            .padding()
        }
    }
}