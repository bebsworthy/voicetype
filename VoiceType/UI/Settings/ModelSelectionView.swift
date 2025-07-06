import SwiftUI

/// View for selecting and managing AI models
struct ModelSelectionView: View {
    @Binding var selectedModel: ModelType
    @ObservedObject var modelManager: ModelManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current model info
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedModel.displayName)
                        .font(.headline)
                    Text("Size: \(selectedModel.sizeInMB) MB • Latency: ~\(Int(selectedModel.targetLatency))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isModelInstalled(selectedModel) {
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            // Model picker
            Picker("Model", selection: $selectedModel) {
                ForEach(ModelType.allCases, id: \.self) { model in
                    HStack {
                        Text(model.displayName)
                        if !isModelInstalled(model) && !model.isEmbedded {
                            Text("(Not installed)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(model)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .disabled(modelManager.downloadQueue.contains { $0.status.isDownloading })
            
            // Download button if needed
            if !isModelInstalled(selectedModel) && !selectedModel.isEmbedded {
                Button(action: {
                    downloadSelectedModel()
                }) {
                    if let downloadItem = modelManager.downloadQueue.first(where: { $0.modelName == selectedModel.rawValue }) {
                        switch downloadItem.status {
                        case .downloading(let progress):
                            HStack {
                                ProgressView(value: progress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .frame(width: 100)
                                Text("\(Int(progress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        case .installing:
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Installing...")
                                    .font(.caption)
                            }
                        case .failed(let error):
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                                Text("Failed: \(error.localizedDescription)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        default:
                            Text("Download")
                        }
                    } else {
                        Label("Download Model", systemImage: "arrow.down.circle")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(modelManager.downloadQueue.contains { $0.status.isDownloading })
            }
        }
    }
    
    private func isModelInstalled(_ modelType: ModelType) -> Bool {
        if modelType.isEmbedded {
            return true
        }
        return modelManager.installedModels.contains { $0.name == modelType.rawValue }
    }
    
    private func downloadSelectedModel() {
        Task {
            do {
                let config = ModelManager.ModelConfiguration(
                    name: selectedModel.rawValue,
                    version: "1.0",
                    downloadURL: modelDownloadURL(for: selectedModel),
                    estimatedSize: Int64(selectedModel.sizeInMB * 1024 * 1024)
                )
                try await modelManager.downloadModel(config)
            } catch {
                print("Failed to download model: \(error)")
            }
        }
    }
    
    private func modelDownloadURL(for modelType: ModelType) -> URL {
        // These would be real URLs in production
        switch modelType {
        case .fast:
            return URL(string: "https://models.voicetype.app/whisper-tiny-en.mlpackage.zip")!
        case .balanced:
            return URL(string: "https://models.voicetype.app/whisper-base-en.mlpackage.zip")!
        case .accurate:
            return URL(string: "https://models.voicetype.app/whisper-small-en.mlpackage.zip")!
        }
    }
}

/// Row view for displaying model information with download status
struct ModelRowView: View {
    let modelType: ModelType
    @ObservedObject var modelManager: ModelManager
    let isSelected: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            // Model info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(modelType.displayName)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(isSelected ? .semibold : .regular)
                    
                    if modelType.isEmbedded {
                        Text("Built-in")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2))
                            .foregroundColor(.accentColor)
                            .cornerRadius(4)
                    }
                }
                
                HStack(spacing: 12) {
                    Label("\(modelType.sizeInMB) MB", systemImage: "internaldrive")
                    Label("~\(Int(modelType.targetLatency))s", systemImage: "timer")
                    Label("\(modelType.minimumRAMRequirement) GB RAM", systemImage: "memorychip")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status/Action
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            } else if let downloadItem = modelManager.downloadQueue.first(where: { $0.modelName == modelType.rawValue }) {
                DownloadStatusView(status: downloadItem.status)
            } else if isModelInstalled {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            } else if !modelType.isEmbedded {
                Button(action: downloadModel) {
                    Label("Download", systemImage: "arrow.down.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .opacity(isHovering ? 1 : 0.8)
            }
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    private var isModelInstalled: Bool {
        if modelType.isEmbedded {
            return true
        }
        return modelManager.installedModels.contains { $0.name == modelType.rawValue }
    }
    
    private func downloadModel() {
        Task {
            do {
                let config = ModelManager.ModelConfiguration(
                    name: modelType.rawValue,
                    version: "1.0",
                    downloadURL: modelDownloadURL(for: modelType),
                    estimatedSize: Int64(modelType.sizeInMB * 1024 * 1024)
                )
                try await modelManager.downloadModel(config)
            } catch {
                print("Failed to download model: \(error)")
            }
        }
    }
    
    private func modelDownloadURL(for modelType: ModelType) -> URL {
        // These would be real URLs in production
        switch modelType {
        case .fast:
            return URL(string: "https://models.voicetype.app/whisper-tiny-en.mlpackage.zip")!
        case .balanced:
            return URL(string: "https://models.voicetype.app/whisper-base-en.mlpackage.zip")!
        case .accurate:
            return URL(string: "https://models.voicetype.app/whisper-small-en.mlpackage.zip")!
        }
    }
}

/// View for displaying download status
struct DownloadStatusView: View {
    let status: ModelManager.ModelDownloadItem.DownloadStatus
    
    var body: some View {
        switch status {
        case .pending:
            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text("Queued")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
        case .downloading(let progress):
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(width: 60)
                Text("\(Int(progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 35)
            }
            
        case .installing:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Installing")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }
}

// MARK: - Preview

struct ModelSelectionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ModelSelectionView(
                selectedModel: .constant(.balanced),
                modelManager: ModelManager()
            )
            .padding()
            .frame(width: 400)
            
            Divider()
            
            VStack(spacing: 8) {
                ForEach(ModelType.allCases, id: \.self) { model in
                    ModelRowView(
                        modelType: model,
                        modelManager: ModelManager(),
                        isSelected: model == .balanced
                    )
                }
            }
            .padding()
            .frame(width: 500)
        }
    }
}