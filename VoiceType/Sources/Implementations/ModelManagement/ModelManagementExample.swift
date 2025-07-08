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

                    ForEach(modelManager.installedModels, id: \.path) { model in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(model.type.rawValue.capitalized)
                                    .font(.body)
                                Text("Version: \(model.version)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(formatBytes(model.sizeInBytes))
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button("Delete") {
                                Task {
                                    do {
                                        try await modelManager.deleteModel(
                                            name: model.type.rawValue,
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
@MainActor
func exampleDownloadModel() async throws {
    let downloader = ModelDownloader()

    // Subscribe to progress updates
    _ = await downloader.$downloadProgress
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
@MainActor
func exampleManageModels() async throws {
    let manager = ModelManager()

    // Refresh installed models
    await manager.refreshInstalledModels()

    // List models
    for model in await manager.installedModels {
        print("Model: \(model.type.rawValue) v\(model.version)")
        print("  Size: \(ByteCountFormatter.string(fromByteCount: model.sizeInBytes, countStyle: .binary))")
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
    let completedCancellable = backgroundHandler.downloadCompleted
        .sink { result in
            print("Download completed: \(result.identifier) at \(result.location)")
        }

    let failedCancellable = backgroundHandler.downloadFailed
        .sink { result in
            print("Download failed: \(result.identifier) - \(result.error)")
        }

    let progressCancellable = backgroundHandler.downloadProgress
        .sink { result in
            print("Download progress: \(result.identifier) - \(Int(result.progress * 100))%")
        }

    // Start a background download
    let progressPublisher = backgroundHandler.startDownload(
        identifier: "large-model-v2.0",
        from: URL(string: "https://example.com/models/large-model.zip")!,
        to: "/path/to/destination/large-model.zip",
        checksum: "abc123..."
    )

    // Subscribe to specific download progress
    _ = progressPublisher
        .sink { progress in
            print("Large model progress: \(Int(progress * 100))%")
        }

    print("Started background download task")
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
