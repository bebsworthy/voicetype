import SwiftUI

/// Permission status section for settings panel
struct PermissionStatusSection: View {
    @ObservedObject var permissionManager: PermissionManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with overall status
            HStack {
                Image(systemName: overallStatusIcon)
                    .font(.title2)
                    .foregroundColor(overallStatusColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Permission Status")
                        .font(.headline)
                    Text(overallStatusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Refresh button
                Button(action: { permissionManager.refreshPermissionStates() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Refresh permission status")
            }
            
            // Permission items
            VStack(spacing: 0) {
                PermissionItemView(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Required to record your voice",
                    state: permissionManager.microphonePermission,
                    onRequest: {
                        Task {
                            await permissionManager.requestMicrophonePermission()
                        }
                    },
                    onOpenSettings: {
                        permissionManager.openMicrophonePreferences()
                    }
                )
                
                Divider()
                    .padding(.vertical, 8)
                
                PermissionItemView(
                    icon: "accessibility",
                    title: "Accessibility Access",
                    description: "Required to insert text into other apps",
                    state: permissionManager.accessibilityPermission,
                    onRequest: {
                        permissionManager.showAccessibilityPermissionGuide()
                    },
                    onOpenSettings: {
                        permissionManager.openAccessibilityPreferences()
                    }
                )
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
            )
            
            // Help text
            if !permissionManager.allPermissionsGranted {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text("VoiceType requires these permissions to function properly. Your privacy is important to us - all audio processing happens locally on your device.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var overallStatusIcon: String {
        if permissionManager.allPermissionsGranted {
            return "checkmark.shield.fill"
        } else if permissionManager.microphonePermission == .denied || 
                  permissionManager.accessibilityPermission == .denied {
            return "exclamationmark.shield.fill"
        } else {
            return "shield.lefthalf.filled"
        }
    }
    
    private var overallStatusColor: Color {
        if permissionManager.allPermissionsGranted {
            return .green
        } else if permissionManager.microphonePermission == .denied || 
                  permissionManager.accessibilityPermission == .denied {
            return .red
        } else {
            return .orange
        }
    }
    
    private var overallStatusText: String {
        if permissionManager.allPermissionsGranted {
            return "All permissions granted"
        } else if permissionManager.microphonePermission == .denied || 
                  permissionManager.accessibilityPermission == .denied {
            return "Some permissions denied - VoiceType won't work properly"
        } else {
            return "Some permissions need to be granted"
        }
    }
}

/// Individual permission item view
struct PermissionItemView: View {
    let icon: String
    let title: String
    let description: String
    let state: PermissionState
    let onRequest: () -> Void
    let onOpenSettings: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status and action
            VStack(alignment: .trailing, spacing: 4) {
                // Status badge
                StatusBadge(state: state)
                
                // Action button
                switch state {
                case .notRequested, .undetermined:
                    Button("Grant", action: onRequest)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .opacity(isHovering ? 1 : 0.9)
                    
                case .denied:
                    Button("Settings", action: onOpenSettings)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .foregroundColor(.red)
                        .opacity(isHovering ? 1 : 0.9)
                    
                case .granted:
                    EmptyView()
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
    
    private var iconBackgroundColor: Color {
        switch state {
        case .granted:
            return Color.green.opacity(0.2)
        case .denied:
            return Color.red.opacity(0.2)
        case .notRequested, .undetermined:
            return Color.orange.opacity(0.2)
        }
    }
    
    private var iconColor: Color {
        switch state {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notRequested, .undetermined:
            return .orange
        }
    }
}

/// Status badge component
struct StatusBadge: View {
    let state: PermissionState
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .foregroundColor(foregroundColor)
        .cornerRadius(4)
    }
    
    private var icon: String {
        switch state {
        case .granted:
            return "checkmark"
        case .denied:
            return "xmark"
        case .notRequested, .undetermined:
            return "questionmark"
        }
    }
    
    private var text: String {
        switch state {
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .notRequested:
            return "Not Requested"
        case .undetermined:
            return "Unknown"
        }
    }
    
    private var backgroundColor: Color {
        switch state {
        case .granted:
            return .green.opacity(0.2)
        case .denied:
            return .red.opacity(0.2)
        case .notRequested, .undetermined:
            return .orange.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch state {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notRequested, .undetermined:
            return .orange
        }
    }
}

// MARK: - Preview

struct PermissionStatusSection_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // All granted
            PermissionStatusSection(permissionManager: {
                let manager = PermissionManager()
                // In preview, we'd set the states manually
                return manager
            }())
            
            // Mixed states
            PermissionStatusSection(permissionManager: PermissionManager())
        }
        .padding()
        .frame(width: 500)
    }
}