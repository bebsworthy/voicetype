//
//  BackgroundDownloadHandler.swift
//  VoiceType
//
//  Handles background downloads and app lifecycle events
//

import Foundation
import Combine
import BackgroundTasks

/// Manages background downloads and continues downloads across app launches
public final class BackgroundDownloadHandler: NSObject {
    
    // MARK: - Singleton
    
    public static let shared = BackgroundDownloadHandler()
    
    // MARK: - Properties
    
    private var backgroundSession: URLSession!
    private var completionHandlers: [String: () -> Void] = [:]
    private var activeDownloads: [URLSessionDownloadTask: DownloadInfo] = [:]
    private let downloadSubject = PassthroughSubject<DownloadEvent, Never>()
    
    public var downloadEvents: AnyPublisher<DownloadEvent, Never> {
        downloadSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Types
    
    public struct DownloadInfo {
        public let modelName: String
        public let version: String
        public let destinationURL: URL
        public let checksum: String?
        public var resumeData: Data?
        
        public init(modelName: String,
                    version: String,
                    destinationURL: URL,
                    checksum: String?) {
            self.modelName = modelName
            self.version = version
            self.destinationURL = destinationURL
            self.checksum = checksum
        }
    }
    
    public enum DownloadEvent {
        case started(modelName: String, version: String)
        case progress(modelName: String, version: String, progress: Double)
        case completed(modelName: String, version: String, url: URL)
        case failed(modelName: String, version: String, error: Error)
        case paused(modelName: String, version: String, resumeData: Data?)
    }
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupBackgroundSession()
        registerBackgroundTasks()
    }
    
    // MARK: - Setup
    
    private func setupBackgroundSession() {
        let config = URLSessionConfiguration.background(withIdentifier: "com.voicetype.modeldownload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        config.allowsCellularAccess = true
        config.shouldUseExtendedBackgroundIdleMode = true
        
        // Configure for large downloads
        config.timeoutIntervalForResource = 60 * 60 * 24 // 24 hours
        config.httpMaximumConnectionsPerHost = 2
        
        backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.voicetype.modeldownload.refresh",
            using: nil
        ) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.voicetype.modeldownload.processing",
            using: nil
        ) { task in
            self.handleBackgroundProcessing(task: task as! BGProcessingTask)
        }
    }
    
    // MARK: - Public Methods
    
    /// Start a background download
    public func startBackgroundDownload(
        from url: URL,
        modelName: String,
        version: String,
        destinationURL: URL,
        checksum: String? = nil
    ) -> URLSessionDownloadTask {
        let downloadInfo = DownloadInfo(
            modelName: modelName,
            version: version,
            destinationURL: destinationURL,
            checksum: checksum
        )
        
        let task = backgroundSession.downloadTask(with: url)
        activeDownloads[task] = downloadInfo
        
        downloadSubject.send(.started(modelName: modelName, version: version))
        task.resume()
        
        scheduleBackgroundRefresh()
        return task
    }
    
    /// Resume a paused download
    public func resumeDownload(with resumeData: Data, downloadInfo: DownloadInfo) -> URLSessionDownloadTask? {
        guard let task = backgroundSession.downloadTask(withResumeData: resumeData) else {
            return nil
        }
        
        activeDownloads[task] = downloadInfo
        task.resume()
        
        return task
    }
    
    /// Get all active downloads
    public func activeDownloadTasks() async -> [(task: URLSessionDownloadTask, info: DownloadInfo)] {
        await withCheckedContinuation { continuation in
            backgroundSession.getAllTasks { tasks in
                let downloadTasks = tasks.compactMap { $0 as? URLSessionDownloadTask }
                let results = downloadTasks.compactMap { task -> (URLSessionDownloadTask, DownloadInfo)? in
                    guard let info = self.activeDownloads[task] else { return nil }
                    return (task, info)
                }
                continuation.resume(returning: results)
            }
        }
    }
    
    /// Handle app being launched to process background downloads
    public func handleEventsForBackgroundURLSession(
        identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        completionHandlers[identifier] = completionHandler
    }
    
    // MARK: - Background Task Handling
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {
            // Clean up if needed
            task.setTaskCompleted(success: false)
        }
        
        // Check for pending downloads or maintenance
        Task {
            let activeTasks = await activeDownloadTasks()
            
            if !activeTasks.isEmpty {
                // We have active downloads, schedule another refresh
                scheduleBackgroundRefresh()
            }
            
            task.setTaskCompleted(success: true)
        }
    }
    
    private func handleBackgroundProcessing(task: BGProcessingTask) {
        task.expirationHandler = {
            // Pause any active processing
            task.setTaskCompleted(success: false)
        }
        
        // Use this for longer running tasks like model optimization
        Task {
            // Perform any model maintenance or optimization
            await ModelManager().performMaintenance()
            task.setTaskCompleted(success: true)
        }
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.voicetype.modeldownload.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background refresh: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func validateChecksum(at url: URL, expected: String) async throws -> Bool {
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
        let actual = digest.map { String(format: "%02x", $0) }.joined()
        
        return actual == expected
    }
}

// MARK: - URLSessionDownloadDelegate

extension BackgroundDownloadHandler: URLSessionDownloadDelegate {
    
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let downloadInfo = activeDownloads[downloadTask] else { return }
        
        do {
            // Validate checksum if provided
            if let expectedChecksum = downloadInfo.checksum {
                Task {
                    let isValid = try await validateChecksum(at: location, expected: expectedChecksum)
                    
                    if !isValid {
                        let error = NSError(
                            domain: "BackgroundDownload",
                            code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "Checksum validation failed"]
                        )
                        downloadSubject.send(.failed(
                            modelName: downloadInfo.modelName,
                            version: downloadInfo.version,
                            error: error
                        ))
                        return
                    }
                    
                    // Move to destination
                    try FileManager.default.moveItem(at: location, to: downloadInfo.destinationURL)
                    
                    downloadSubject.send(.completed(
                        modelName: downloadInfo.modelName,
                        version: downloadInfo.version,
                        url: downloadInfo.destinationURL
                    ))
                }
            } else {
                // No checksum validation, just move
                try FileManager.default.moveItem(at: location, to: downloadInfo.destinationURL)
                
                downloadSubject.send(.completed(
                    modelName: downloadInfo.modelName,
                    version: downloadInfo.version,
                    url: downloadInfo.destinationURL
                ))
            }
            
        } catch {
            downloadSubject.send(.failed(
                modelName: downloadInfo.modelName,
                version: downloadInfo.version,
                error: error
            ))
        }
        
        activeDownloads.removeValue(forKey: downloadTask)
    }
    
    public func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let downloadInfo = activeDownloads[downloadTask] else { return }
        
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        
        downloadSubject.send(.progress(
            modelName: downloadInfo.modelName,
            version: downloadInfo.version,
            progress: progress
        ))
    }
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let downloadTask = task as? URLSessionDownloadTask,
              var downloadInfo = activeDownloads[downloadTask] else { return }
        
        if let error = error {
            let nsError = error as NSError
            
            if nsError.code == NSURLErrorCancelled,
               let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
                // Download was cancelled with resume data
                downloadInfo.resumeData = resumeData
                downloadSubject.send(.paused(
                    modelName: downloadInfo.modelName,
                    version: downloadInfo.version,
                    resumeData: resumeData
                ))
            } else {
                // Actual error
                downloadSubject.send(.failed(
                    modelName: downloadInfo.modelName,
                    version: downloadInfo.version,
                    error: error
                ))
            }
        }
        
        activeDownloads.removeValue(forKey: downloadTask)
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // Call the completion handler to update UI
        if let identifier = session.configuration.identifier,
           let completionHandler = completionHandlers.removeValue(forKey: identifier) {
            DispatchQueue.main.async {
                completionHandler()
            }
        }
    }
}

// Required import for SHA256
import CryptoKit