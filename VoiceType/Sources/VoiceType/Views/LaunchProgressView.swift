//
//  LaunchProgressView.swift
//  VoiceType
//
//  Shows initialization progress during app launch
//

import SwiftUI

/// View shown during app initialization
struct LaunchProgressView: View {
    @ObservedObject var lifecycleManager: AppLifecycleManager

    var body: some View {
        VStack(spacing: 24) {
            // App icon
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .shadow(radius: 10)

            // App name
            Text("VoiceType")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Progress section
            VStack(spacing: 16) {
                // Status text
                Text(lifecycleManager.initializationState.rawValue)
                    .font(.headline)
                    .foregroundColor(.secondary)

                // Progress bar
                ProgressView(value: lifecycleManager.initializationProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 300)

                // Additional status details
                if lifecycleManager.initializationState == .validatingModels {
                    Text("Checking AI models...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if lifecycleManager.initializationState == .migratingSettings {
                    Text("Updating settings...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Loading indicator
            if lifecycleManager.initializationProgress < 1.0 {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.top)
            }
        }
        .padding(40)
        .frame(width: 400, height: 350)
        .background(VisualEffectBackground())
    }
}

/// Provides a blurred background effect
struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .hudWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Preview

#if DEBUG
struct LaunchProgressView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchProgressView(lifecycleManager: {
            let manager = AppLifecycleManager()
            manager.initializationState = .validatingModels
            manager.initializationProgress = 0.6
            return manager
        }())
    }
}
#endif
