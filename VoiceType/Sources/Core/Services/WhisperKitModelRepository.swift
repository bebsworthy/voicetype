import Foundation

/// Repository for fetching and caching WhisperKit models from Hugging Face
@MainActor
public class WhisperKitModelRepository: ObservableObject {
    // MARK: - Properties
    
    /// Cached models list
    @Published public private(set) var models: [WhisperKitModel] = []
    
    /// Loading state
    @Published public private(set) var isLoading = false
    
    /// Error message if any
    @Published public private(set) var errorMessage: String?
    
    /// Last refresh date
    @Published public private(set) var lastRefreshDate: Date?
    
    // MARK: - Private Properties
    
    private let cacheURL: URL
    private let huggingFaceAPI = "https://huggingface.co/api/models"
    private let whisperKitOrg = "argmaxinc/whisperkit"
    
    // Cache duration (7 days)
    private let cacheExpirationInterval: TimeInterval = 7 * 24 * 60 * 60
    
    // MARK: - Initialization
    
    public init() {
        // Setup cache directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let voiceTypeDir = appSupport.appendingPathComponent("VoiceType", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: voiceTypeDir, withIntermediateDirectories: true)
        
        self.cacheURL = voiceTypeDir.appendingPathComponent("whisperkit_models_cache.json")
        
        // Load cached models on init
        loadCachedModels()
    }
    
    // MARK: - Public Methods
    
    /// Load models from cache or fetch if needed
    public func loadModels(forceRefresh: Bool = false) async {
        // Check if we should use cache
        if !forceRefresh && shouldUseCache() {
            return
        }
        
        // Fetch from Hugging Face
        await fetchModelsFromHuggingFace()
    }
    
    /// Refresh models from Hugging Face
    public func refreshModels() async {
        await fetchModelsFromHuggingFace()
    }
    
    /// Get a specific model by ID
    public func model(withId id: String) -> WhisperKitModel? {
        models.first { $0.id == id }
    }
    
    /// Get models filtered by base model type
    public func models(forBaseModel baseModel: String) -> [WhisperKitModel] {
        models.filter { $0.baseModel == baseModel }
    }
    
    /// Get recommended models (curated list)
    public var recommendedModels: [WhisperKitModel] {
        // Define recommended model IDs
        let recommendedIds = [
            "openai_whisper-tiny",
            "openai_whisper-tiny.en",
            "openai_whisper-base",
            "openai_whisper-base.en",
            "openai_whisper-small",
            "openai_whisper-small.en",
            "openai_whisper-large-v3_turbo_954MB",
            "distil-whisper_distil-large-v3"
        ]
        
        return models.filter { recommendedIds.contains($0.id) }
            .sorted { m1, m2 in
                // Sort by size (smaller first)
                (m1.sizeInBytes ?? 0) < (m2.sizeInBytes ?? 0)
            }
    }
    
    // MARK: - Private Methods
    
    private func shouldUseCache() -> Bool {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return false
        }
        
        guard let lastRefresh = lastRefreshDate else {
            return false
        }
        
        // Check if cache is still valid
        return Date().timeIntervalSince(lastRefresh) < cacheExpirationInterval
    }
    
    private func loadCachedModels() {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            print("No cached models found")
            return
        }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let cache = try JSONDecoder().decode(ModelsCache.self, from: data)
            
            self.models = cache.models
            self.lastRefreshDate = cache.lastRefreshDate
            
            print("Loaded \(models.count) models from cache")
        } catch {
            print("Failed to load cached models: \(error)")
        }
    }
    
    private func saveCachedModels() {
        let cache = ModelsCache(
            models: models,
            lastRefreshDate: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(cache)
            try data.write(to: cacheURL)
            
            self.lastRefreshDate = cache.lastRefreshDate
            print("Saved \(models.count) models to cache")
        } catch {
            print("Failed to save models cache: \(error)")
        }
    }
    
    private func fetchModelsFromHuggingFace() async {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // For now, use a predefined list of WhisperKit models
            // In a real implementation, this would query the HF API
            let predefinedModels = getPredefinedModels()
            
            self.models = predefinedModels
            
            // Save to cache
            saveCachedModels()
            
            print("Fetched \(models.count) models")
        } catch {
            errorMessage = "Failed to fetch models: \(error.localizedDescription)"
            print("Error fetching models: \(error)")
        }
    }
    
    /// Get predefined list of WhisperKit models
    /// This is a curated list of known WhisperKit models from argmaxinc
    private func getPredefinedModels() -> [WhisperKitModel] {
        return [
            // Tiny models
            WhisperKitModel(
                id: "openai_whisper-tiny",
                repoPath: "openai_whisper-tiny",
                baseModel: "whisper-tiny",
                variant: nil,
                language: nil,
                sizeInBytes: 39_000_000,
                lastModified: Date()
            ),
            WhisperKitModel(
                id: "openai_whisper-tiny.en",
                repoPath: "openai_whisper-tiny.en",
                baseModel: "whisper-tiny",
                variant: nil,
                language: "en",
                sizeInBytes: 39_000_000,
                lastModified: Date()
            ),
            
            // Base models
            WhisperKitModel(
                id: "openai_whisper-base",
                repoPath: "openai_whisper-base",
                baseModel: "whisper-base",
                variant: nil,
                language: nil,
                sizeInBytes: 74_000_000,
                lastModified: Date()
            ),
            WhisperKitModel(
                id: "openai_whisper-base.en",
                repoPath: "openai_whisper-base.en",
                baseModel: "whisper-base",
                variant: nil,
                language: "en",
                sizeInBytes: 74_000_000,
                lastModified: Date()
            ),
            
            // Small models
            WhisperKitModel(
                id: "openai_whisper-small",
                repoPath: "openai_whisper-small",
                baseModel: "whisper-small",
                variant: nil,
                language: nil,
                sizeInBytes: 244_000_000,
                lastModified: Date()
            ),
            WhisperKitModel(
                id: "openai_whisper-small.en",
                repoPath: "openai_whisper-small.en",
                baseModel: "whisper-small",
                variant: nil,
                language: "en",
                sizeInBytes: 244_000_000,
                lastModified: Date()
            ),
            
            // Medium models
            WhisperKitModel(
                id: "openai_whisper-medium",
                repoPath: "openai_whisper-medium",
                baseModel: "whisper-medium",
                variant: nil,
                language: nil,
                sizeInBytes: 769_000_000,
                lastModified: Date()
            ),
            WhisperKitModel(
                id: "openai_whisper-medium.en",
                repoPath: "openai_whisper-medium.en",
                baseModel: "whisper-medium",
                variant: nil,
                language: "en",
                sizeInBytes: 769_000_000,
                lastModified: Date()
            ),
            
            // Large models
            WhisperKitModel(
                id: "openai_whisper-large-v2",
                repoPath: "openai_whisper-large-v2",
                baseModel: "whisper-large-v2",
                variant: nil,
                language: nil,
                sizeInBytes: 1_550_000_000,
                lastModified: Date()
            ),
            WhisperKitModel(
                id: "openai_whisper-large-v3",
                repoPath: "openai_whisper-large-v3",
                baseModel: "whisper-large-v3",
                variant: nil,
                language: nil,
                sizeInBytes: 1_550_000_000,
                lastModified: Date()
            ),
            WhisperKitModel(
                id: "openai_whisper-large-v3_turbo_954MB",
                repoPath: "openai_whisper-large-v3_turbo_954MB",
                baseModel: "whisper-large-v3",
                variant: "turbo_954MB",
                language: nil,
                sizeInBytes: 954_000_000,
                lastModified: Date()
            ),
            
            // Distil models
            WhisperKitModel(
                id: "distil-whisper_distil-large-v3",
                repoPath: "distil-whisper_distil-large-v3",
                baseModel: "distil-large-v3",
                variant: nil,
                language: nil,
                sizeInBytes: 756_000_000,
                lastModified: Date()
            ),
            WhisperKitModel(
                id: "distil-whisper_distil-medium.en",
                repoPath: "distil-whisper_distil-medium.en",
                baseModel: "distil-medium",
                variant: nil,
                language: "en",
                sizeInBytes: 394_000_000,
                lastModified: Date()
            ),
            WhisperKitModel(
                id: "distil-whisper_distil-small.en",
                repoPath: "distil-whisper_distil-small.en",
                baseModel: "distil-small",
                variant: nil,
                language: "en",
                sizeInBytes: 166_000_000,
                lastModified: Date()
            )
        ]
    }
    
    // MARK: - Cache Structure
    
    private struct ModelsCache: Codable {
        let models: [WhisperKitModel]
        let lastRefreshDate: Date
    }
}

// MARK: - Model Selection Helpers

extension WhisperKitModelRepository {
    /// Get the model that matches the legacy ModelType
    public func modelForLegacyType(_ type: ModelType) -> WhisperKitModel? {
        switch type {
        case .fast:
            return model(withId: "openai_whisper-tiny")
        case .balanced:
            return model(withId: "openai_whisper-base")
        case .accurate:
            return model(withId: "openai_whisper-small")
        }
    }
    
    /// Find best matching model for a given size constraint
    public func bestModel(maxSizeBytes: Int64, preferEnglish: Bool = false) -> WhisperKitModel? {
        let candidates = models.filter { model in
            guard let size = model.sizeInBytes else { return false }
            return size <= maxSizeBytes
        }
        
        // Sort by size (largest that fits)
        let sorted = candidates.sorted { m1, m2 in
            (m1.sizeInBytes ?? 0) > (m2.sizeInBytes ?? 0)
        }
        
        // If prefer English, try to find English variant
        if preferEnglish {
            return sorted.first { $0.language == "en" } ?? sorted.first
        }
        
        return sorted.first
    }
}