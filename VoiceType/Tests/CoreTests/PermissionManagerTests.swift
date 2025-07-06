import XCTest
@testable import VoiceTypeCore
@testable import VoiceTypeImplementations

/// Tests for the PermissionManager implementation
final class PermissionManagerTests: XCTestCase {
    
    var permissionManager: PermissionManager!
    
    override func setUp() {
        super.setUp()
        // Clear any persisted permission states to ensure clean test environment
        UserDefaults.standard.removeObject(forKey: "VoiceType.MicrophonePermissionState")
        UserDefaults.standard.removeObject(forKey: "VoiceType.AccessibilityPermissionState")
        UserDefaults.standard.removeObject(forKey: "VoiceType.LastPermissionCheckDate")
        UserDefaults.standard.synchronize()
        
        permissionManager = PermissionManager()
    }
    
    override func tearDown() {
        permissionManager = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(permissionManager)
        XCTAssertFalse(permissionManager.allPermissionsGranted)
    }
    
    // MARK: - Permission State Tests
    
    func testPermissionStateValues() {
        // Test the raw values
        XCTAssertEqual(PermissionState.notRequested.rawValue, "notRequested")
        XCTAssertEqual(PermissionState.denied.rawValue, "denied")
        XCTAssertEqual(PermissionState.granted.rawValue, "granted")
        XCTAssertEqual(PermissionState.undetermined.rawValue, "undetermined")
        
        // Test boolean properties
        XCTAssertTrue(PermissionState.granted.isGranted)
        XCTAssertFalse(PermissionState.denied.isGranted)
        
        XCTAssertTrue(PermissionState.notRequested.needsRequest)
        XCTAssertTrue(PermissionState.undetermined.needsRequest)
        XCTAssertFalse(PermissionState.granted.needsRequest)
    }
    
    // MARK: - Permission Type Tests
    
    func testPermissionTypeDisplayNames() {
        XCTAssertEqual(PermissionType.microphone.displayName, "Microphone")
        XCTAssertEqual(PermissionType.accessibility.displayName, "Accessibility")
    }
    
    func testPermissionTypePurpose() {
        XCTAssertEqual(PermissionType.microphone.purpose, "Required to record and transcribe your speech")
        XCTAssertEqual(PermissionType.accessibility.purpose, "Required to insert transcribed text into other applications")
    }
    
    // MARK: - Instruction Generation Tests
    
    func testMicrophonePermissionInstructions() {
        let instructions = permissionManager.generatePermissionInstructions(for: .microphone)
        
        XCTAssertTrue(instructions.contains("microphone"))
        XCTAssertTrue(instructions.contains("System Preferences"))
        XCTAssertTrue(instructions.contains("Privacy & Security"))
        XCTAssertTrue(instructions.contains("VoiceType"))
    }
    
    func testAccessibilityPermissionInstructions() {
        let instructions = permissionManager.generatePermissionInstructions(for: .accessibility)
        
        XCTAssertTrue(instructions.contains("accessibility"))
        XCTAssertTrue(instructions.contains("System Preferences"))
        XCTAssertTrue(instructions.contains("Privacy & Security"))
        XCTAssertTrue(instructions.contains("VoiceType"))
        XCTAssertTrue(instructions.contains("lock icon"))
    }
    
    // MARK: - Permission Summary Tests
    
    func testPermissionSummaryNeedsAttention() {
        // Wait a moment for initial permission checks to complete
        let expectation = XCTestExpectation(description: "Initial check complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let summary = permissionManager.permissionSummary
        
        // Check if permissions need attention based on current state
        let needingAttention = summary.permissionsNeedingAttention
        
        // The test should verify the logic, not assume initial state
        // If microphone is not granted, it should be in needingAttention
        if summary.microphone != .granted {
            XCTAssertTrue(needingAttention.contains(.microphone))
        }
        
        // If accessibility is not granted, it should be in needingAttention  
        if summary.accessibility != .granted {
            XCTAssertTrue(needingAttention.contains(.accessibility))
        }
        
        // Verify the array contains the correct permissions
        XCTAssertEqual(needingAttention.count, 
                      (summary.microphone != .granted ? 1 : 0) + 
                      (summary.accessibility != .granted ? 1 : 0))
    }
    
    func testPermissionSummaryFunctionality() {
        // Wait a moment for initial permission checks to complete
        let expectation = XCTestExpectation(description: "Initial check complete")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let summary = permissionManager.permissionSummary
        
        // Test the logic based on current permission state
        // canFunctionMinimally requires microphone permission
        XCTAssertEqual(summary.canFunctionMinimally, summary.microphone == .granted)
        
        // canFunctionFully requires all permissions
        XCTAssertEqual(summary.canFunctionFully, summary.allGranted)
        
        // If we have microphone but not accessibility, we can function minimally but not fully
        if summary.microphone == .granted && summary.accessibility != .granted {
            XCTAssertTrue(summary.canFunctionMinimally)
            XCTAssertFalse(summary.canFunctionFully)
        }
    }
    
    // MARK: - Refresh Tests
    
    func testRefreshPermissionStates() {
        // This test verifies the method runs without crashing
        permissionManager.refreshPermissionStates()
        
        // The actual permission states depend on system settings
        XCTAssertNotNil(permissionManager.microphonePermission)
        XCTAssertNotNil(permissionManager.accessibilityPermission)
    }
    
    // MARK: - Accessibility Permission Tests
    
    func testHasAccessibilityPermission() {
        // This test verifies the method runs and returns a boolean
        let hasPermission = permissionManager.hasAccessibilityPermission()
        
        // The actual result depends on system settings
        XCTAssertNotNil(hasPermission)
        
        // Verify the state was updated
        XCTAssertNotEqual(permissionManager.accessibilityPermission, .notRequested)
    }
    
    // MARK: - Microphone Permission Tests
    
    func testCheckMicrophonePermission() {
        // This test verifies the method runs without crashing
        permissionManager.checkMicrophonePermission()
        
        // The actual permission state depends on system settings
        XCTAssertNotNil(permissionManager.microphonePermission)
    }
    
    // MARK: - Async Tests
    
    func testRequestMicrophonePermissionAsync() async {
        // This test verifies the async method completes
        // Note: In a real test environment, we'd mock the AVCaptureDevice
        // to avoid actually requesting permissions during tests
        
        // For now, we just verify the method exists and can be called
        // The actual result depends on system settings and user interaction
        let _ = await permissionManager.requestMicrophonePermission()
        
        // Verify the state was updated
        XCTAssertNotEqual(permissionManager.microphonePermission, .notRequested)
    }
}

// MARK: - Mock Permission Manager for Testing

/// Mock implementation of PermissionManager for testing purposes
/// Since we can't override @Published properties, we'll create a separate mock
class MockPermissionManager: ObservableObject {
    
    @Published var microphonePermission: PermissionState = .notRequested
    @Published var accessibilityPermission: PermissionState = .notRequested
    @Published var allPermissionsGranted: Bool = false
    
    // Allow tests to set mock states
    func setMockMicrophonePermission(_ state: PermissionState) {
        microphonePermission = state
        updateAllPermissionsStatus()
    }
    
    func setMockAccessibilityPermission(_ state: PermissionState) {
        accessibilityPermission = state
        updateAllPermissionsStatus()
    }
    
    func checkMicrophonePermission() {
        // Just trigger update
        updateAllPermissionsStatus()
    }
    
    func hasAccessibilityPermission() -> Bool {
        return accessibilityPermission == .granted
    }
    
    func requestMicrophonePermission() async -> Bool {
        updateAllPermissionsStatus()
        return microphonePermission == .granted
    }
    
    func openAccessibilityPreferences() {
        // No-op in tests
    }
    
    func openMicrophonePreferences() {
        // No-op in tests
    }
    
    func showAccessibilityPermissionGuide() {
        // No-op in tests
    }
    
    func showPermissionDeniedAlert(for permission: PermissionType) {
        // No-op in tests
    }
    
    func generatePermissionInstructions(for permission: PermissionType) -> String {
        switch permission {
        case .microphone:
            return "Mock microphone instructions"
        case .accessibility:
            return "Mock accessibility instructions"
        }
    }
    
    func refreshPermissionStates() {
        updateAllPermissionsStatus()
    }
    
    var permissionSummary: PermissionSummary {
        PermissionSummary(
            microphone: microphonePermission,
            accessibility: accessibilityPermission,
            allGranted: allPermissionsGranted
        )
    }
    
    private func updateAllPermissionsStatus() {
        allPermissionsGranted = microphonePermission == .granted && accessibilityPermission == .granted
    }
}

// MARK: - Mock Permission Manager Tests

final class MockPermissionManagerTests: XCTestCase {
    
    var mockManager: MockPermissionManager!
    
    override func setUp() {
        super.setUp()
        mockManager = MockPermissionManager()
    }
    
    override func tearDown() {
        mockManager = nil
        super.tearDown()
    }
    
    func testMockMicrophonePermission() {
        // Initially not requested
        XCTAssertEqual(mockManager.microphonePermission, .notRequested)
        
        // Set to granted
        mockManager.setMockMicrophonePermission(.granted)
        XCTAssertEqual(mockManager.microphonePermission, .granted)
        
        // Set to denied
        mockManager.setMockMicrophonePermission(.denied)
        XCTAssertEqual(mockManager.microphonePermission, .denied)
    }
    
    func testMockAccessibilityPermission() {
        // Initially not requested
        XCTAssertEqual(mockManager.accessibilityPermission, .notRequested)
        
        // Set to granted
        mockManager.setMockAccessibilityPermission(.granted)
        XCTAssertEqual(mockManager.accessibilityPermission, .granted)
        XCTAssertTrue(mockManager.hasAccessibilityPermission())
        
        // Set to denied
        mockManager.setMockAccessibilityPermission(.denied)
        XCTAssertEqual(mockManager.accessibilityPermission, .denied)
        XCTAssertFalse(mockManager.hasAccessibilityPermission())
    }
    
    func testMockAllPermissionsGranted() {
        // Initially false
        XCTAssertFalse(mockManager.allPermissionsGranted)
        
        // Grant microphone only
        mockManager.setMockMicrophonePermission(.granted)
        XCTAssertFalse(mockManager.allPermissionsGranted)
        
        // Grant both
        mockManager.setMockAccessibilityPermission(.granted)
        XCTAssertTrue(mockManager.allPermissionsGranted)
        
        // Deny one
        mockManager.setMockMicrophonePermission(.denied)
        XCTAssertFalse(mockManager.allPermissionsGranted)
    }
    
    func testMockRequestMicrophonePermission() async {
        // Set mock state
        mockManager.setMockMicrophonePermission(.granted)
        
        // Request permission
        let granted = await mockManager.requestMicrophonePermission()
        
        XCTAssertTrue(granted)
        XCTAssertEqual(mockManager.microphonePermission, .granted)
    }
    
    func testMockPermissionSummary() {
        // Initially both permissions are not requested
        var summary = mockManager.permissionSummary
        XCTAssertEqual(summary.microphone, .notRequested)
        XCTAssertEqual(summary.accessibility, .notRequested)
        XCTAssertFalse(summary.allGranted)
        XCTAssertEqual(summary.permissionsNeedingAttention.count, 2)
        
        // Grant microphone permission
        mockManager.setMockMicrophonePermission(.granted)
        summary = mockManager.permissionSummary
        XCTAssertTrue(summary.canFunctionMinimally)
        XCTAssertFalse(summary.canFunctionFully)
        XCTAssertEqual(summary.permissionsNeedingAttention.count, 1)
        XCTAssertTrue(summary.permissionsNeedingAttention.contains(.accessibility))
        
        // Grant accessibility permission
        mockManager.setMockAccessibilityPermission(.granted)
        summary = mockManager.permissionSummary
        XCTAssertTrue(summary.canFunctionMinimally)
        XCTAssertTrue(summary.canFunctionFully)
        XCTAssertTrue(summary.permissionsNeedingAttention.isEmpty)
    }
    
    func testMockPermissionInstructions() {
        let micInstructions = mockManager.generatePermissionInstructions(for: .microphone)
        XCTAssertTrue(micInstructions.contains("microphone"))
        
        let accInstructions = mockManager.generatePermissionInstructions(for: .accessibility)
        XCTAssertTrue(accInstructions.contains("accessibility"))
    }
    
    func testMockRefreshPermissionStates() {
        // Set initial states
        mockManager.setMockMicrophonePermission(.granted)
        mockManager.setMockAccessibilityPermission(.denied)
        
        // Refresh should maintain states
        mockManager.refreshPermissionStates()
        
        XCTAssertEqual(mockManager.microphonePermission, .granted)
        XCTAssertEqual(mockManager.accessibilityPermission, .denied)
        XCTAssertFalse(mockManager.allPermissionsGranted)
    }
}