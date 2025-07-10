import XCTest
import SwiftUI
@testable import VoiceTypeUI
@testable import VoiceTypeImplementations

final class SettingsViewTests: XCTestCase {
    
    func testModelSettingsViewInitializes() {
        let view = ModelSettingsView()
        XCTAssertNotNil(view)
    }
    
    func testTestTranscriptionViewInitializes() {
        let coordinator = VoiceTypeCoordinator()
        let view = TestTranscriptionView()
            .environmentObject(coordinator)
        XCTAssertNotNil(view)
    }
    
    func testSettingsViewInitializes() {
        let coordinator = VoiceTypeCoordinator()
        let view = SettingsView()
            .environmentObject(coordinator)
        XCTAssertNotNil(view)
    }
}