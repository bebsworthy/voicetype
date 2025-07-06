//
//  FileManager+ModelStorage.swift
//  VoiceType
//
//  FileManager extensions for model storage management
//

import Foundation

public extension FileManager {
    
    // MARK: - Model Storage Paths
    
    /// Base directory for VoiceType application support
    var voiceTypeDirectory: URL {
        get throws {
            let appSupport = try url(for: .applicationSupportDirectory,
                                   in: .userDomainMask,
                                   appropriateFor: nil,
                                   create: true)
            let voiceTypeDir = appSupport.appendingPathComponent("VoiceType", isDirectory: true)
            
            if !fileExists(atPath: voiceTypeDir.path) {
                try createDirectory(at: voiceTypeDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            return voiceTypeDir
        }
    }
    
    /// Directory for storing ML models
    var modelsDirectory: URL {
        get throws {
            let modelsDir = try voiceTypeDirectory.appendingPathComponent("models", isDirectory: true)
            
            if !fileExists(atPath: modelsDir.path) {
                try createDirectory(at: modelsDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            return modelsDir
        }
    }
    
    /// Directory for temporary downloads
    var downloadsDirectory: URL {
        get throws {
            let downloadsDir = try voiceTypeDirectory.appendingPathComponent("downloads", isDirectory: true)
            
            if !fileExists(atPath: downloadsDir.path) {
                try createDirectory(at: downloadsDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            return downloadsDir
        }
    }
    
    /// Directory for cache files
    var cacheDirectory: URL {
        get throws {
            let cacheDir = try url(for: .cachesDirectory,
                                 in: .userDomainMask,
                                 appropriateFor: nil,
                                 create: true)
                .appendingPathComponent("VoiceType", isDirectory: true)
            
            if !fileExists(atPath: cacheDir.path) {
                try createDirectory(at: cacheDir, withIntermediateDirectories: true, attributes: nil)
            }
            
            return cacheDir
        }
    }
    
    // MARK: - Model File Management
    
    /// Get the path for a specific model
    func modelPath(for modelName: String, version: String? = nil) throws -> URL {
        let modelDir = try modelsDirectory
        
        if let version = version {
            return modelDir
                .appendingPathComponent(modelName, isDirectory: true)
                .appendingPathComponent(version, isDirectory: true)
        } else {
            return modelDir.appendingPathComponent(modelName, isDirectory: true)
        }
    }
    
    /// List all installed models
    func installedModels() throws -> [ModelFileInfo] {
        let modelsDir = try modelsDirectory
        let contents = try contentsOfDirectory(at: modelsDir,
                                             includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
                                             options: .skipsHiddenFiles)
        
        var models: [ModelFileInfo] = []
        
        for modelDir in contents {
            let resourceValues = try modelDir.resourceValues(forKeys: [.isDirectoryKey])
            guard resourceValues.isDirectory == true else { continue }
            
            let modelName = modelDir.lastPathComponent
            
            // Check for versioned subdirectories
            let versionDirs = try contentsOfDirectory(at: modelDir,
                                                    includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey],
                                                    options: .skipsHiddenFiles)
            
            if versionDirs.isEmpty {
                // Unversioned model
                if let modelInfo = try? loadModelInfo(at: modelDir, name: modelName, version: nil) {
                    models.append(modelInfo)
                }
            } else {
                // Versioned models
                for versionDir in versionDirs {
                    let versionValues = try versionDir.resourceValues(forKeys: [.isDirectoryKey])
                    guard versionValues.isDirectory == true else { continue }
                    
                    let version = versionDir.lastPathComponent
                    if let modelInfo = try? loadModelInfo(at: versionDir, name: modelName, version: version) {
                        models.append(modelInfo)
                    }
                }
            }
        }
        
        return models
    }
    
    /// Check if a model is installed
    func isModelInstalled(name: String, version: String? = nil) throws -> Bool {
        let modelPath = try modelPath(for: name, version: version)
        
        // Check for .mlpackage or .mlmodelc
        let mlpackagePath = modelPath.appendingPathComponent("\(name).mlpackage")
        let mlmodelcPath = modelPath.appendingPathComponent("\(name).mlmodelc")
        
        return fileExists(atPath: mlpackagePath.path) || fileExists(atPath: mlmodelcPath.path)
    }
    
    /// Delete a model
    func deleteModel(name: String, version: String? = nil) throws {
        let modelPath = try modelPath(for: name, version: version)
        
        if fileExists(atPath: modelPath.path) {
            try removeItem(at: modelPath)
        }
    }
    
    // MARK: - Disk Space Management
    
    /// Get available disk space in bytes
    var availableDiskSpace: Int64 {
        do {
            let attributes = try attributesOfFileSystem(forPath: NSHomeDirectory())
            return attributes[.systemFreeSize] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    /// Get used disk space by models in bytes
    func modelStorageUsed() throws -> Int64 {
        let modelsDir = try modelsDirectory
        return try directorySize(at: modelsDir)
    }
    
    /// Clean up old cache files
    func cleanupCache(olderThan days: Int = 7) throws {
        let cacheDir = try cacheDirectory
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        
        let contents = try contentsOfDirectory(at: cacheDir,
                                             includingPropertiesForKeys: [.contentModificationDateKey],
                                             options: .skipsHiddenFiles)
        
        for file in contents {
            let resourceValues = try file.resourceValues(forKeys: [.contentModificationDateKey])
            if let modificationDate = resourceValues.contentModificationDate,
               modificationDate < cutoffDate {
                try removeItem(at: file)
            }
        }
    }
    
    /// Clean up partial downloads
    func cleanupPartialDownloads() throws {
        let downloadsDir = try downloadsDirectory
        let contents = try contentsOfDirectory(at: downloadsDir,
                                             includingPropertiesForKeys: nil,
                                             options: .skipsHiddenFiles)
        
        for file in contents {
            if file.pathExtension == "partial" {
                try removeItem(at: file)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func directorySize(at url: URL) throws -> Int64 {
        var size: Int64 = 0
        
        let contents = try contentsOfDirectory(at: url,
                                             includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                                             options: .skipsHiddenFiles)
        
        for item in contents {
            let resourceValues = try item.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
            
            if resourceValues.isDirectory == true {
                size += try directorySize(at: item)
            } else {
                size += Int64(resourceValues.fileSize ?? 0)
            }
        }
        
        return size
    }
    
    private func loadModelInfo(at url: URL, name: String, version: String?) throws -> ModelFileInfo? {
        // Look for model metadata file
        let metadataPath = url.appendingPathComponent("metadata.json")
        
        if fileExists(atPath: metadataPath.path) {
            let data = try Data(contentsOf: metadataPath)
            var info = try JSONDecoder().decode(ModelFileInfo.self, from: data)
            info.name = name // Ensure consistency
            info.version = version ?? info.version
            return info
        }
        
        // Create basic info if no metadata
        let attributes = try attributesOfItem(atPath: url.path)
        let creationDate = attributes[.creationDate] as? Date ?? Date()
        let size = try directorySize(at: url)
        
        return ModelFileInfo(
            name: name,
            version: version ?? "1.0",
            path: url,
            size: size,
            creationDate: creationDate,
            lastAccessDate: Date()
        )
    }
}

// MARK: - Model Info

public struct ModelFileInfo: Codable {
    public var name: String
    public var version: String
    public var path: URL
    public var size: Int64
    public var creationDate: Date
    public var lastAccessDate: Date
    public var checksum: String?
    public var metadata: [String: String]?
    
    public init(name: String,
                version: String,
                path: URL,
                size: Int64,
                creationDate: Date,
                lastAccessDate: Date,
                checksum: String? = nil,
                metadata: [String: String]? = nil) {
        self.name = name
        self.version = version
        self.path = path
        self.size = size
        self.creationDate = creationDate
        self.lastAccessDate = lastAccessDate
        self.checksum = checksum
        self.metadata = metadata
    }
}

// MARK: - Model Storage Error

public enum ModelStorageError: LocalizedError {
    case modelNotFound(name: String, version: String?)
    case insufficientDiskSpace(required: Int64, available: Int64)
    case invalidModelFormat
    case metadataCorrupted
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let name, let version):
            if let version = version {
                return "Model '\(name)' version '\(version)' not found"
            } else {
                return "Model '\(name)' not found"
            }
        case .insufficientDiskSpace(let required, let available):
            let formatter = ByteCountFormatter()
            let requiredStr = formatter.string(fromByteCount: required)
            let availableStr = formatter.string(fromByteCount: available)
            return "Insufficient disk space. Required: \(requiredStr), Available: \(availableStr)"
        case .invalidModelFormat:
            return "Invalid model format. Expected .mlpackage or .mlmodelc"
        case .metadataCorrupted:
            return "Model metadata is corrupted"
        }
    }
}