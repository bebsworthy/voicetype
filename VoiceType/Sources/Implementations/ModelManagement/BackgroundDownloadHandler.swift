//
//  BackgroundDownloadHandler.swift
//  VoiceType
//
//  Handles background downloads and app lifecycle events
//

import Foundation
import AppKit
import Combine

/// Manages background downloads and continues downloads across app launches
public final class BackgroundDownloadHandler: NSObject {
    
    // MARK: - Singleton
    
    public static let shared = BackgroundDownloadHandler()
    
    // MARK: - Properties
    
    private var backgroundSession: URLSession!
    private var activeDownloads: [String: URLSessionDownloadTask] = [:]
    private var completionHandlers: [String: () -> Void] = [:]
    private let downloadQueue = DispatchQueue(label: "com.voicetype.download", qos: .utility)
    
    // Progress tracking
    private var progressSubjects: [String: PassthroughSubject<Double, Never>] = [:]
    private var speedTrackers: [String: SpeedTracker] = [:]
    
    // Events
    public let downloadCompleted = PassthroughSubject<(identifier: String, location: URL), Never>()
    public let downloadFailed = PassthroughSubject<(identifier: String, error: Error), Never>()
    public let downloadProgress = PassthroughSubject<(identifier: String, progress: Double), Never>()
    
    // Background task timer for macOS
    private var backgroundTimer: Timer?
    
    // MARK: - Configuration
    
    struct DownloadInfo: Codable {
        let identifier: String
        let url: URL
        let destinationPath: String
        let resumeData: Data?
        let checksum: String?
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupBackgroundSession()
        registerForAppLifecycleEvents()
        startBackgroundTimer()
    }
    
    // MARK: - Setup
    
    private func setupBackgroundSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.voicetype.modeldownload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.httpMaximumConnectionsPerHost = 2
        config.timeoutIntervalForResource = 60 * 60 * 24 // 24 hours
        
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    private func registerForAppLifecycleEvents() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }
    
    private func startBackgroundTimer() {
        // Schedule periodic maintenance tasks
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.performBackgroundMaintenance()
        }
    }
    
    // MARK: - Public Methods
    
    /// Start a background download
    public func startDownload(
        identifier: String,
        from url: URL,
        to destinationPath: String,
        checksum: String? = nil,
        resumeData: Data? = nil
    ) -> AnyPublisher<Double, Never> {
        let progressSubject = PassthroughSubject<Double, Never>()
        
        downloadQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Store progress subject
            self.progressSubjects[identifier] = progressSubject
            self.speedTrackers[identifier] = SpeedTracker()
            
            // Create download task
            let task: URLSessionDownloadTask
            if let resumeData = resumeData {
                task = self.backgroundSession.downloadTask(withResumeData: resumeData)
            } else {
                task = self.backgroundSession.downloadTask(with: url)
            }
            
            task.taskDescription = identifier
            
            // Store download info
            let info = DownloadInfo(
                identifier: identifier,
                url: url,
                destinationPath: destinationPath,
                resumeData: resumeData,
                checksum: checksum
            )
            self.saveDownloadInfo(info)
            
            // Start download
            self.activeDownloads[identifier] = task
            task.resume()
        }
        
        return progressSubject.eraseToAnyPublisher()
    }
    
    /// Cancel a download
    public func cancelDownload(identifier: String, saveResumeData: Bool = true) {
        downloadQueue.async { [weak self] in
            guard let self = self,
                  let task = self.activeDownloads[identifier] else { return }
            
            if saveResumeData {
                task.cancel { resumeData in
                    self.saveResumeData(resumeData, for: identifier)
                }
            } else {
                task.cancel()
            }
            
            self.cleanup(for: identifier)
        }
    }
    
    /// Get active download tasks
    public func activeDownloadTasks() async -> [String] {
        return await withCheckedContinuation { continuation in
            downloadQueue.async { [weak self] in
                guard let downloads = self?.activeDownloads else {
                    continuation.resume(returning: [])
                    return
                }
                let identifiers = Array(downloads.keys)
                continuation.resume(returning: identifiers)
            }
        }
    }
    
    // MARK: - Background Task Handling (macOS)
    
    @objc private func appWillTerminate() {
        // Save state before termination
        saveAllDownloadStates()
        backgroundTimer?.invalidate()
    }
    
    private func performBackgroundMaintenance() {
        Task {
            // Check for stalled downloads
            await checkStalledDownloads()
            
            // Clean up old temporary files
            cleanupTemporaryFiles()
            
            // Validate completed downloads
            await validateDownloadedModels()
        }
    }
    
    private func checkStalledDownloads() async {
        let activeTasks = await activeDownloadTasks()
        for identifier in activeTasks {
            if let tracker = speedTrackers[identifier], tracker.isStalled {
                // Consider restarting the download
                print("Download \(identifier) appears to be stalled")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func saveDownloadInfo(_ info: DownloadInfo) {
        let url = getDownloadInfoURL(for: info.identifier)
        do {
            let data = try JSONEncoder().encode(info)
            try data.write(to: url)
        } catch {
            print("Failed to save download info: \(error)")
        }
    }
    
    private func loadDownloadInfo(for identifier: String) -> DownloadInfo? {
        let url = getDownloadInfoURL(for: identifier)
        guard let data = try? Data(contentsOf: url),
              let info = try? JSONDecoder().decode(DownloadInfo.self, from: data) else {
            return nil
        }
        return info
    }
    
    private func getDownloadInfoURL(for identifier: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceTypeDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(identifier).json")
    }
    
    private func saveResumeData(_ data: Data?, for identifier: String) {
        guard let data = data else { return }
        let url = getResumeDataURL(for: identifier)
        try? data.write(to: url)
    }
    
    private func getResumeDataURL(for identifier: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceTypeDownloads", isDirectory: true)
        return directory.appendingPathComponent("\(identifier).resume")
    }
    
    private func cleanup(for identifier: String) {
        activeDownloads.removeValue(forKey: identifier)
        progressSubjects.removeValue(forKey: identifier)
        speedTrackers.removeValue(forKey: identifier)
        
        // Remove saved info
        try? FileManager.default.removeItem(at: getDownloadInfoURL(for: identifier))
        try? FileManager.default.removeItem(at: getResumeDataURL(for: identifier))
    }
    
    private func saveAllDownloadStates() {
        for (identifier, _) in activeDownloads {
            if let task = activeDownloads[identifier] {
                task.cancel { [weak self] resumeData in
                    self?.saveResumeData(resumeData, for: identifier)
                }
            }
        }
    }
    
    private func cleanupTemporaryFiles() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VoiceTypeDownloads", isDirectory: true)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days
        
        for file in files {
            if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
               creationDate < cutoffDate {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    private func validateDownloadedModels() async {
        // Implementation for validating downloaded models
        // This would check checksums, file integrity, etc.
    }
}

// MARK: - URLSessionDownloadDelegate

extension BackgroundDownloadHandler: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let identifier = downloadTask.taskDescription,
              let info = loadDownloadInfo(for: identifier) else { return }
        
        do {
            // Move file to destination
            let destinationURL = URL(fileURLWithPath: info.destinationPath)
            try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            // Verify checksum if provided
            if let expectedChecksum = info.checksum {
                // Implement checksum validation
                print("Validating checksum for \(identifier)")
            }
            
            downloadCompleted.send((identifier: identifier, location: destinationURL))
            cleanup(for: identifier)
            
        } catch {
            downloadFailed.send((identifier: identifier, error: error))
            cleanup(for: identifier)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let identifier = downloadTask.taskDescription else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressSubjects[identifier]?.send(progress)
        downloadProgress.send((identifier: identifier, progress: progress))
        
        // Update speed tracker
        speedTrackers[identifier]?.addBytes(Int(bytesWritten))
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let identifier = task.taskDescription else { return }
        
        if let error = error {
            downloadFailed.send((identifier: identifier, error: error))
            
            // Save resume data if available
            if let downloadTask = task as? URLSessionDownloadTask {
                downloadTask.cancel { [weak self] resumeData in
                    self?.saveResumeData(resumeData, for: identifier)
                }
            }
        }
        
        cleanup(for: identifier)
    }
}

// MARK: - Speed Tracking

private class SpeedTracker {
    private var measurements: [(timestamp: Date, bytes: Int)] = []
    private let measurementWindow: TimeInterval = 5.0
    
    var currentSpeed: Double {
        let now = Date()
        let cutoff = now.addingTimeInterval(-measurementWindow)
        
        // Remove old measurements
        measurements.removeAll { $0.timestamp < cutoff }
        
        guard measurements.count > 1,
              let first = measurements.first,
              let last = measurements.last else { return 0 }
        
        let totalBytes = measurements.reduce(0) { $0 + $1.bytes }
        let timeInterval = last.timestamp.timeIntervalSince(first.timestamp)
        
        return timeInterval > 0 ? Double(totalBytes) / timeInterval : 0
    }
    
    var isStalled: Bool {
        return measurements.isEmpty || (Date().timeIntervalSince(measurements.last?.timestamp ?? Date()) > 30)
    }
    
    func addBytes(_ bytes: Int) {
        measurements.append((timestamp: Date(), bytes: bytes))
    }
}