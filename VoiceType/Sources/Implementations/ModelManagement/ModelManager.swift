//
//  ModelManager.swift
//  VoiceType
//
//  High-level model management coordinator
//

import Foundation
import Combine
import CoreML
import VoiceTypeCore

/// Coordinates model downloading, installation, and lifecycle management
@MainActor
public final class ModelManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var installedModels: [ModelInfo] = []
    @Published public private(set) var isRefreshing: Bool = false
    @Published public private(set) var downloadQueue: [ModelDownloadItem] = []
    
    // MARK: - Types
    
    public struct ModelDownloadItem: Identifiable {
        public let id = UUID()
        public let modelName: String
        public let version: String
        public let url: URL
        public let checksum: String?
        public let estimatedSize: Int64
        public var status: DownloadStatus = .pending
        
        public enum DownloadStatus {
            case pending
            case downloading(progress: Double)
            case installing
            case completed
            case failed(Error)
        }
    }
    
    public struct ModelConfiguration {
        public let name: String
        public let version: String
        public let downloadURL: URL
        public let checksum: String?
        public let estimatedSize: Int64
        public let minimumOSVersion: String?
        public let requiredMemoryGB: Double?
        
        public init(name: String,
                    version: String,
                    downloadURL: URL,
                    checksum: String? = nil,
                    estimatedSize: Int64,
                    minimumOSVersion: String? = nil,
                    requiredMemoryGB: Double? = nil) {
            self.name = name
            self.version = version
            self.downloadURL = downloadURL
            self.checksum = checksum
            self.estimatedSize = estimatedSize
            self.minimumOSVersion = minimumOSVersion
            self.requiredMemoryGB = requiredMemoryGB
        }
    }
    
    // MARK: - Private Properties
    
    private let downloader = ModelDownloader()
    private let fileManager = FileManager.default
    private var downloadCancellables = Set<AnyCancellable>()
    private let processQueue = DispatchQueue(label: "com.voicetype.modelmanager", qos: .utility)
    
    // MARK: - Initialization
    
    public init() {
        Task {
            await refreshInstalledModels()
        }
    }
    
    // MARK: - Helper Methods
    
    private func modelTypeFromString(_ type: String) -> ModelType {
        switch type.lowercased() {
        case "fast", "tiny":
            return .fast
        case "balanced", "base":
            return .balanced
        case "accurate", "small":
            return .accurate
        default:
            return .fast
        }
    }
    
    // MARK: - Public Methods
    
    /// Refresh the list of installed models
    public func refreshInstalledModels() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            let fileInfos = try fileManager.installedModels()
            installedModels = fileInfos.map { fileInfo in
                ModelInfo(
                    type: modelTypeFromString(fileInfo.name),
                    version: fileInfo.version,
                    path: fileInfo.path,
                    sizeInBytes: fileInfo.size,
                    isLoaded: false, // Would need to check with transcriber
                    lastUsed: fileInfo.lastAccessDate
                )
            }
        } catch {
            print("Failed to load installed models: \(error)")
            installedModels = []
        }
    }
    
    /// Download and install a model
    public func downloadModel(_ configuration: ModelConfiguration) async throws {
        // Check if already installed
        if try fileManager.isModelInstalled(name: configuration.name, version: configuration.version) {
            throw ModelStorageError.modelNotFound(name: configuration.name, version: configuration.version)
        }
        
        // Check disk space
        let availableSpace = fileManager.availableDiskSpace
        let requiredSpace = Int64(Double(configuration.estimatedSize) * 1.2) // 20% buffer
        
        guard availableSpace > requiredSpace else {
            throw ModelStorageError.insufficientDiskSpace(required: requiredSpace, available: availableSpace)
        }
        
        // Add to download queue
        let downloadItem = ModelDownloadItem(
            modelName: configuration.name,
            version: configuration.version,
            url: configuration.downloadURL,
            checksum: configuration.checksum,
            estimatedSize: configuration.estimatedSize
        )
        
        downloadQueue.append(downloadItem)
        
        // Update status
        updateDownloadStatus(id: downloadItem.id, status: .downloading(progress: 0))
        
        // Subscribe to download progress
        downloader.$downloadProgress
            .sink { [weak self] progress in
                self?.updateDownloadStatus(id: downloadItem.id, status: .downloading(progress: progress))
            }
            .store(in: &downloadCancellables)
        
        do {
            // Download to temporary location
            let tempURL = try fileManager.downloadsDirectory
                .appendingPathComponent("\(configuration.name)-\(configuration.version).download")
            
            try await downloader.downloadModel(
                from: configuration.downloadURL,
                to: tempURL,
                expectedChecksum: configuration.checksum
            )
            
            // Update status to installing
            updateDownloadStatus(id: downloadItem.id, status: .installing)
            
            // Install the model
            try await installModel(from: tempURL, configuration: configuration)
            
            // Clean up temp file
            try? fileManager.removeItem(at: tempURL)
            
            // Update status
            updateDownloadStatus(id: downloadItem.id, status: .completed)
            
            // Refresh installed models
            await refreshInstalledModels()
            
        } catch {
            updateDownloadStatus(id: downloadItem.id, status: .failed(error))
            throw error
        }
    }
    
    /// Delete an installed model
    public func deleteModel(name: String, version: String? = nil) async throws {
        try fileManager.deleteModel(name: name, version: version)
        await refreshInstalledModels()
    }
    
    /// Load a CoreML model
    public func loadModel(name: String, version: String? = nil) async throws -> MLModel {
        let modelPath = try fileManager.modelPath(for: name, version: version)
        
        // Look for .mlmodelc first (compiled), then .mlpackage
        let compiledPath = modelPath.appendingPathComponent("\(name).mlmodelc")
        let packagePath = modelPath.appendingPathComponent("\(name).mlpackage")
        
        let modelURL: URL
        if fileManager.fileExists(atPath: compiledPath.path) {
            modelURL = compiledPath
        } else if fileManager.fileExists(atPath: packagePath.path) {
            modelURL = packagePath
        } else {
            throw ModelStorageError.modelNotFound(name: name, version: version)
        }
        
        // Load model with configuration
        let config = MLModelConfiguration()
        config.computeUnits = .all // Use all available compute units
        
        return try await MLModel.load(contentsOf: modelURL, configuration: config)
    }
    
    /// Get storage information
    public func storageInfo() -> (used: Int64, available: Int64) {
        let used = (try? fileManager.modelStorageUsed()) ?? 0
        let available = fileManager.availableDiskSpace
        return (used, available)
    }
    
    /// Clean up cache and temporary files
    public func performMaintenance() async {
        do {
            try fileManager.cleanupCache()
            try fileManager.cleanupPartialDownloads()
        } catch {
            print("Maintenance error: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateDownloadStatus(id: UUID, status: ModelDownloadItem.DownloadStatus) {
        if let index = downloadQueue.firstIndex(where: { $0.id == id }) {
            downloadQueue[index].status = status
        }
    }
    
    private func installModel(from sourceURL: URL, configuration: ModelConfiguration) async throws {
        let destinationPath = try fileManager.modelPath(for: configuration.name, version: configuration.version)
        
        // Create model directory
        try fileManager.createDirectory(at: destinationPath, withIntermediateDirectories: true)
        
        // Extract if it's a zip file
        if sourceURL.pathExtension == "zip" {
            try await extractZip(from: sourceURL, to: destinationPath)
        } else {
            // Move the model file
            let modelName = sourceURL.deletingPathExtension().lastPathComponent
            let destinationURL = destinationPath.appendingPathComponent(modelName)
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
        }
        
        // Save metadata
        let metadata = ModelInfo(
            type: modelTypeFromString(configuration.name),
            version: configuration.version,
            path: destinationPath,
            sizeInBytes: configuration.estimatedSize,
            isLoaded: false,
            lastUsed: Date()
        )
        
        let metadataURL = destinationPath.appendingPathComponent("metadata.json")
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: metadataURL)
    }
    
    private func extractZip(from sourceURL: URL, to destinationURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            processQueue.async {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                    process.arguments = ["-q", sourceURL.path, "-d", destinationURL.path]
                    
                    try process.run()
                    process.waitUntilExit()
                    
                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "ModelManager",
                            code: Int(process.terminationStatus),
                            userInfo: [NSLocalizedDescriptionKey: "Failed to extract model archive"]
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Model Manager Error

public enum ModelManagerError: LocalizedError {
    case modelAlreadyInstalled(name: String, version: String)
    case downloadInProgress
    case invalidModelPackage
    case extractionFailed
    
    public var errorDescription: String? {
        switch self {
        case .modelAlreadyInstalled(let name, let version):
            return "Model '\(name)' version '\(version)' is already installed"
        case .downloadInProgress:
            return "A model download is already in progress"
        case .invalidModelPackage:
            return "Invalid model package format"
        case .extractionFailed:
            return "Failed to extract model package"
        }
    }
}