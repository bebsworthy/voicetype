//
//  ModelDownloader.swift
//  VoiceType
//
//  Model downloading with progress tracking, checksum validation, and resume support
//

import Foundation
import Combine
import CryptoKit
import Network

/// Observable model downloader with progress tracking and resumable downloads
@MainActor
public final class ModelDownloader: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var downloadProgress: Double = 0.0
    @Published public private(set) var downloadSpeed: Double = 0.0 // bytes per second
    @Published public private(set) var remainingTime: TimeInterval? = nil
    @Published public private(set) var isDownloading: Bool = false
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var currentDownloadTask: DownloadTask? = nil
    
    // MARK: - Types
    
    public struct DownloadTask {
        public let id: UUID
        public let url: URL
        public let destinationURL: URL
        public let expectedChecksum: String?
        public let totalBytes: Int64
        public var downloadedBytes: Int64
        public var startTime: Date
        
        public var progress: Double {
            guard totalBytes > 0 else { return 0 }
            return Double(downloadedBytes) / Double(totalBytes)
        }
    }
    
    public enum DownloadError: LocalizedError {
        case invalidURL
        case networkUnavailable
        case insufficientDiskSpace
        case checksumMismatch(expected: String, actual: String)
        case downloadFailed(Error)
        case fileSystemError(Error)
        case cancelled
        
        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid download URL"
            case .networkUnavailable:
                return "Network connection unavailable"
            case .insufficientDiskSpace:
                return "Insufficient disk space for download"
            case .checksumMismatch(let expected, let actual):
                return "Downloaded file checksum mismatch. Expected: \(expected), Got: \(actual)"
            case .downloadFailed(let error):
                return "Download failed: \(error.localizedDescription)"
            case .fileSystemError(let error):
                return "File system error: \(error.localizedDescription)"
            case .cancelled:
                return "Download cancelled"
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var downloadTask: URLSessionDownloadTask?
    private var urlSession: URLSession!
    private let fileManager = FileManager.default
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.voicetype.networkmonitor")
    private var speedCalculator = SpeedCalculator()
    private var resumeData: Data?
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupURLSession()
        setupNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Setup
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        config.allowsCellularAccess = true
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                // Network became available, attempt to resume if we have a paused download
                Task { @MainActor [weak self] in
                    if let self = self, self.isPaused, self.resumeData != nil {
                        try? await self.resume()
                    }
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Public Methods
    
    /// Download a model file with progress tracking and checksum validation
    public func downloadModel(
        from url: URL,
        to destinationURL: URL,
        expectedChecksum: String? = nil
    ) async throws {
        guard !isDownloading else {
            throw DownloadError.downloadFailed(NSError(domain: "ModelDownloader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Download already in progress"]))
        }
        
        // Check network availability
        guard networkMonitor.currentPath.status == .satisfied else {
            throw DownloadError.networkUnavailable
        }
        
        // Check disk space
        let requiredSpace = try await estimateRequiredSpace(for: url)
        guard hasAvailableDiskSpace(bytes: requiredSpace) else {
            throw DownloadError.insufficientDiskSpace
        }
        
        // Create destination directory if needed
        let destinationDir = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        
        // Check for existing partial download
        let partialURL = destinationURL.appendingPathExtension("partial")
        var startByte: Int64 = 0
        
        if fileManager.fileExists(atPath: partialURL.path) {
            startByte = try getFileSize(at: partialURL)
        }
        
        // Create download task
        let task = DownloadTask(
            id: UUID(),
            url: url,
            destinationURL: destinationURL,
            expectedChecksum: expectedChecksum,
            totalBytes: requiredSpace,
            downloadedBytes: startByte,
            startTime: Date()
        )
        
        currentDownloadTask = task
        isDownloading = true
        isPaused = false
        speedCalculator.reset()
        
        do {
            try await performDownload(task: task, partialURL: partialURL, startByte: startByte)
            
            // Validate checksum if provided
            if let expectedChecksum = expectedChecksum {
                let actualChecksum = try await calculateSHA256(for: destinationURL)
                guard actualChecksum == expectedChecksum else {
                    try? fileManager.removeItem(at: destinationURL)
                    throw DownloadError.checksumMismatch(expected: expectedChecksum, actual: actualChecksum)
                }
            }
            
            // Clean up partial file
            try? fileManager.removeItem(at: partialURL)
            
        } catch {
            isDownloading = false
            currentDownloadTask = nil
            throw error
        }
        
        isDownloading = false
        currentDownloadTask = nil
    }
    
    /// Pause the current download
    public func pause() {
        guard isDownloading, let task = downloadTask else { return }
        
        task.cancel { [weak self] resumeData in
            self?.resumeData = resumeData
            Task { @MainActor [weak self] in
                self?.isPaused = true
                self?.isDownloading = false
            }
        }
    }
    
    /// Resume a paused download
    public func resume() async throws {
        guard isPaused, let resumeData = resumeData else { return }
        
        isPaused = false
        isDownloading = true
        
        downloadTask = urlSession.downloadTask(withResumeData: resumeData)
        downloadTask?.resume()
        self.resumeData = nil
    }
    
    /// Cancel the current download
    public func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        resumeData = nil
        isDownloading = false
        isPaused = false
        currentDownloadTask = nil
        downloadProgress = 0.0
        downloadSpeed = 0.0
        remainingTime = nil
        
        // Clean up partial files
        if let task = currentDownloadTask {
            let partialURL = task.destinationURL.appendingPathExtension("partial")
            try? fileManager.removeItem(at: partialURL)
        }
    }
    
    // MARK: - Private Methods
    
    private func performDownload(task: DownloadTask, partialURL: URL, startByte: Int64) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: task.url)
            
            // Add range header for resume support
            if startByte > 0 {
                request.setValue("bytes=\(startByte)-", forHTTPHeaderField: "Range")
            }
            
            let downloadTask = urlSession.downloadTask(with: request) { [weak self] tempURL, response, error in
                guard let self = self else {
                    continuation.resume(throwing: DownloadError.cancelled)
                    return
                }
                
                if let error = error {
                    continuation.resume(throwing: DownloadError.downloadFailed(error))
                    return
                }
                
                guard let tempURL = tempURL else {
                    continuation.resume(throwing: DownloadError.downloadFailed(NSError(domain: "ModelDownloader", code: 2, userInfo: [NSLocalizedDescriptionKey: "No temporary file created"])))
                    return
                }
                
                do {
                    // Move or append to destination
                    if startByte > 0 {
                        // Append to existing partial file
                        try self.appendFile(from: tempURL, to: partialURL)
                        try self.fileManager.moveItem(at: partialURL, to: task.destinationURL)
                    } else {
                        // Direct move for new download
                        try self.fileManager.moveItem(at: tempURL, to: task.destinationURL)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: DownloadError.fileSystemError(error))
                }
            }
            
            self.downloadTask = downloadTask
            downloadTask.resume()
        }
    }
    
    private func estimateRequiredSpace(for url: URL) async throws -> Int64 {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        let (_, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length"),
              let bytes = Int64(contentLength) else {
            // Default to 1GB if we can't determine size
            return 1_073_741_824
        }
        
        return bytes
    }
    
    private func hasAvailableDiskSpace(bytes: Int64) -> Bool {
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())
            guard let freeSpace = attributes[.systemFreeSize] as? Int64 else { return false }
            // Require at least 10% buffer
            return freeSpace > Int64(Double(bytes) * 1.1)
        } catch {
            return false
        }
    }
    
    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func appendFile(from source: URL, to destination: URL) throws {
        let sourceHandle = try FileHandle(forReadingFrom: source)
        defer { sourceHandle.closeFile() }
        
        if !fileManager.fileExists(atPath: destination.path) {
            fileManager.createFile(atPath: destination.path, contents: nil)
        }
        
        let destHandle = try FileHandle(forWritingTo: destination)
        defer { destHandle.closeFile() }
        
        destHandle.seekToEndOfFile()
        
        let bufferSize = 65536 // 64KB chunks
        while true {
            let data = sourceHandle.readData(ofLength: bufferSize)
            if data.isEmpty { break }
            destHandle.write(data)
        }
    }
    
    private func calculateSHA256(for url: URL) async throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { handle.closeFile() }
        
        var hasher = SHA256()
        let bufferSize = 65536 // 64KB chunks
        
        while true {
            let data = handle.readData(ofLength: bufferSize)
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - URLSessionDownloadDelegate

extension ModelDownloader: URLSessionDownloadDelegate {
    nonisolated public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled in completion handler
    }
    
    nonisolated public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            guard var task = currentDownloadTask else { return }
            
            task.downloadedBytes = totalBytesWritten
            currentDownloadTask = task
            
            downloadProgress = task.progress
            
            // Update speed and remaining time
            speedCalculator.addSample(bytes: bytesWritten)
            downloadSpeed = speedCalculator.currentSpeed
            
            if downloadSpeed > 0 {
                let remainingBytes = totalBytesExpectedToWrite - totalBytesWritten
                remainingTime = TimeInterval(remainingBytes) / downloadSpeed
            }
        }
    }
    
    nonisolated public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                isDownloading = false
                if (error as NSError).code == NSURLErrorCancelled {
                    // Handled by pause/cancel methods
                } else {
                    // Actual error
                    currentDownloadTask = nil
                }
            }
        }
    }
}

// MARK: - Speed Calculator

private struct SpeedCalculator {
    private var samples: [(date: Date, bytes: Int64)] = []
    private let maxSamples = 10
    private let sampleWindow: TimeInterval = 5.0
    
    mutating func reset() {
        samples.removeAll()
    }
    
    mutating func addSample(bytes: Int64) {
        let now = Date()
        samples.append((date: now, bytes: bytes))
        
        // Remove old samples
        samples.removeAll { now.timeIntervalSince($0.date) > sampleWindow }
        
        // Keep only recent samples
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }
    
    var currentSpeed: Double {
        guard samples.count >= 2 else { return 0 }
        
        let totalBytes = samples.reduce(0) { $0 + $1.bytes }
        let duration = samples.last!.date.timeIntervalSince(samples.first!.date)
        
        guard duration > 0 else { return 0 }
        return Double(totalBytes) / duration
    }
}