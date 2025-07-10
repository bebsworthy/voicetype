import SwiftUI
import VoiceTypeCore
import VoiceTypeImplementations

/// Settings view for dynamic WhisperKit model management
public struct DynamicModelSettingsView: View {
    @StateObject private var modelManager = WhisperKitModelManager()
    @StateObject private var modelRepository = WhisperKitModelRepository()
    @EnvironmentObject var coordinator: VoiceTypeCoordinator
    
    @State private var selectedModelId: String?
    @State private var showRefreshProgress = false
    @State private var searchText = ""
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with refresh button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WhisperKit Models")
                            .font(.largeTitle)
                            .bold()
                        
                        Text("Choose from a variety of Whisper models optimized for different use cases")
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: refreshModelList) {
                        if showRefreshProgress {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(showRefreshProgress || modelRepository.isLoading)
                    .help("Reload model list from Hugging Face")
                }
                
                // Last refresh info
                if let lastRefresh = modelRepository.lastRefreshDate {
                    Text("Last updated: \(lastRefresh, formatter: relativeDateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search models...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                
                // Model categories
                if modelRepository.models.isEmpty && !modelRepository.isLoading {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No models loaded")
                            .font(.headline)
                        Text("Click Refresh to load available models")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // Model sections
                    VStack(spacing: 24) {
                        // Recommended models
                        if !recommendedModels.isEmpty {
                            ModelSection(
                                title: "Recommended",
                                models: recommendedModels,
                                modelManager: modelManager,
                                selectedModelId: $selectedModelId
                            )
                        }
                        
                        // All models grouped by base type
                        ForEach(groupedModels.sorted(by: { $0.key < $1.key }), id: \.key) { baseModel, models in
                            ModelSection(
                                title: formatBaseModelName(baseModel),
                                models: models,
                                modelManager: modelManager,
                                selectedModelId: $selectedModelId
                            )
                        }
                    }
                }
                
                // Loading indicator
                if modelRepository.isLoading {
                    HStack {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                        Text("Loading models...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                
                // Error message
                if let error = modelRepository.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
        .frame(maxWidth: 800)
        .task {
            // Load cached models on appear
            await modelRepository.loadModels()
            
            // Set current selected model
            selectedModelId = getCurrentSelectedModelId()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredModels: [WhisperKitModel] {
        if searchText.isEmpty {
            return modelRepository.models
        }
        
        return modelRepository.models.filter { model in
            model.displayName.localizedCaseInsensitiveContains(searchText) ||
            model.id.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var recommendedModels: [WhisperKitModel] {
        modelRepository.recommendedModels.filter { model in
            searchText.isEmpty || 
            model.displayName.localizedCaseInsensitiveContains(searchText) ||
            model.id.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var groupedModels: [String: [WhisperKitModel]] {
        Dictionary(grouping: filteredModels) { $0.baseModel }
    }
    
    // MARK: - Helper Methods
    
    private func refreshModelList() {
        showRefreshProgress = true
        
        Task {
            await modelRepository.refreshModels()
            showRefreshProgress = false
        }
    }
    
    private func getCurrentSelectedModelId() -> String? {
        // Check if using legacy model type
        if let legacyModel = modelRepository.modelForLegacyType(coordinator.selectedModel) {
            return legacyModel.id
        }
        
        // Check if we have a stored dynamic model ID
        return UserDefaults.standard.string(forKey: "selectedDynamicModelId")
    }
    
    private func formatBaseModelName(_ baseModel: String) -> String {
        // Format the base model name for display
        return baseModel
            .replacingOccurrences(of: "whisper-", with: "Whisper ")
            .replacingOccurrences(of: "distil-", with: "Distil ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}

// MARK: - Model Section View

struct ModelSection: View {
    let title: String
    let models: [WhisperKitModel]
    @ObservedObject var modelManager: WhisperKitModelManager
    @Binding var selectedModelId: String?
    
    @EnvironmentObject var coordinator: VoiceTypeCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                ForEach(models.sorted(by: { m1, m2 in
                    // Sort by size (smaller first)
                    (m1.sizeInBytes ?? 0) < (m2.sizeInBytes ?? 0)
                })) { model in
                    DynamicModelRowView(
                        model: model,
                        modelManager: modelManager,
                        isSelected: selectedModelId == model.id,
                        onSelect: {
                            selectedModelId = model.id
                        }
                    )
                    .environmentObject(coordinator)
                    
                    if model.id != models.last?.id {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

// MARK: - Dynamic Model Row View

struct DynamicModelRowView: View {
    let model: WhisperKitModel
    @ObservedObject var modelManager: WhisperKitModelManager
    let isSelected: Bool
    let onSelect: () -> Void
    
    @EnvironmentObject var coordinator: VoiceTypeCoordinator
    
    @State private var isDownloading = false
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    private var isDownloaded: Bool {
        modelManager.isDynamicModelDownloaded(modelId: model.id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(model.displayName)
                            .font(.headline)
                        
                        if let language = model.language {
                            Text(language.uppercased())
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                        
                        if let variant = model.variant {
                            Text(variant)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(model.sizeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isDownloading || (modelManager.isDownloading && modelManager.currentDownloadTask == model.displayName) {
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
                        // Selection button
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
                        .disabled(isSelected)
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
            Text("Are you sure you want to delete \(model.displayName)? You can download it again later.")
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
                try await modelManager.downloadDynamicModel(model: model)
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
                try await modelManager.deleteDynamicModel(modelId: model.id)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func selectModel() {
        onSelect()
        
        // Save the selected dynamic model ID
        UserDefaults.standard.set(model.id, forKey: "selectedDynamicModelId")
        
        // Load the model in coordinator
        Task {
            await coordinator.loadDynamicModel(modelId: model.id)
        }
    }
}

// MARK: - Date Formatter

private let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter
}()

// MARK: - Preview

struct DynamicModelSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        DynamicModelSettingsView()
            .frame(width: 800, height: 600)
    }
}