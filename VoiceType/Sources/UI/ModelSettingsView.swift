import SwiftUI
import VoiceTypeCore
import VoiceTypeImplementations

/// Settings view specifically for model management
public struct ModelSettingsView: View {
    @StateObject private var modelManager = WhisperKitModelManager()
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Choose the model that best fits your needs. Larger models provide better accuracy but require more storage and memory.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Model list
                VStack(alignment: .leading, spacing: 12) {
                    ModelRowView(modelType: .fast, modelManager: modelManager)
                    Divider()
                    ModelRowView(modelType: .balanced, modelManager: modelManager)
                    Divider()
                    ModelRowView(modelType: .accurate, modelManager: modelManager)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .frame(maxWidth: 600)
        .task {
            // Verify models on view appear
            await MainActor.run {
                modelManager.verifyAllModels()
            }
        }
    }
}

struct ModelRowView: View {
    let modelType: ModelType
    @ObservedObject var modelManager: WhisperKitModelManager
    @EnvironmentObject var coordinator: VoiceTypeCoordinator
    
    @State private var isDownloading = false
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var isDownloaded: Bool {
        modelManager.isModelDownloaded(modelType: modelType)
    }
    
    private var isSelected: Bool {
        coordinator.selectedModel == modelType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(modelType.displayName)
                        .font(.headline)
                    
                    Text(modelType.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        Label("\(modelType.sizeInMB) MB", systemImage: "internaldrive")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("\(modelType.minimumRAMRequirement) GB RAM", systemImage: "memorychip")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isDownloading {
                    VStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                        if modelManager.downloadProgress > 0 {
                            Text("\(Int(modelManager.downloadProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else if isDownloaded {
                    HStack(spacing: 12) {
                        // Selection radio button
                        Button(action: {
                            selectModel()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                                    .foregroundColor(isSelected ? .accentColor : .secondary)
                                Text(isSelected ? "Active" : "Select")
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Button("Delete") {
                            showDeleteConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(isSelected) // Can't delete the active model
                    }
                } else {
                    Button("Download") {
                        downloadModel()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
        }
        .padding(.vertical, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .alert("Delete Model", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteModel()
            }
        } message: {
            Text("Are you sure you want to delete the \(modelType.displayName) model? You can download it again later.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func downloadModel() {
        isDownloading = true
        
        Task {
            do {
                try await modelManager.downloadModel(modelType: modelType)
                isDownloading = false
            } catch {
                isDownloading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func deleteModel() {
        Task {
            do {
                try await modelManager.deleteModel(modelType: modelType)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func selectModel() {
        // Update the coordinator's selected model
        coordinator.selectedModel = modelType
        
        // Save to UserDefaults
        let modelString: String
        switch modelType {
        case .fast:
            modelString = "fast"
        case .balanced:
            modelString = "balanced"
        case .accurate:
            modelString = "accurate"
        }
        UserDefaults.standard.set(modelString, forKey: "selectedModel")
        
        // Load the model
        Task {
            await coordinator.loadSelectedModel()
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
            .frame(width: 600, height: 500)
    }
}