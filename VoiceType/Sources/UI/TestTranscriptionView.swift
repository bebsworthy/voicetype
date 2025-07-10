import SwiftUI
import VoiceTypeCore
import VoiceTypeImplementations

/// Test transcription view for testing model functionality
public struct TestTranscriptionView: View {
    @EnvironmentObject var coordinator: VoiceTypeCoordinator
    @State private var transcribedText: String = ""
    @State private var isRecording: Bool = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Test your voice transcription model by recording audio and viewing the results.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Model Info
                GroupBox {
                    HStack {
                        Label("Active Model", systemImage: "cpu")
                            .font(.headline)
                        Spacer()
                        Text(getActiveModelName())
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 4)
                }
                
                // Recording Section
                GroupBox {
                    VStack(spacing: 16) {
                        // Recording Button
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                toggleRecording()
                            }) {
                                VStack(spacing: 8) {
                                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                        .font(.system(size: 48))
                                        .foregroundColor(isRecording ? .red : .accentColor)
                                        .symbolEffect(.bounce, value: isRecording)
                                    
                                    Text(isRecording ? "Stop Recording" : "Start Recording")
                                        .font(.headline)
                                    
                                    if isRecording {
                                        Text(formatDuration(recordingDuration))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(coordinator.recordingState == .processing)
                            
                            Spacer()
                        }
                        
                        // Status
                        if coordinator.recordingState == .processing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Processing...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Error Message
                        if let error = coordinator.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Transcription Results
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Transcription Result", systemImage: "text.quote")
                                .font(.headline)
                            
                            Spacer()
                            
                            if !transcribedText.isEmpty {
                                Button(action: {
                                    copyToClipboard()
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                Button(action: {
                                    clearTranscription()
                                }) {
                                    Label("Clear", systemImage: "trash")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        
                        Text(transcribedText.isEmpty ? "Transcribed text will appear here..." : transcribedText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(transcribedText.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .textSelection(.enabled)
                            .frame(minHeight: 150)
                    }
                }
                
                // Tips
                Text("Tip: Speak clearly and at a normal pace for best results.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .frame(maxWidth: 600)
        .onReceive(coordinator.$recordingState) { state in
            handleStateChange(state)
        }
        .onReceive(coordinator.$lastTranscription) { text in
            if !text.isEmpty && coordinator.recordingState != .recording {
                transcribedText = text
            }
        }
        .onDisappear {
            // Stop recording if view disappears
            if isRecording {
                Task {
                    await coordinator.stopDictation()
                }
            }
            timer?.invalidate()
        }
    }
    
    // MARK: - Private Methods
    
    private func getActiveModelName() -> String {
        // Check if we're using a dynamic model
        if let dynamicModelId = coordinator.selectedDynamicModelId {
            // Extract a display name from the model ID
            // e.g., "openai_whisper-tiny" -> "whisper-tiny"
            let displayName = dynamicModelId
                .replacingOccurrences(of: "openai_", with: "")
                .replacingOccurrences(of: "distil-whisper_", with: "")
                .replacingOccurrences(of: "_", with: " ")
            return displayName
        } else {
            // Fall back to legacy model type
            return coordinator.selectedModel.displayName
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        recordingDuration = 0
        
        // Start timer to track duration
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
        }
        
        Task {
            await coordinator.startDictation()
        }
    }
    
    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        
        Task {
            await coordinator.stopDictation()
        }
    }
    
    private func handleStateChange(_ state: RecordingState) {
        switch state {
        case .recording:
            isRecording = true
        case .idle, .processing, .success:
            isRecording = false
            timer?.invalidate()
        case .error:
            isRecording = false
            timer?.invalidate()
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcribedText, forType: .string)
    }
    
    private func clearTranscription() {
        transcribedText = ""
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let tenths = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        
        if minutes > 0 {
            return String(format: "%d:%02d.%d", minutes, seconds, tenths)
        } else {
            return String(format: "%d.%d", seconds, tenths)
        }
    }
}

// MARK: - Preview

struct TestTranscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        TestTranscriptionView()
            .environmentObject(VoiceTypeCoordinator())
            .frame(width: 600, height: 700)
    }
}