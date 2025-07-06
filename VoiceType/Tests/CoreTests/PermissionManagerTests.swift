import XCTest
@testable import VoiceType

/// Tests for the PermissionManager implementation
final class PermissionManagerTests: XCTestCase {
    
    var permissionManager: PermissionManager!
    
    override func setUp() {
        super.setUp()
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
    
    func testPermissionStateDescription() {
        XCTAssertEqual(PermissionState.notRequested.description, "Not Requested")
        XCTAssertEqual(PermissionState.denied.description, "Denied")
        XCTAssertEqual(PermissionState.granted.description, "Granted")
    }
    
    func testPermissionStateIcons() {
        XCTAssertEqual(PermissionState.notRequested.iconName, "questionmark.circle")
        XCTAssertEqual(PermissionState.denied.iconName, "xmark.circle")
        XCTAssertEqual(PermissionState.granted.iconName, "checkmark.circle")
    }
    
    func testPermissionStateColors() {
        XCTAssertEqual(PermissionState.notRequested.color, "gray")
        XCTAssertEqual(PermissionState.denied.color, "red")
        XCTAssertEqual(PermissionState.granted.color, "green")
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
        let summary = permissionManager.permissionSummary
        
        // Initially, both permissions should need attention
        let needingAttention = summary.permissionsNeedingAttention
        XCTAssertTrue(needingAttention.contains(.microphone))
        XCTAssertTrue(needingAttention.contains(.accessibility))
    }
    
    func testPermissionSummaryFunctionality() {
        let summary = permissionManager.permissionSummary
        
        // Initially, the app cannot function at all
        XCTAssertFalse(summary.canFunctionMinimally)
        XCTAssertFalse(summary.canFunctionFully)
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
/// This allows testing components that depend on PermissionManager
/// without actually requesting system permissions
class MockPermissionManager: PermissionManager {
    
    private var mockMicrophoneState: PermissionState = .notRequested
    private var mockAccessibilityState: PermissionState = .notRequested
    
    // Allow tests to set mock states
    func setMockMicrophonePermission(_ state: PermissionState) {
        mockMicrophoneState = state
        microphonePermission = state
        updateAllPermissionsStatus()
    }
    
    func setMockAccessibilityPermission(_ state: PermissionState) {
        mockAccessibilityState = state
        accessibilityPermission = state
        updateAllPermissionsStatus()
    }
    
    override func checkMicrophonePermission() {
        microphonePermission = mockMicrophoneState
        updateAllPermissionsStatus()
    }
    
    override func hasAccessibilityPermission() -> Bool {
        accessibilityPermission = mockAccessibilityState
        updateAllPermissionsStatus()
        return mockAccessibilityState == .granted
    }
    
    override func requestMicrophonePermission() async -> Bool {
        microphonePermission = mockMicrophoneState
        updateAllPermissionsStatus()
        return mockMicrophoneState == .granted
    }
    
    override func openAccessibilityPreferences() {
        // No-op in tests
    }
    
    override func openMicrophonePreferences() {
        // No-op in tests
    }
    
    override func showAccessibilityPermissionGuide() {
        // No-op in tests
    }
    
    override func showPermissionDeniedAlert(for permission: PermissionType) {
        // No-op in tests
    }
    
    private func updateAllPermissionsStatus() {
        allPermissionsGranted = mockMicrophoneState == .granted && mockAccessibilityState == .granted
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
}