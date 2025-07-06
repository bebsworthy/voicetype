import XCTest
import Combine
@testable import VoiceTypeImplementations

@MainActor
class HotkeyManagerTests: XCTestCase {
    
    var hotkeyManager: HotkeyManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        hotkeyManager = HotkeyManager()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        Task { @MainActor in
            hotkeyManager.unregisterAllHotkeys()
            hotkeyManager = nil
            cancellables = nil
        }
        super.tearDown()
    }
    
    // MARK: - Key Combination Validation Tests
    
    func testValidKeyComboValidation() {
        // Test valid combinations by trying to register them
        let validCombos = [
            "cmd+shift+a",
            "ctrl+opt+space",
            "cmd+f1",
            "shift+cmd+return",
            "cmd+shift+opt+p"
        ]
        
        for (index, combo) in validCombos.enumerated() {
            do {
                try hotkeyManager.registerHotkey(
                    identifier: "test.\(index)",
                    keyCombo: combo,
                    action: {}
                )
                // If registration succeeds, the combo is valid
            } catch {
                XCTFail("'\(combo)' should be valid but got error: \(error)")
            }
        }
    }
    
    func testInvalidKeyComboValidation() {
        // Test invalid combinations by trying to register them
        let invalidCombos = [
            "a",              // No modifier
            "space",          // No modifier
            "cmd+",          // Missing key
            "+shift+a",      // Invalid format
            "cmd++a",        // Double plus
            "invalid+a",     // Invalid modifier
            ""               // Empty string
        ]
        
        for combo in invalidCombos {
            do {
                try hotkeyManager.registerHotkey(
                    identifier: "test.invalid",
                    keyCombo: combo,
                    action: {}
                )
                XCTFail("'\(combo)' should be invalid but was accepted")
            } catch {
                // Expected error for invalid combo
            }
        }
    }
    
    // MARK: - Registration Tests
    
    func testSuccessfulHotkeyRegistration() throws {
        let expectation = XCTestExpectation(description: "Hotkey registered")
        
        hotkeyManager.$registeredHotkeys
            .dropFirst()
            .sink { hotkeys in
                XCTAssertEqual(hotkeys.count, 1)
                XCTAssertNotNil(hotkeys["test.hotkey"])
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        try hotkeyManager.registerHotkey(
            identifier: "test.hotkey",
            keyCombo: "cmd+shift+t",
            action: {}
        )
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testDuplicateIdentifierRegistration() throws {
        // Register first hotkey
        try hotkeyManager.registerHotkey(
            identifier: "test.hotkey",
            keyCombo: "cmd+shift+t",
            action: {}
        )
        
        // Try to register with same identifier but different combo
        XCTAssertNoThrow(
            try hotkeyManager.registerHotkey(
                identifier: "test.hotkey",
                keyCombo: "cmd+shift+r",
                action: {}
            ),
            "Should allow updating hotkey with same identifier"
        )
        
        // Verify it was updated
        XCTAssertEqual(hotkeyManager.registeredHotkeys["test.hotkey"]?.keyCombo, "cmd+shift+r")
    }
    
    func testConflictingKeyComboRegistration() throws {
        // Register first hotkey
        try hotkeyManager.registerHotkey(
            identifier: "test.hotkey1",
            keyCombo: "cmd+shift+t",
            action: {}
        )
        
        // Try to register different identifier with same combo
        XCTAssertThrowsError(
            try hotkeyManager.registerHotkey(
                identifier: "test.hotkey2",
                keyCombo: "cmd+shift+t",
                action: {}
            )
        ) { error in
            guard case HotkeyError.conflictingHotkey = error else {
                XCTFail("Expected conflicting hotkey error")
                return
            }
        }
    }
    
    // MARK: - Update Tests
    
    func testSuccessfulHotkeyUpdate() throws {
        // Register initial hotkey
        try hotkeyManager.registerHotkey(
            identifier: "test.hotkey",
            keyCombo: "cmd+shift+t",
            action: {}
        )
        
        // Update it
        try hotkeyManager.updateHotkey(
            identifier: "test.hotkey",
            newKeyCombo: "cmd+shift+r"
        )
        
        // Verify update
        XCTAssertEqual(hotkeyManager.registeredHotkeys["test.hotkey"]?.keyCombo, "cmd+shift+r")
    }
    
    func testUpdateNonExistentHotkey() {
        XCTAssertThrowsError(
            try hotkeyManager.updateHotkey(
                identifier: "non.existent",
                newKeyCombo: "cmd+shift+x"
            )
        ) { error in
            guard case HotkeyError.hotkeyNotFound = error else {
                XCTFail("Expected hotkey not found error")
                return
            }
        }
    }
    
    // MARK: - Unregistration Tests
    
    func testHotkeyUnregistration() throws {
        // Register hotkey
        try hotkeyManager.registerHotkey(
            identifier: "test.hotkey",
            keyCombo: "cmd+shift+t",
            action: {}
        )
        
        // Verify it exists
        XCTAssertNotNil(hotkeyManager.registeredHotkeys["test.hotkey"])
        
        // Unregister
        hotkeyManager.unregisterHotkey(identifier: "test.hotkey")
        
        // Verify it's gone
        XCTAssertNil(hotkeyManager.registeredHotkeys["test.hotkey"])
    }
    
    func testUnregisterAllHotkeys() throws {
        // Register multiple hotkeys
        try hotkeyManager.registerHotkey(identifier: "test1", keyCombo: "cmd+1", action: {})
        try hotkeyManager.registerHotkey(identifier: "test2", keyCombo: "cmd+2", action: {})
        try hotkeyManager.registerHotkey(identifier: "test3", keyCombo: "cmd+3", action: {})
        
        XCTAssertEqual(hotkeyManager.registeredHotkeys.count, 3)
        
        // Unregister all
        hotkeyManager.unregisterAllHotkeys()
        
        XCTAssertTrue(hotkeyManager.registeredHotkeys.isEmpty)
    }
    
    // MARK: - Preset Tests
    
    func testPresetRegistration() throws {
        let actionCalled = XCTestExpectation(description: "Action called")
        
        try hotkeyManager.registerPreset(.toggleRecording) {
            actionCalled.fulfill()
        }
        
        // Verify registration
        let preset = HotkeyManager.HotkeyPreset.toggleRecording
        XCTAssertNotNil(hotkeyManager.registeredHotkeys[preset.identifier])
        XCTAssertEqual(
            hotkeyManager.registeredHotkeys[preset.identifier]?.keyCombo,
            preset.defaultKeyCombo
        )
    }
    
    // MARK: - Display String Tests
    
    func testHotkeyDisplayString() throws {
        try hotkeyManager.registerHotkey(
            identifier: "test",
            keyCombo: "cmd+shift+a",
            action: {}
        )
        
        let displayString = hotkeyManager.getHotkeyDescription(for: "test")
        XCTAssertNotNil(displayString)
        XCTAssertTrue(displayString!.contains("⌘"))
        XCTAssertTrue(displayString!.contains("⇧"))
        XCTAssertTrue(displayString!.contains("A"))
    }
    
    // MARK: - Edge Case Tests
    
    func testCaseInsensitiveKeyCombos() throws {
        // These should all be treated the same
        let combos = ["CMD+SHIFT+A", "cmd+shift+a", "Cmd+Shift+A"]
        
        try hotkeyManager.registerHotkey(
            identifier: "test1",
            keyCombo: combos[0],
            action: {}
        )
        
        // Others should conflict
        for i in 1..<combos.count {
            XCTAssertThrowsError(
                try hotkeyManager.registerHotkey(
                    identifier: "test\(i+1)",
                    keyCombo: combos[i],
                    action: {}
                ),
                "Should detect conflict regardless of case"
            )
        }
    }
    
    func testAlternateModifierNames() throws {
        // Test alternate names for modifiers
        let alternates = [
            ("cmd+a", "command+a"),
            ("ctrl+b", "control+b"),
            ("opt+c", "option+c"),
            ("alt+d", "option+d")
        ]
        
        for (primary, alternate) in alternates {
            try hotkeyManager.registerHotkey(
                identifier: "test.\(primary)",
                keyCombo: primary,
                action: {}
            )
            
            // Alternate should conflict
            XCTAssertThrowsError(
                try hotkeyManager.registerHotkey(
                    identifier: "test.\(alternate)",
                    keyCombo: alternate,
                    action: {}
                ),
                "'\(primary)' and '\(alternate)' should be treated as the same"
            )
            
            hotkeyManager.unregisterAllHotkeys()
        }
    }
    
    // MARK: - Performance Tests
    
    func testBulkRegistrationPerformance() {
        measure {
            do {
                // Register 100 hotkeys
                for i in 0..<100 {
                    try hotkeyManager.registerHotkey(
                        identifier: "perf.test.\(i)",
                        keyCombo: "cmd+shift+f\(i % 12 + 1)",
                        action: {}
                    )
                }
                
                // Clean up
                hotkeyManager.unregisterAllHotkeys()
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
}