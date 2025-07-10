import Foundation
import WhisperKit
import VoiceTypeCore
import Combine
import os

/// Manages WhisperKit-specific model operations, bridging VoiceType's model management with WhisperKit's model system
@MainActor
public final class WhisperKitModelManager: ObservableObject {
    // MARK: - Published Properties

    @Published public private(set) var downloadProgress: Double = 0.0
    @Published public private(set) var isDownloading: Bool = false
    @Published public private(set) var currentDownloadTask: String?

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private var downloadTask: Task<Void, Error>?
    private let modelStorage: URL
    private let logger = Logger(subsystem: "com.voicetype", category: "WhisperKitModelManager")

    // MARK: - Constants

    private static let whisperKitModelRepo = "argmaxinc/whisperkit-coreml"
    private static let whisperKitDownloadBase = "https://huggingface.co/"

    // MARK: - Model Mapping

    /// Maps VoiceType ModelType to WhisperKit model names
    private func getWhisperKitModelName(for modelType: ModelType) -> String {
        switch modelType {
        case .fast:
            return "openai_whisper-tiny"
        case .balanced:
            return "openai_whisper-base"
        case .accurate:
            return "openai_whisper-small"
        }
    }

    /// Maps WhisperKit model name to VoiceType ModelType
    private func getModelType(from whisperKitName: String) -> ModelType? {
        switch whisperKitName {
        case "openai_whisper-tiny":
            return .fast
        case "openai_whisper-base":
            return .balanced
        case "openai_whisper-small":
            return .accurate
        default:
            return nil
        }
    }

    // MARK: - Initialization

    public init() {
        // Initialize model storage path
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.modelStorage = appSupport.appendingPathComponent("WhisperKit", isDirectory: true)

        // Ensure WhisperKit directory exists
        try? fileManager.createDirectory(at: modelStorage, withIntermediateDirectories: true)
    }

    // MARK: - Public Methods

    /// Check if a WhisperKit model is downloaded
    public func isModelDownloaded(modelType: ModelType) -> Bool {
        let modelName = getWhisperKitModelName(for: modelType)
        
        // First check if we have a stored WhisperKit location
        if let storedPath = UserDefaults.standard.string(forKey: "WhisperKitModel_\(modelName)"),
           fileManager.fileExists(atPath: storedPath) {
            // Verify it's a valid WhisperKit model
            let url = URL(fileURLWithPath: storedPath)
            return verifyWhisperKitModel(at: url)
        }
        
        // Otherwise check our default location
        let integrityResult = checkModelIntegrity(modelType: modelType)
        return integrityResult.isValid
    }
    
    /// Verify a WhisperKit model at a given location
    private func verifyWhisperKitModel(at url: URL) -> Bool {
        let requiredFiles = ["MelSpectrogram", "AudioEncoder", "TextDecoder"]
        
        for fileName in requiredFiles {
            let mlmodelc = url.appendingPathComponent("\(fileName).mlmodelc")
            let mlpackage = url.appendingPathComponent("\(fileName).mlpackage")
            
            if !fileManager.fileExists(atPath: mlmodelc.path) && 
               !fileManager.fileExists(atPath: mlpackage.path) {
                return false
            }
        }
        
        return true
    }

    /// Download a WhisperKit model
    public func downloadModel(modelType: ModelType) async throws {
        print("🔽 WhisperKitModelManager: Starting download for model: \(modelType.displayName)")
        logger.info("Starting download for model: \(modelType.displayName)")
        
        // Cancel any existing download
        downloadTask?.cancel()

        // Reset progress
        downloadProgress = 0.0
        isDownloading = true
        currentDownloadTask = modelType.displayName

        defer {
            isDownloading = false
            currentDownloadTask = nil
            downloadProgress = 0.0
            print("🔄 WhisperKitModelManager: Download state reset")
        }

        let modelName = getWhisperKitModelName(for: modelType)
        print("📦 WhisperKitModelManager: WhisperKit model name: \(modelName)")
        logger.debug("WhisperKit model name: \(modelName)")

        // Create a download task
        downloadTask = Task {
            try await performModelDownload(modelName: modelName, modelType: modelType)
        }

        do {
            try await downloadTask?.value
            print("✅ WhisperKitModelManager: Successfully downloaded model: \(modelType.displayName)")
            logger.info("Successfully downloaded model: \(modelType.displayName)")
        } catch {
            print("❌ WhisperKitModelManager: Failed to download model: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            logger.error("Failed to download model: \(error.localizedDescription)")
            throw error
        }
    }

    /// Delete a WhisperKit model
    public func deleteModel(modelType: ModelType) async throws {
        print("🗑️ WhisperKitModelManager: Deleting model \(modelType.displayName)")
        
        let modelName = getWhisperKitModelName(for: modelType)
        
        // Check if we have a stored WhisperKit location
        if let storedPath = UserDefaults.standard.string(forKey: "WhisperKitModel_\(modelName)"),
           fileManager.fileExists(atPath: storedPath) {
            print("📁 Deleting WhisperKit model at: \(storedPath)")
            try fileManager.removeItem(atPath: storedPath)
            UserDefaults.standard.removeObject(forKey: "WhisperKitModel_\(modelName)")
            print("✅ Model deleted successfully")
            return
        }
        
        // Check default location
        let modelPath = modelStorage.appendingPathComponent(modelName, isDirectory: true)
        
        if fileManager.fileExists(atPath: modelPath.path) {
            print("📁 Deleting model at default location: \(modelPath.path)")
            try fileManager.removeItem(at: modelPath)
            print("✅ Model deleted successfully")
        } else {
            print("❌ Model not found")
            throw WhisperKitModelError.modelNotFound(modelType: modelType)
        }
    }

    /// Get the file path for a downloaded model
    public func getModelPath(modelType: ModelType) -> URL? {
        let modelName = getWhisperKitModelName(for: modelType)
        
        // First check if we have a stored WhisperKit location
        if let storedPath = UserDefaults.standard.string(forKey: "WhisperKitModel_\(modelName)"),
           fileManager.fileExists(atPath: storedPath) {
            let url = URL(fileURLWithPath: storedPath)
            if verifyWhisperKitModel(at: url) {
                return url
            }
        }
        
        // Otherwise check our default location
        let defaultPath = modelStorage.appendingPathComponent(modelName, isDirectory: true)
        if fileManager.fileExists(atPath: defaultPath.path) {
            return defaultPath
        }
        
        return nil
    }

    /// Get current download progress (0.0 to 1.0)
    public func getDownloadProgress() -> Double {
        downloadProgress
    }

    /// Get all downloaded WhisperKit models
    public func getDownloadedModels() -> [ModelType] {
        var downloadedModels: [ModelType] = []

        for modelType in ModelType.allCases {
            if isModelDownloaded(modelType: modelType) {
                downloadedModels.append(modelType)
            }
        }

        return downloadedModels
    }
    
    // MARK: - Dynamic Model Support
    
    /// Check if a dynamic WhisperKit model is downloaded
    public func isDynamicModelDownloaded(modelId: String) -> Bool {
        // Check if we have a stored WhisperKit location for this model
        if let storedPath = UserDefaults.standard.string(forKey: "WhisperKitModel_\(modelId)"),
           fileManager.fileExists(atPath: storedPath) {
            let url = URL(fileURLWithPath: storedPath)
            return verifyWhisperKitModel(at: url)
        }
        
        // Check default location
        let modelPath = modelStorage.appendingPathComponent(modelId, isDirectory: true)
        if fileManager.fileExists(atPath: modelPath.path) {
            return verifyWhisperKitModel(at: modelPath)
        }
        
        return false
    }
    
    /// Download a dynamic WhisperKit model
    public func downloadDynamicModel(model: WhisperKitModel) async throws {
        print("🔽 WhisperKitModelManager: Starting download for dynamic model: \(model.displayName)")
        logger.info("Starting download for dynamic model: \(model.displayName)")
        
        // Cancel any existing download
        downloadTask?.cancel()
        
        // Reset progress
        downloadProgress = 0.0
        isDownloading = true
        currentDownloadTask = model.displayName
        
        defer {
            isDownloading = false
            currentDownloadTask = nil
            downloadProgress = 0.0
        }
        
        // Create a download task
        downloadTask = Task {
            try await performModelDownload(modelName: model.id, modelType: nil)
        }
        
        do {
            try await downloadTask?.value
            print("✅ WhisperKitModelManager: Successfully downloaded model: \(model.displayName)")
            logger.info("Successfully downloaded model: \(model.displayName)")
        } catch {
            print("❌ WhisperKitModelManager: Failed to download model: \(error)")
            logger.error("Failed to download model: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Delete a dynamic WhisperKit model
    public func deleteDynamicModel(modelId: String) async throws {
        print("🗑️ WhisperKitModelManager: Deleting dynamic model \(modelId)")
        
        // Check if we have a stored WhisperKit location
        if let storedPath = UserDefaults.standard.string(forKey: "WhisperKitModel_\(modelId)"),
           fileManager.fileExists(atPath: storedPath) {
            print("📁 Deleting WhisperKit model at: \(storedPath)")
            try fileManager.removeItem(atPath: storedPath)
            UserDefaults.standard.removeObject(forKey: "WhisperKitModel_\(modelId)")
            print("✅ Model deleted successfully")
            return
        }
        
        // Check default location
        let modelPath = modelStorage.appendingPathComponent(modelId, isDirectory: true)
        
        if fileManager.fileExists(atPath: modelPath.path) {
            print("📁 Deleting model at default location: \(modelPath.path)")
            try fileManager.removeItem(at: modelPath)
            print("✅ Model deleted successfully")
        } else {
            print("❌ Model not found")
            throw WhisperKitModelError.dynamicModelNotFound(modelId: modelId)
        }
    }
    
    /// Get the file path for a downloaded dynamic model
    public func getDynamicModelPath(modelId: String) -> URL? {
        // First check if we have a stored WhisperKit location
        if let storedPath = UserDefaults.standard.string(forKey: "WhisperKitModel_\(modelId)"),
           fileManager.fileExists(atPath: storedPath) {
            let url = URL(fileURLWithPath: storedPath)
            if verifyWhisperKitModel(at: url) {
                return url
            }
        }
        
        // Otherwise check our default location
        let defaultPath = modelStorage.appendingPathComponent(modelId, isDirectory: true)
        if fileManager.fileExists(atPath: defaultPath.path) {
            return defaultPath
        }
        
        return nil
    }
    
    /// Get all downloaded dynamic models
    public func getDownloadedDynamicModels() -> [String] {
        var downloadedModels: [String] = []
        
        // Check UserDefaults for all WhisperKitModel_ keys
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() {
            if key.hasPrefix("WhisperKitModel_"),
               let path = value as? String,
               fileManager.fileExists(atPath: path) {
                let modelId = String(key.dropFirst("WhisperKitModel_".count))
                downloadedModels.append(modelId)
            }
        }
        
        // Also check default location
        if let contents = try? fileManager.contentsOfDirectory(at: modelStorage, includingPropertiesForKeys: nil) {
            for url in contents {
                if url.hasDirectoryPath {
                    let modelId = url.lastPathComponent
                    if !downloadedModels.contains(modelId) && verifyWhisperKitModel(at: url) {
                        downloadedModels.append(modelId)
                    }
                }
            }
        }
        
        return downloadedModels
    }

    /// Get the size of a downloaded model in bytes
    public func getModelSize(modelType: ModelType) -> Int64? {
        guard let modelPath = getModelPath(modelType: modelType) else {
            return nil
        }

        return calculateDirectorySize(at: modelPath)
    }

    /// Verify model integrity
    public func verifyModel(modelType: ModelType) async -> Bool {
        guard isModelDownloaded(modelType: modelType) else {
            return false
        }

        // Try to initialize WhisperKit with the model to verify it works
        let modelName = getWhisperKitModelName(for: modelType)

        do {
            let computeOptions = ModelComputeOptions(
                audioEncoderCompute: .cpuAndGPU,
                textDecoderCompute: .cpuAndGPU
            )
            
            let config = WhisperKitConfig(
                model: modelName,
                downloadBase: URL(string: Self.whisperKitDownloadBase),
                modelRepo: Self.whisperKitModelRepo,
                modelFolder: modelStorage.path,
                computeOptions: computeOptions,
                verbose: false,
                logLevel: .error,
                prewarm: false,
                load: false,
                download: false
            )

            _ = try await WhisperKit(config)
            return true
        } catch {
            return false
        }
    }
    
    /// Comprehensive model integrity check with detailed results
    public struct ModelIntegrityResult {
        public let isValid: Bool
        public let directoryExists: Bool
        public let hasConfigFile: Bool
        public let hasModelFiles: Bool
        public let hasTokenizer: Bool
        public let totalSize: Int64
        public let missingFiles: [String]
        public let error: String?
        
        public init(
            isValid: Bool,
            directoryExists: Bool,
            hasConfigFile: Bool,
            hasModelFiles: Bool,
            hasTokenizer: Bool,
            totalSize: Int64,
            missingFiles: [String],
            error: String?
        ) {
            self.isValid = isValid
            self.directoryExists = directoryExists
            self.hasConfigFile = hasConfigFile
            self.hasModelFiles = hasModelFiles
            self.hasTokenizer = hasTokenizer
            self.totalSize = totalSize
            self.missingFiles = missingFiles
            self.error = error
        }
    }
    
    /// Perform detailed integrity check on a model
    public func checkModelIntegrity(modelType: ModelType) -> ModelIntegrityResult {
        let modelName = getWhisperKitModelName(for: modelType)
        
        // First check if we have a stored WhisperKit location
        if let storedPath = UserDefaults.standard.string(forKey: "WhisperKitModel_\(modelName)") {
            let url = URL(fileURLWithPath: storedPath)
            return checkModelIntegrityAtPath(url)
        }
        
        // Otherwise check default location
        let modelPath = modelStorage.appendingPathComponent(modelName, isDirectory: true)
        return checkModelIntegrityAtPath(modelPath)
    }
    
    private func checkModelIntegrityAtPath(_ modelPath: URL) -> ModelIntegrityResult {
        var missingFiles: [String] = []
        var directoryExists = false
        var hasConfigFile = false // For WhisperKit, we'll check for the required CoreML models
        var hasModelFiles = false
        var hasTokenizer = false // For WhisperKit, this will be true if all required models exist
        var totalSize: Int64 = 0
        var error: String?
        
        // Check if directory exists
        var isDirectory: ObjCBool = false
        directoryExists = fileManager.fileExists(atPath: modelPath.path, isDirectory: &isDirectory) && isDirectory.boolValue
        
        if !directoryExists {
            error = "Model directory does not exist"
        } else {
            // Check for WhisperKit required models
            let requiredModels = ["MelSpectrogram", "AudioEncoder", "TextDecoder"]
            var foundModels: [String] = []
            
            for modelName in requiredModels {
                // Check for either .mlmodelc or .mlpackage
                let mlmodelcPath = modelPath.appendingPathComponent("\(modelName).mlmodelc")
                let mlpackagePath = modelPath.appendingPathComponent("\(modelName).mlpackage")
                
                if fileManager.fileExists(atPath: mlmodelcPath.path) {
                    foundModels.append(modelName)
                    if let size = calculateDirectorySize(at: mlmodelcPath) {
                        totalSize += size
                    }
                } else if fileManager.fileExists(atPath: mlpackagePath.path) {
                    foundModels.append(modelName)
                    if let size = calculateDirectorySize(at: mlpackagePath) {
                        totalSize += size
                    }
                } else {
                    missingFiles.append("\(modelName).mlmodelc or \(modelName).mlpackage")
                }
            }
            
            // For WhisperKit models:
            // hasConfigFile represents having MelSpectrogram
            // hasModelFiles represents having AudioEncoder
            // hasTokenizer represents having TextDecoder
            hasConfigFile = foundModels.contains("MelSpectrogram")
            hasModelFiles = foundModels.contains("AudioEncoder")
            hasTokenizer = foundModels.contains("TextDecoder")
            
            // Calculate total directory size
            if let dirSize = calculateDirectorySize(at: modelPath) {
                totalSize = dirSize
            }
            
            // Check if we have all required models
            if foundModels.count < requiredModels.count {
                error = "Missing required WhisperKit models"
            }
        }
        
        let isValid = directoryExists && hasConfigFile && hasModelFiles && hasTokenizer && totalSize > 1024 * 1024 // At least 1MB
        
        return ModelIntegrityResult(
            isValid: isValid,
            directoryExists: directoryExists,
            hasConfigFile: hasConfigFile, // Represents MelSpectrogram
            hasModelFiles: hasModelFiles,  // Represents AudioEncoder
            hasTokenizer: hasTokenizer,    // Represents TextDecoder
            totalSize: totalSize,
            missingFiles: missingFiles,
            error: error
        )
    }
    
    /// Check integrity of all models and log results
    public func verifyAllModels() {
        print("🔍 Verifying all WhisperKit models...")
        print("📁 Model storage: \(modelStorage.path)")
        
        for modelType in ModelType.allCases {
            let result = checkModelIntegrity(modelType: modelType)
            
            print("\n📦 \(modelType.displayName):")
            if result.isValid {
                let sizeInMB = Double(result.totalSize) / 1024 / 1024
                print("   ✅ Valid (\(String(format: "%.1f", sizeInMB)) MB)")
            } else if !result.directoryExists {
                print("   ⭕ Not downloaded")
            } else {
                print("   ❌ Corrupted or incomplete")
                if !result.missingFiles.isEmpty {
                    print("   Missing: \(result.missingFiles.joined(separator: ", "))")
                }
                if let error = result.error {
                    print("   Error: \(error)")
                }
            }
        }
        print("")
    }

    // MARK: - Private Methods

    private func performModelDownload(modelName: String, modelType: ModelType?) async throws {
        print("🔧 performModelDownload: Using WhisperKit's built-in download for \(modelName)")
        logger.debug("Using WhisperKit's built-in download system")
        
        // WhisperKit handles its own directory creation, we just need to ensure our base directory exists
        try? fileManager.createDirectory(at: modelStorage, withIntermediateDirectories: true)
        
        // Use WhisperKit's built-in download functionality
        // Key: We let WhisperKit handle everything by just specifying the model name
        let config = WhisperKitConfig(
            model: modelName,
            downloadBase: nil, // Let WhisperKit use its default
            modelRepo: nil, // Let WhisperKit use its default repo
            modelFolder: nil, // Don't specify folder - let WhisperKit download to its default location
            computeOptions: nil, // Use defaults for download
            verbose: true,
            logLevel: .debug,
            prewarm: false,
            load: false, // Don't load after download
            download: true // This is the key - WhisperKit will download if needed
        )

        print("🌐 WhisperKit Config:")
        print("   Model: \(modelName)")
        print("   Model folder: nil (will use WhisperKit default)")
        print("   Download enabled: true")
        
        logger.info("Starting WhisperKit download for: \(modelName)")

        // Note: We can't monitor progress since we don't know WhisperKit's download location ahead of time

        do {
            // This will download the model if not already present
            print("🚀 Initializing WhisperKit to trigger download...")
            logger.info("Initializing WhisperKit with automatic download")
            
            // WhisperKit will automatically download the model when initialized with download: true
            let whisperKit = try await WhisperKit(config)
            
            downloadProgress = 1.0
            print("✅ WhisperKit initialization completed successfully")
            logger.info("WhisperKit initialization completed successfully")
            
            // Get the actual model folder where WhisperKit downloaded
            guard let downloadedModelFolder = whisperKit.modelFolder else {
                print("❌ WhisperKit didn't set a model folder")
                throw WhisperKitModelError.downloadFailed(modelType: modelType, underlyingError: NSError(domain: "WhisperKitModelManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "WhisperKit didn't set model folder after download"]))
            }
            
            print("✅ Model downloaded to: \(downloadedModelFolder.path)")
            
            // List the contents to verify
            if let contents = try? fileManager.contentsOfDirectory(at: downloadedModelFolder, includingPropertiesForKeys: nil) {
                print("📦 Downloaded files:")
                for file in contents {
                    print("   - \(file.lastPathComponent)")
                }
            }
            
            // Store the WhisperKit model location for this model type
            // We'll need to update our integrity checks to look at WhisperKit's location
            UserDefaults.standard.set(downloadedModelFolder.path, forKey: "WhisperKitModel_\(modelName)")
            
            // Debug: Print what we're storing
            print("📝 Storing model path in UserDefaults:")
            print("   Key: WhisperKitModel_\(modelName)")
            print("   Path: \(downloadedModelFolder.path)")
            
            print("✅ Model ready to use at: \(downloadedModelFolder.path)")
            
        } catch {
            print("❌ WhisperKit initialization/download failed: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error details: \(String(describing: error))")
            logger.error("WhisperKit download failed: \(error)")
            
            if let modelType = modelType {
                throw WhisperKitModelError.downloadFailed(modelType: modelType, underlyingError: error)
            } else {
                throw WhisperKitModelError.dynamicModelDownloadFailed(modelId: modelName, underlyingError: error)
            }
        }
    }

    private func monitorDownloadProgress(modelName: String, expectedSize: Int) async {
        let modelPath = modelStorage.appendingPathComponent(modelName, isDirectory: true)
        var lastSize: Int64 = 0
        var stuckCounter = 0

        while !Task.isCancelled {
            let currentSize = calculateDirectorySize(at: modelPath) ?? 0
            let progress = min(Double(currentSize) / Double(expectedSize), 0.99)

            await MainActor.run {
                self.downloadProgress = progress
            }
            
            // Log progress periodically
            if currentSize > lastSize {
                logger.debug("Download progress: \(Int(progress * 100))% (\(currentSize / 1024 / 1024) MB / \(expectedSize / 1024 / 1024) MB)")
                lastSize = currentSize
                stuckCounter = 0
            } else {
                stuckCounter += 1
                if stuckCounter > 20 { // 10 seconds with no progress
                    logger.warning("Download appears stuck at \(Int(progress * 100))%")
                }
            }

            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }

    private func calculateDirectorySize(at url: URL) -> Int64? {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: []
        ) else {
            return nil
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }

        return totalSize
    }
}

// MARK: - WhisperKit Model Error

public enum WhisperKitModelError: LocalizedError {
    case modelNotFound(modelType: ModelType)
    case downloadFailed(modelType: ModelType, underlyingError: Error)
    case invalidModelPath
    case verificationFailed(modelType: ModelType)
    case dynamicModelNotFound(modelId: String)
    case dynamicModelDownloadFailed(modelId: String, underlyingError: Error)

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let modelType):
            return "WhisperKit model '\(modelType.displayName)' not found"
        case .downloadFailed(let modelType, let error):
            return "Failed to download WhisperKit model '\(modelType.displayName)': \(error.localizedDescription)"
        case .invalidModelPath:
            return "Invalid WhisperKit model path"
        case .verificationFailed(let modelType):
            return "WhisperKit model '\(modelType.displayName)' verification failed"
        case .dynamicModelNotFound(let modelId):
            return "WhisperKit model '\(modelId)' not found"
        case .dynamicModelDownloadFailed(let modelId, let error):
            return "Failed to download WhisperKit model '\(modelId)': \(error.localizedDescription)"
        }
    }
}

// MARK: - Integration with ModelManager

extension WhisperKitModelManager {
    /// Create a ModelConfiguration for WhisperKit model download
    public func createModelConfiguration(for modelType: ModelType) -> ModelManager.ModelConfiguration {
        let modelName = getWhisperKitModelName(for: modelType)
        let downloadURL = URL(string: "\(Self.whisperKitDownloadBase)\(Self.whisperKitModelRepo)/resolve/main/\(modelName)")!

        return ModelManager.ModelConfiguration(
            name: modelName,
            version: "1.0",
            downloadURL: downloadURL,
            checksum: nil, // WhisperKit handles verification
            estimatedSize: Int64(modelType.sizeInMB * 1024 * 1024),
            minimumOSVersion: "17.0",
            requiredMemoryGB: Double(modelType.minimumRAMRequirement)
        )
    }

    /// Sync WhisperKit models with ModelManager
    public func syncWithModelManager(_ modelManager: ModelManager) async {
        for modelType in ModelType.allCases {
            if isModelDownloaded(modelType: modelType) {
                // Model is downloaded via WhisperKit but ModelManager might not know about it
                // This helps keep both systems in sync
                await modelManager.refreshInstalledModels()
            }
        }
    }
}
