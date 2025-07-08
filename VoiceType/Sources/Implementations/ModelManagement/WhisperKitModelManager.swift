import Foundation
import WhisperKit
import VoiceTypeCore
import Combine

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
        let modelPath = modelStorage.appendingPathComponent(modelName, isDirectory: true)

        // Check if the model directory exists and contains the expected files
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: modelPath.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }

        // Check for essential model files
        let requiredFiles = ["config.json", "model.mlmodelc", "tokenizer.json"]
        for file in requiredFiles {
            let filePath = modelPath.appendingPathComponent(file)

            // For model.mlmodelc, it might be a directory
            var fileIsDirectory: ObjCBool = false
            if !fileManager.fileExists(atPath: filePath.path, isDirectory: &fileIsDirectory) {
                // Try with .mlpackage extension
                let mlpackagePath = modelPath.appendingPathComponent("model.mlpackage")
                if !fileManager.fileExists(atPath: mlpackagePath.path) {
                    return false
                }
            }
        }

        return true
    }

    /// Download a WhisperKit model
    public func downloadModel(modelType: ModelType) async throws {
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
        }

        let modelName = getWhisperKitModelName(for: modelType)

        // Create a download task
        downloadTask = Task {
            try await performModelDownload(modelName: modelName, modelType: modelType)
        }

        try await downloadTask?.value
    }

    /// Delete a WhisperKit model
    public func deleteModel(modelType: ModelType) async throws {
        let modelName = getWhisperKitModelName(for: modelType)
        let modelPath = modelStorage.appendingPathComponent(modelName, isDirectory: true)

        // Check if model exists
        guard fileManager.fileExists(atPath: modelPath.path) else {
            throw WhisperKitModelError.modelNotFound(modelType: modelType)
        }

        // Delete the model directory
        try fileManager.removeItem(at: modelPath)
    }

    /// Get the file path for a downloaded model
    public func getModelPath(modelType: ModelType) -> URL? {
        guard isModelDownloaded(modelType: modelType) else {
            return nil
        }

        let modelName = getWhisperKitModelName(for: modelType)
        return modelStorage.appendingPathComponent(modelName, isDirectory: true)
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
            let config = WhisperKitConfig(
                model: modelName,
                downloadBase: URL(string: Self.whisperKitDownloadBase),
                modelRepo: Self.whisperKitModelRepo,
                modelFolder: modelStorage.path,
                computeOptions: ModelComputeOptions(),
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

    // MARK: - Private Methods

    private func performModelDownload(modelName: String, modelType: ModelType) async throws {
        // Use WhisperKit's built-in download functionality
        let config = WhisperKitConfig(
            model: modelName,
            downloadBase: URL(string: Self.whisperKitDownloadBase),
            modelRepo: Self.whisperKitModelRepo,
            modelFolder: modelStorage.path,
            computeOptions: ModelComputeOptions(),
            verbose: true,
            logLevel: .debug,
            prewarm: false,
            load: false,
            download: true
        )

        // Monitor download progress by checking file sizes periodically
        let progressTask = Task {
            await monitorDownloadProgress(modelName: modelName, expectedSize: modelType.sizeInMB * 1024 * 1024)
        }

        do {
            // This will download the model if not already present
            _ = try await WhisperKit(config)
            progressTask.cancel()
            downloadProgress = 1.0
        } catch {
            progressTask.cancel()
            throw WhisperKitModelError.downloadFailed(modelType: modelType, underlyingError: error)
        }
    }

    private func monitorDownloadProgress(modelName: String, expectedSize: Int) async {
        let modelPath = modelStorage.appendingPathComponent(modelName, isDirectory: true)

        while !Task.isCancelled {
            let currentSize = calculateDirectorySize(at: modelPath) ?? 0
            let progress = min(Double(currentSize) / Double(expectedSize), 0.99)

            await MainActor.run {
                self.downloadProgress = progress
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
