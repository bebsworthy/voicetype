import SwiftUI
import VoiceTypeCore
import VoiceTypeImplementations
import AppKit

/// Main menu bar interface for VoiceType
public struct MenuBarView: View {
    @ObservedObject var coordinator: VoiceTypeCoordinator
    @Environment(\.openWindow) var openWindow

    public init(coordinator: VoiceTypeCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status Section
            statusSection

            Divider()
                .padding(.horizontal, -12)

            // Quick Actions
            quickActionsSection

            Divider()
                .padding(.horizontal, -12)

            // Bottom Actions
            bottomActionsSection
        }
        .padding(12)
        .frame(width: 200)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status indicator with icon and text
            HStack(spacing: 8) {
                statusIndicator
                    .frame(width: 8, height: 8)

                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(statusTextColor)
            }

            // Recording progress (if recording)
            if coordinator.recordingState == .recording {
                ProgressView(value: coordinator.recordingProgress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(x: 1, y: 0.5, anchor: .center)
            }

            // Error message (if any)
            if let error = coordinator.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Last transcription preview (if success)
            if coordinator.recordingState == .success && !coordinator.lastTranscription.isEmpty {
                Text("✓ \(coordinator.lastTranscription)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Start/Stop Dictation Button
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
                    Image(systemName: dictationButtonIcon)
                        .foregroundColor(dictationButtonColor)
                    Text(dictationButtonText)
                    Spacer()
                    Text(hotkeyHint)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(MenuButtonStyle())
            .disabled(!coordinator.isReady || coordinator.recordingState == .processing)

            // Model selection
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Text("Model:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()

                if coordinator.isLoadingModel {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        if let status = coordinator.modelLoadingStatus {
                            Text(status)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text(getActiveModelName())
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
    }

    // MARK: - Bottom Actions Section

    private var bottomActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                openWindow(id: "settings")
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                    Spacer()
                }
            }
            .buttonStyle(MenuButtonStyle())

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit VoiceType")
                    Spacer()
                }
            }
            .buttonStyle(MenuButtonStyle())
        }
    }

    // MARK: - Helper Properties

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .overlay(
                Circle()
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
            )
    }

    private var statusColor: Color {
        switch coordinator.recordingState {
        case .idle:
            return coordinator.isReady ? .gray : .orange
        case .recording:
            return .green  // Changed from red to green
        case .processing:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch coordinator.recordingState {
        case .idle:
            return coordinator.isReady ? "Ready" : "Loading..."
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .success:
            return "Success"
        case .error(let message):
            return message
        }
    }

    private var statusTextColor: Color {
        switch coordinator.recordingState {
        case .error:
            return .red
        case .success:
            return .green
        default:
            return .primary
        }
    }
    
    private func getActiveModelName() -> String {
        // Check if we're using a dynamic model
        if let dynamicModelId = coordinator.selectedModelId {
            // Extract a display name from the model ID
            // e.g., "openai_whisper-tiny" -> "whisper-tiny"
            let displayName = dynamicModelId
                .replacingOccurrences(of: "openai_", with: "")
                .replacingOccurrences(of: "distil-whisper_", with: "")
                .replacingOccurrences(of: "_", with: " ")
            return displayName
        } else {
            // Default to tiny if no model selected
            return "whisper-tiny"
        }
    }

    private var dictationButtonIcon: String {
        switch coordinator.recordingState {
        case .idle:
            return "mic.fill"
        case .recording:
            return "stop.fill"
        case .processing:
            return "hourglass"
        default:
            return "mic.fill"
        }
    }

    private var dictationButtonColor: Color {
        switch coordinator.recordingState {
        case .recording:
            return .red
        case .processing:
            return .blue
        default:
            return .primary
        }
    }

    private var dictationButtonText: String {
        switch coordinator.recordingState {
        case .idle:
            return "Start Dictation (Hold)"
        case .recording:
            return "Recording... (Release to stop)"
        case .processing:
            return "Processing..."
        default:
            return "Start Dictation (Hold)"
        }
    }

    private var hotkeyHint: String {
        let hotkey = UserDefaults.standard.string(forKey: "globalHotkey") ?? "⌃⇧V"
        return formatHotkey(hotkey)
    }

    private func formatHotkey(_ hotkey: String) -> String {
        // Convert hotkey format to symbols
        hotkey
            .replacingOccurrences(of: "ctrl", with: "⌃")
            .replacingOccurrences(of: "cmd", with: "⌘")
            .replacingOccurrences(of: "shift", with: "⇧")
            .replacingOccurrences(of: "opt", with: "⌥")
            .replacingOccurrences(of: "alt", with: "⌥")
            .replacingOccurrences(of: "+", with: "")
            .uppercased()
    }
}

// MARK: - Menu Button Style

struct MenuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .foregroundColor(configuration.isPressed ? .accentColor : .primary)
    }
}

// MARK: - Preview

struct MenuBarView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarView(coordinator: VoiceTypeCoordinator())
            .frame(width: 200)
    }
}
