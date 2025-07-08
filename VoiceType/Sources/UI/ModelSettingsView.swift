import SwiftUI
import VoiceTypeCore
import VoiceTypeImplementations

/// Settings view specifically for model management with download progress and smooth switching
public struct ModelSettingsView: View {
    @EnvironmentObject var coordinator: VoiceTypeCoordinator
    @StateObject private var modelManager = WhisperKitModelManager()
    @AppStorage("selectedModel") private var selectedModelSetting = "fast"

    @State private var selectedModel: ModelType = .fast
    @State private var isLoadingModel = false
    @State private var loadingModelType: ModelType?
    @State private var showingRestartAlert = false
    @State private var showingDownloadError = false
    @State private var downloadError: Error?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text("AI Model Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Choose the model that best fits your needs. Larger models provide better accuracy but require more storage and memory.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Model Selection
            VStack(spacing: 12) {
                ForEach(ModelType.allCases, id: \.self) { modelType in
                    ModelRowView(
                        modelType: modelType,
                        isSelected: selectedModel == modelType,
                        isDownloaded: modelManager.isModelDownloaded(modelType: modelType),
                        isDownloading: modelManager.isDownloading && loadingModelType == modelType,
                        downloadProgress: modelManager.isDownloading && loadingModelType == modelType ? modelManager.downloadProgress : 0,
                        onSelect: {
                            selectModel(modelType)
                        },
                        onDownload: {
                            Task {
                                await downloadModel(modelType)
                            }
                        }
                    )
                }
            }

            Spacer()

            // Info Box
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Current Model", systemImage: "info.circle")
                        .font(.headline)

                    HStack {
                        Text("Active:")
                            .foregroundColor(.secondary)
                        Text(coordinator.selectedModel.displayName)
                            .fontWeight(.medium)

                        if isLoadingModel {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(.leading, 4)
                        }
                    }
                    .font(.callout)

                    if let modelSize = modelManager.getModelSize(modelType: coordinator.selectedModel) {
                        HStack {
                            Text("Size on disk:")
                                .foregroundColor(.secondary)
                            Text(formatBytes(modelSize))
                                .fontWeight(.medium)
                        }
                        .font(.callout)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: 600)
        .onAppear {
            selectedModel = modelTypeFromString(selectedModelSetting)
        }
        .alert("Restart Required", isPresented: $showingRestartAlert) {
            Button("Later") {
                // User chose to restart later
            }
            Button("Restart Now") {
                restartApp()
            }
        } message: {
            Text("VoiceType needs to restart to switch to the \(selectedModel.displayName) model. You can restart now or the change will take effect the next time you launch the app.")
        }
        .alert("Download Failed", isPresented: $showingDownloadError) {
            Button("OK") {
                downloadError = nil
            }
        } message: {
            if let error = downloadError {
                Text(error.localizedDescription)
            } else {
                Text("Failed to download the model. Please check your internet connection and try again.")
            }
        }
    }

    // MARK: - Private Methods

    private func selectModel(_ modelType: ModelType) {
        guard modelManager.isModelDownloaded(modelType: modelType) else {
            // Model needs to be downloaded first
            return
        }

        selectedModel = modelType
        selectedModelSetting = modelTypeToString(modelType)

        // If selecting a different model than currently loaded, show restart alert
        if modelType != coordinator.selectedModel {
            showingRestartAlert = true
        }
    }

    private func downloadModel(_ modelType: ModelType) async {
        loadingModelType = modelType

        do {
            try await modelManager.downloadModel(modelType: modelType)

            // After successful download, select the model
            await MainActor.run {
                selectModel(modelType)
            }
        } catch {
            await MainActor.run {
                downloadError = error
                showingDownloadError = true
            }
        }

        loadingModelType = nil
    }

    private func modelTypeFromString(_ string: String) -> ModelType {
        switch string {
        case "fast": return .fast
        case "balanced": return .balanced
        case "accurate": return .accurate
        default: return .fast
        }
    }

    private func modelTypeToString(_ modelType: ModelType) -> String {
        switch modelType {
        case .fast: return "fast"
        case .balanced: return "balanced"
        case .accurate: return "accurate"
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }

    private func restartApp() {
        // Save any pending changes
        UserDefaults.standard.synchronize()

        // Relaunch the app
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()

        // Terminate current instance
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Model Row View

struct ModelRowView: View {
    let modelType: ModelType
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let onSelect: () -> Void
    let onDownload: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Radio button
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .imageScale(.large)
                .onTapGesture {
                    if isDownloaded {
                        onSelect()
                    }
                }
                .disabled(!isDownloaded)

            // Model info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(modelType.displayName)
                        .font(.headline)

                    if modelType == .fast {
                        Text("(Embedded)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(modelType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Label("\(modelType.sizeInMB) MB", systemImage: "internaldrive")
                    Label("\(modelType.minimumRAMRequirement) GB RAM", systemImage: "memorychip")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Download/Status indicator
            if isDownloaded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .imageScale(.large)
            } else if isDownloading {
                VStack(spacing: 4) {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)

                    Text("\(Int(downloadProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(width: 50)
            } else {
                Button(action: onDownload) {
                    Label("Download", systemImage: "arrow.down.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isDownloaded {
                onSelect()
            }
        }
    }
}

// MARK: - Model Type Extensions

extension ModelType {
    var description: String {
        switch self {
        case .fast:
            return "Fastest processing, good for quick notes and basic dictation"
        case .balanced:
            return "Best balance of speed and accuracy for everyday use"
        case .accurate:
            return "Highest accuracy, ideal for professional or technical content"
        }
    }
}

// MARK: - Preview

struct ModelSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ModelSettingsView()
            .environmentObject(VoiceTypeCoordinator())
            .frame(width: 600, height: 500)
    }
}
