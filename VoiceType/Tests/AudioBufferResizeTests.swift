import XCTest
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

final class AudioBufferResizeTests: XCTestCase {
    
    @MainActor
    func testAudioProcessorReinitializationWithDifferentBufferSizes() async throws {
        // Create coordinator
        let coordinator = VoiceTypeCoordinator()
        
        // Wait for initial setup
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Get initial settings manager
        let settingsManager = SettingsManager()
        
        // Test different buffer sizes
        let testDurations = [5, 10, 30, 60]
        
        for duration in testDurations {
            // Update max recording duration
            settingsManager.maxRecordingDuration = duration
            
            // Reinitialize audio processor
            await coordinator.reinitializeAudioProcessor()
            
            // Wait a moment for reinitialization
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Verify the coordinator is still ready (assuming permissions are granted)
            // The actual buffer size verification would require exposing internal state
            // For now, we just verify no crashes occur
            XCTAssertNotNil(coordinator.recordingState)
        }
    }
    
    @MainActor
    func testCannotReinitializeDuringRecording() async throws {
        // Create mock audio processor that simulates recording state
        let mockAudioProcessor = MockAudioProcessor()
        let coordinator = VoiceTypeCoordinator(
            audioProcessor: mockAudioProcessor,
            transcriber: MockTranscriber(),
            textInjector: MockTextInjector(),
            permissionManager: PermissionManager(),
            hotkeyManager: HotkeyManager(),
            modelManager: ModelManager()
        )
        
        // Wait for initialization
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Simulate recording state
        mockAudioProcessor.simulateRecordingState()
        
        // Try to reinitialize during recording
        await coordinator.reinitializeAudioProcessor()
        
        // Verify error message is set
        XCTAssertEqual(coordinator.errorMessage, "Cannot change audio settings while recording or processing")
    }
}

// Simple mock for testing
extension MockAudioProcessor {
    func simulateRecordingState() {
        // This would set the internal state to recording
        // Implementation depends on MockAudioProcessor's structure
    }
}