// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoiceType",
    platforms: [
        .macOS("15.0")
    ],
    products: [
        .executable(
            name: "VoiceType",
            targets: ["VoiceType"]
        ),
        .library(
            name: "VoiceTypeCore",
            targets: ["VoiceTypeCore"]
        ),
        .library(
            name: "VoiceTypeUI",
            targets: ["VoiceTypeUI"]
        ),
        .library(
            name: "VoiceTypeImplementations",
            targets: ["VoiceTypeImplementations"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit", from: "0.9.0")
    ],
    targets: [
        // Main executable
        .executableTarget(
            name: "VoiceType",
            dependencies: [
                "VoiceTypeCore",
                "VoiceTypeUI",
                "VoiceTypeImplementations"
            ],
            path: "Sources/VoiceType",
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release)),
                .unsafeFlags(["-enable-testing"], .when(configuration: .debug))
            ]
        ),
        
        // Core business logic - no external dependencies
        .target(
            name: "VoiceTypeCore",
            dependencies: [],
            path: "Sources/Core",
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        
        // UI components
        .target(
            name: "VoiceTypeUI",
            dependencies: ["VoiceTypeCore", "VoiceTypeImplementations"],
            path: "Sources/UI",
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        
        // Concrete implementations
        .target(
            name: "VoiceTypeImplementations",
            dependencies: [
                "VoiceTypeCore",
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources/Implementations",
            swiftSettings: [
                .unsafeFlags(["-cross-module-optimization"], .when(configuration: .release))
            ]
        ),
        
        // Test targets
        .testTarget(
            name: "VoiceTypeCoreTests",
            dependencies: ["VoiceTypeCore", "VoiceTypeImplementations"],
            path: "Tests/CoreTests",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "VoiceTypeIntegrationTests",
            dependencies: [
                "VoiceType",
                "VoiceTypeCore",
                "VoiceTypeImplementations"
            ],
            path: "Tests/IntegrationTests",
            resources: [
                .process("Resources")
            ]
        )
    ]
)

// MARK: - Build Settings
#if swift(>=5.10)
extension SwiftSetting {
    static let strictConcurrency: Self = .enableExperimentalFeature("StrictConcurrency")
}
#endif