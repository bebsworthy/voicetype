import Foundation

/// Protocol defining the interface for inserting text into target applications.
/// Implementations handle different injection methods (accessibility API, clipboard, etc.)
public protocol TextInjector {
    /// Checks if this injector can insert text into the specified target application.
    /// - Parameter target: The application to check compatibility with
    /// - Returns: true if injection is supported for this application
    func canInject(into target: TargetApplication) -> Bool
    
    /// Injects the transcribed text into the target application at the cursor position.
    /// - Parameters:
    ///   - text: The text to insert
    ///   - target: The target application to insert into
    /// - Throws: InjectionError if insertion fails or is not supported
    func inject(_ text: String, into target: TargetApplication) async throws
    
    /// Gets the currently focused application that would receive text input.
    /// - Returns: The target application if one is focused, nil otherwise
    func getFocusedTarget() async -> TargetApplication?
}