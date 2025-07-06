# Model Download & File Management Implementation

This directory contains the complete implementation for model downloading and file management in VoiceType.

## Components

### 1. ModelDownloader.swift
An `ObservableObject` class that handles:
- Downloading models from URLs with real-time progress tracking
- SHA256 checksum validation
- Resume support for interrupted downloads
- Bandwidth-aware downloading with speed calculation
- Network monitoring for automatic resume
- Published properties for UI binding

**Key Features:**
- `@Published` progress, speed, and remaining time
- Pause/resume functionality
- Automatic network reconnection handling
- Partial download support with `.partial` files
- Configurable buffer sizes for optimal performance

### 2. FileManager+ModelStorage.swift
Extensions to `FileManager` providing:
- Standardized directory structure for VoiceType
- Model file organization and versioning
- Disk space validation and monitoring
- Cache management and cleanup
- Model discovery and enumeration

**Directory Structure:**
```
~/Library/Application Support/VoiceType/
├── models/
│   ├── whisper-base/
│   │   ├── 1.0/
│   │   │   ├── whisper-base.mlpackage/
│   │   │   └── metadata.json
│   │   └── 2.0/
│   │       ├── whisper-base.mlpackage/
│   │       └── metadata.json
│   └── other-model/
├── downloads/
│   └── *.partial (temporary download files)
└── cache/
```

### 3. ModelManager.swift
High-level coordinator that:
- Manages the entire model lifecycle
- Coordinates downloads with installation
- Provides CoreML model loading
- Tracks download queue with status updates
- Handles model metadata and versioning

**Key Features:**
- Automatic disk space checking
- Download queue management
- Model installation from zip archives
- CoreML model loading with optimal configuration
- Storage usage tracking

### 4. BackgroundDownloadHandler.swift
Singleton handler for background downloads:
- Continues downloads when app is backgrounded
- Survives app termination and relaunches
- Background task scheduling for maintenance
- Event-based progress reporting via Combine

**Key Features:**
- `URLSession` with background configuration
- Background task registration for iOS/macOS
- Checksum validation in background
- Resume data persistence
- Completion handler management

### 5. ModelManagementExample.swift
Comprehensive examples showing:
- SwiftUI integration with progress UI
- Download management with pause/resume
- Model listing and deletion
- Storage information display
- Background download setup

## Usage Examples

### Basic Model Download
```swift
let downloader = ModelDownloader()

// Subscribe to progress
downloader.$downloadProgress
    .sink { progress in
        print("Progress: \(Int(progress * 100))%")
    }
    .store(in: &cancellables)

// Download model
try await downloader.downloadModel(
    from: URL(string: "https://example.com/model.mlpackage")!,
    to: destinationURL,
    expectedChecksum: "sha256_hash_here"
)
```

### Model Management
```swift
let manager = ModelManager()

// Download and install a model
let config = ModelManager.ModelConfiguration(
    name: "whisper-base",
    version: "1.0",
    downloadURL: modelURL,
    checksum: "sha256_hash",
    estimatedSize: 150_000_000
)

try await manager.downloadModel(config)

// Load the model
let mlModel = try await manager.loadModel(name: "whisper-base", version: "1.0")
```

### Background Downloads
```swift
let handler = BackgroundDownloadHandler.shared

// Subscribe to events
handler.downloadEvents
    .sink { event in
        switch event {
        case .progress(let name, let version, let progress):
            print("\(name) v\(version): \(Int(progress * 100))%")
        case .completed(let name, let version, let url):
            print("Download completed: \(url)")
        default:
            break
        }
    }
    .store(in: &cancellables)

// Start background download
handler.startBackgroundDownload(
    from: modelURL,
    modelName: "large-model",
    version: "2.0",
    destinationURL: destination,
    checksum: "sha256_hash"
)
```

## Error Handling

The implementation includes comprehensive error handling for:
- Network failures (with automatic retry via resume)
- Insufficient disk space
- Corrupted downloads (checksum mismatch)
- File system errors
- Background task expiration

## Performance Considerations

- Downloads use 64KB buffer sizes for optimal performance
- Speed calculation uses a sliding window algorithm
- Background downloads are configured for large files
- Automatic cleanup prevents disk space issues
- Resume support minimizes bandwidth usage

## Requirements

- macOS 12.0+ / iOS 15.0+
- Swift 5.9+
- CryptoKit framework for SHA256
- Network framework for connectivity monitoring
- BackgroundTasks framework for background processing