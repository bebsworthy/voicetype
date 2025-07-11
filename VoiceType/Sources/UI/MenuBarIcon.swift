import SwiftUI
import AppKit
import VoiceTypeCore
import VoiceTypeImplementations

/// Dynamic menu bar icon that changes based on recording state
public struct MenuBarIcon: View {
    let recordingState: RecordingState
    let isReady: Bool

    public init(recordingState: RecordingState, isReady: Bool) {
        self.recordingState = recordingState
        self.isReady = isReady
    }

    public var body: some View {
        Image(systemName: iconName)
            .foregroundColor(iconColor)
            .symbolRenderingMode(.hierarchical)
    }

    private var iconName: String {
        switch recordingState {
        case .idle:
            return isReady ? "mic" : "mic.slash"
        case .recording:
            return "mic.fill"
        case .processing:
            return "mic.badge.questionmark"
        case .success:
            return "mic.badge.checkmark"
        case .error:
            return "mic.badge.xmark"
        }
    }

    private var iconColor: Color {
        switch recordingState {
        case .idle:
            return isReady ? .primary : .orange
        case .recording:
            return .green  // Changed from red to green
        case .processing:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

/// NSImage extension for creating menu bar images from SF Symbols
public extension NSImage {
    /// Create a menu bar icon image from the current recording state
    static func menuBarIcon(for state: RecordingState, isReady: Bool) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)

        let symbolName: String
        switch state {
        case .idle:
            symbolName = isReady ? "mic" : "mic.slash"
        case .recording:
            symbolName = "mic.fill"
        case .processing:
            symbolName = "mic.badge.questionmark"
        case .success:
            symbolName = "mic.badge.checkmark"
        case .error:
            symbolName = "mic.badge.xmark"
        }

        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "VoiceType") else {
            // Fallback to default mic icon
            return NSImage(systemSymbolName: "mic", accessibilityDescription: "VoiceType")!
        }

        // Apply configuration
        let configuredImage = image.withSymbolConfiguration(config) ?? image

        // Set as template to respect menu bar appearance
        configuredImage.isTemplate = true

        return configuredImage
    }

    /// Create a colored menu bar icon for special states
    static func coloredMenuBarIcon(for state: RecordingState, isReady: Bool) -> NSImage {
        let baseImage = menuBarIcon(for: state, isReady: isReady)

        // Only apply color for special states
        switch state {
        case .recording:
            return baseImage.tinted(with: .systemGreen)  // Changed from red to green
        case .processing:
            return baseImage.tinted(with: .systemBlue)
        case .success:
            return baseImage.tinted(with: .systemGreen)
        case .error:
            return baseImage.tinted(with: .systemRed)
        default:
            return baseImage
        }
    }

    /// Tint an image with a specific color
    private func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()

        color.set()

        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)

        image.unlockFocus()
        image.isTemplate = false // Disable template mode to show color

        return image
    }
}

// MARK: - Menu Bar Extra Icon View

/// A view that can be used in MenuBarExtra for the icon
public struct MenuBarExtraIcon: View {
    @ObservedObject var coordinator: VoiceTypeCoordinator

    public init(coordinator: VoiceTypeCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.multicolor)
            .foregroundStyle(iconColor)
    }
    
    private var iconName: String {
        switch coordinator.recordingState {
        case .idle:
            return coordinator.isReady ? "mic" : "mic.slash"
        case .recording:
            return "mic.fill"
        case .processing:
            return "mic.badge.questionmark"
        case .success:
            return "mic.badge.checkmark"
        case .error:
            return "mic.badge.xmark"
        }
    }

    private var iconColor: Color {
        switch coordinator.recordingState {
        case .idle:
            return coordinator.isReady ? .primary : .orange
        case .recording:
            return .green
        case .processing:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

// MARK: - Animated Recording Indicator

/// Animated recording indicator for visual feedback
public struct RecordingIndicator: View {
    @State private var isAnimating = false

    public init() {}

    public var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 6, height: 6)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Menu Bar Status Item Helper

/// Helper class for managing the menu bar status item
@MainActor
public class MenuBarStatusItem: ObservableObject {
    private var statusItem: NSStatusItem?
    private var coordinator: VoiceTypeCoordinator

    public init(coordinator: VoiceTypeCoordinator) {
        self.coordinator = coordinator
        setupStatusItem()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateIcon()

        // Set accessibility
        statusItem?.button?.toolTip = "VoiceType - Click to show menu"
        statusItem?.button?.setAccessibilityLabel("VoiceType")
        statusItem?.button?.setAccessibilityRole(.menuButton)
    }

    public func updateIcon() {
        guard let button = statusItem?.button else { return }

        // Update the icon based on state - use colored version
        button.image = NSImage.coloredMenuBarIcon(
            for: coordinator.recordingState,
            isReady: coordinator.isReady
        )

        // Update accessibility description
        button.setAccessibilityValue(coordinator.recordingState.description)
    }

    public func setMenu(_ menu: NSMenu) {
        statusItem?.menu = menu
    }

    public func remove() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }
}
