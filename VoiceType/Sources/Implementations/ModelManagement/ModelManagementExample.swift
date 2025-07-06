//
//  ModelManagementExample.swift
//  VoiceType
//
//  Example usage of the model management system
//

import Foundation
import SwiftUI

/// Example view demonstrating model management
struct ModelManagementExampleView: View {
    @StateObject private var modelManager = ModelManager()
    @StateObject private var modelDownloader = ModelDownloader()
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Download progress
            if modelDownloader.isDownloading {
                VStack {
                    Text("Downloading Model...")
                        .font(.headline)
                    
                    ProgressView(value: modelDownloader.downloadProgress)
                        .progressViewStyle(.linear)
                    
                    HStack {
                        Text("Speed: \(formatSpeed(modelDownloader.downloadSpeed))")
                        Spacer()
                        if let remaining = modelDownloader.remainingTime {
                            Text("Remaining: \(formatTime(remaining))")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Pause") {
                            modelDownloader.pause()
                        }
                        
                        Button("Cancel") {
                            modelDownloader.cancel()
                        }
                        .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Installed models
            if !modelManager.installedModels.isEmpty {
                VStack(alignment: .leading) {
                    Text("Installed Models")
                        .font(.headline)
                    
                    ForEach(modelManager.installedModels, id: \.name) { model in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(model.name)
                                    .font(.body)
                                Text("Version: \(model.version)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(formatBytes(model.size))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button("Delete") {
                                Task {
                                    do {
                                        try await modelManager.deleteModel(
                                            name: model.name,
                                            version: model.version
                                        )
                                    } catch {
                                        showError(error)
                                    }
                                }
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            
            // Storage info
            let storageInfo = modelManager.storageInfo()
            HStack {
                Text("Storage Used: \(formatBytes(storageInfo.used))")
                Spacer()
                Text("Available: \(formatBytes(storageInfo.available))")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            // Download button
            Button("Download Sample Model") {
                downloadSampleModel()
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Actions
    
    private func downloadSampleModel() {
        Task {
            do {
                // Example model configuration
                let config = ModelManager.ModelConfiguration(
                    name: "whisper-base",
                    version: "1.0",
                    downloadURL: URL(string: "https://example.com/models/whisper-base.mlpackage.zip")!,
                    checksum: "abc123def456...", // SHA256 checksum
                    estimatedSize: 150_000_000, // 150MB
                    minimumOSVersion: "13.0",
                    requiredMemoryGB: 2.0
                )
                
                try await modelManager.downloadModel(config)
            } catch {
                showError(error)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func showError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: seconds) ?? "--"
    }
}

// MARK: - Example Usage Functions

/// Example: Download a model with progress tracking
func exampleDownloadModel() async throws {
    let downloader = ModelDownloader()
    
    // Subscribe to progress updates
    let cancellable = downloader.$downloadProgress
        .sink { progress in
            print("Download progress: \(Int(progress * 100))%")
        }
    
    // Download model
    let modelURL = URL(string: "https://example.com/models/whisper-base.mlpackage")!
    let destinationURL = try FileManager.default.modelsDirectory
        .appendingPathComponent("whisper-base")
        .appendingPathComponent("whisper-base.mlpackage")
    
    try await downloader.downloadModel(
        from: modelURL,
        to: destinationURL,
        expectedChecksum: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    )
    
    print("Model downloaded successfully!")
}

/// Example: List and manage installed models
func exampleManageModels() async throws {
    let manager = ModelManager()
    
    // Refresh installed models
    await manager.refreshInstalledModels()
    
    // List models
    for model in manager.installedModels {
        print("Model: \(model.name) v\(model.version)")
        print("  Size: \(ByteCountFormatter.string(fromByteCount: model.size, countStyle: .binary))")
        print("  Path: \(model.path)")
    }
    
    // Load a model
    let mlModel = try await manager.loadModel(name: "whisper-base", version: "1.0")
    print("Loaded CoreML model: \(mlModel)")
    
    // Delete a model
    try await manager.deleteModel(name: "old-model", version: "0.9")
}

/// Example: Setup background downloads
func exampleBackgroundDownload() {
    let backgroundHandler = BackgroundDownloadHandler.shared
    
    // Subscribe to download events
    let cancellable = backgroundHandler.downloadEvents
        .sink { event in
            switch event {
            case .started(let name, let version):
                print("Started downloading \(name) v\(version)")
            case .progress(let name, let version, let progress):
                print("\(name) v\(version): \(Int(progress * 100))%")
            case .completed(let name, let version, let url):
                print("Completed \(name) v\(version) at \(url)")
            case .failed(let name, let version, let error):
                print("Failed \(name) v\(version): \(error)")
            case .paused(let name, let version, let resumeData):
                print("Paused \(name) v\(version), can resume: \(resumeData != nil)")
            }
        }
    
    // Start a background download
    let task = backgroundHandler.startBackgroundDownload(
        from: URL(string: "https://example.com/models/large-model.zip")!,
        modelName: "large-model",
        version: "2.0",
        destinationURL: URL(fileURLWithPath: "/path/to/destination"),
        checksum: "abc123..."
    )
    
    print("Started background download task: \(task)")
}

/// Example: File management
func exampleFileManagement() throws {
    let fileManager = FileManager.default
    
    // Get VoiceType directories
    let voiceTypeDir = try fileManager.voiceTypeDirectory
    let modelsDir = try fileManager.modelsDirectory
    let cacheDir = try fileManager.cacheDirectory
    
    print("VoiceType directory: \(voiceTypeDir)")
    print("Models directory: \(modelsDir)")
    print("Cache directory: \(cacheDir)")
    
    // Check disk space
    let availableSpace = fileManager.availableDiskSpace
    print("Available disk space: \(ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .binary))")
    
    // Check model storage usage
    let modelStorageUsed = try fileManager.modelStorageUsed()
    print("Model storage used: \(ByteCountFormatter.string(fromByteCount: modelStorageUsed, countStyle: .binary))")
    
    // Clean up old cache files
    try fileManager.cleanupCache(olderThan: 7) // 7 days
    
    // Clean up partial downloads
    try fileManager.cleanupPartialDownloads()
}