//
//  FirstLaunchDetector.swift
//  VoiceType
//
//  Detects and handles first launch scenarios
//

import SwiftUI

/// View modifier that detects first launch and shows onboarding
struct FirstLaunchModifier: ViewModifier {
    @ObservedObject var lifecycleManager: AppLifecycleManager
    @State private var hasShownOnboarding = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                checkFirstLaunch()
            }
    }
    
    private func checkFirstLaunch() {
        if lifecycleManager.isFirstLaunch && !hasShownOnboarding {
            hasShownOnboarding = true
            // The onboarding is handled by the WindowGroup in VoiceTypeApp
        }
    }
}

extension View {
    /// Adds first launch detection to a view
    func detectFirstLaunch(with lifecycleManager: AppLifecycleManager) -> some View {
        modifier(FirstLaunchModifier(lifecycleManager: lifecycleManager))
    }
}

/// Helper to manage first launch state
public struct FirstLaunchHelper {
    private static let hasLaunchedBeforeKey = "hasLaunchedBefore"
    private static let firstLaunchDateKey = "firstLaunchDate"
    private static let launchCountKey = "launchCount"
    
    /// Check if this is the first launch
    public static var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
    }
    
    /// Mark first launch as completed
    public static func completeFirstLaunch() {
        UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
        UserDefaults.standard.set(Date(), forKey: firstLaunchDateKey)
    }
    
    /// Increment launch count
    public static func incrementLaunchCount() {
        let currentCount = UserDefaults.standard.integer(forKey: launchCountKey)
        UserDefaults.standard.set(currentCount + 1, forKey: launchCountKey)
    }
    
    /// Get the date of first launch
    public static var firstLaunchDate: Date? {
        UserDefaults.standard.object(forKey: firstLaunchDateKey) as? Date
    }
    
    /// Get the total number of launches
    public static var launchCount: Int {
        UserDefaults.standard.integer(forKey: launchCountKey)
    }
    
    /// Reset first launch state (for testing)
    public static func resetFirstLaunchState() {
        UserDefaults.standard.removeObject(forKey: hasLaunchedBeforeKey)
        UserDefaults.standard.removeObject(forKey: firstLaunchDateKey)
        UserDefaults.standard.removeObject(forKey: launchCountKey)
    }
}