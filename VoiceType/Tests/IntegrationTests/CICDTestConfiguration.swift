import XCTest
@testable import VoiceTypeCore

/// Configuration for running integration tests in CI/CD pipelines
public struct CICDTestConfiguration {
    // MARK: - Test Environment

    public enum Environment {
        case local
        case ci
        case staging
        case production

        var timeoutMultiplier: Double {
            switch self {
            case .local: return 1.0
            case .ci: return 2.0 // CI runners may be slower
            case .staging: return 1.5
            case .production: return 1.0
            }
        }

        var shouldRunPerformanceTests: Bool {
            switch self {
            case .local, .staging: return true
            case .ci, .production: return false // Too variable in CI
            }
        }

        var maxParallelTests: Int {
            switch self {
            case .local: return ProcessInfo.processInfo.processorCount
            case .ci: return 2 // Limited resources
            case .staging: return 4
            case .production: return 1
            }
        }
    }

    // MARK: - Test Categories

    public enum TestCategory: String, CaseIterable {
        case smoke = "smoke"
        case functional = "functional"
        case integration = "integration"
        case performance = "performance"
        case stress = "stress"
        case compatibility = "compatibility"

        var isRequiredForRelease: Bool {
            switch self {
            case .smoke, .functional, .integration: return true
            case .performance, .stress, .compatibility: return false
            }
        }

        var maxDuration: TimeInterval {
            switch self {
            case .smoke: return 60 // 1 minute
            case .functional: return 300 // 5 minutes
            case .integration: return 600 // 10 minutes
            case .performance: return 900 // 15 minutes
            case .stress: return 1800 // 30 minutes
            case .compatibility: return 300 // 5 minutes
            }
        }
    }

    // MARK: - Test Plan

    public struct TestPlan {
        let environment: Environment
        let categories: Set<TestCategory>
        let parallel: Bool
        let retryFailedTests: Bool
        let generateReport: Bool

        public static let smokeTest = TestPlan(
            environment: .ci,
            categories: [.smoke],
            parallel: false,
            retryFailedTests: false,
            generateReport: false
        )

        public static let pullRequest = TestPlan(
            environment: .ci,
            categories: [.smoke, .functional],
            parallel: true,
            retryFailedTests: true,
            generateReport: true
        )

        public static let preRelease = TestPlan(
            environment: .staging,
            categories: Set(TestCategory.allCases),
            parallel: true,
            retryFailedTests: true,
            generateReport: true
        )

        public static let nightly = TestPlan(
            environment: .ci,
            categories: [.smoke, .functional, .integration, .stress],
            parallel: true,
            retryFailedTests: false,
            generateReport: true
        )
    }

    // MARK: - Test Filters

    public struct TestFilter {
        let includePatterns: [String]
        let excludePatterns: [String]
        let skipFlaky: Bool
        let runOnlyChanged: Bool

        public static let `default` = TestFilter(
            includePatterns: [],
            excludePatterns: ["*LongRunning*", "*Manual*"],
            skipFlaky: true,
            runOnlyChanged: false
        )

        public static let comprehensive = TestFilter(
            includePatterns: [],
            excludePatterns: ["*Manual*"],
            skipFlaky: false,
            runOnlyChanged: false
        )

        public func shouldRun(test: String, isFlaky: Bool = false) -> Bool {
            // Check if flaky and should skip
            if skipFlaky && isFlaky {
                return false
            }

            // Check exclude patterns
            for pattern in excludePatterns {
                if test.contains(pattern.replacingOccurrences(of: "*", with: "")) {
                    return false
                }
            }

            // Check include patterns (if any specified)
            if !includePatterns.isEmpty {
                for pattern in includePatterns {
                    if test.contains(pattern.replacingOccurrences(of: "*", with: "")) {
                        return true
                    }
                }
                return false
            }

            return true
        }
    }

    // MARK: - Test Results

    public struct TestResults {
        let plan: TestPlan
        let startTime: Date
        let endTime: Date
        let totalTests: Int
        let passedTests: Int
        let failedTests: Int
        let skippedTests: Int
        let flakyTests: Int
        let coverage: Double?
        let performanceMetrics: [String: Double]

        var duration: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }

        var successRate: Double {
            guard totalTests > 0 else { return 0 }
            return Double(passedTests) / Double(totalTests) * 100
        }

        var isPassing: Bool {
            failedTests == 0 && successRate >= 95.0
        }

        func generateReport() -> String {
            var report = """
            VoiceType Integration Test Report
            =================================

            Test Plan: \(plan.categories.map(\.rawValue).joined(separator: ", "))
            Environment: \(plan.environment)
            Duration: \(String(format: "%.2f", duration))s

            Results:
            --------
            Total Tests: \(totalTests)
            Passed: \(passedTests) ✅
            Failed: \(failedTests) ❌
            Skipped: \(skippedTests) ⏭️
            Flaky: \(flakyTests) 🔄
            Success Rate: \(String(format: "%.1f", successRate))%

            """

            if let coverage = coverage {
                report += "Code Coverage: \(String(format: "%.1f", coverage))%\n"
            }

            if !performanceMetrics.isEmpty {
                report += "\nPerformance Metrics:\n"
                report += "-------------------\n"
                for (metric, value) in performanceMetrics.sorted(by: { $0.key < $1.key }) {
                    report += "\(metric): \(String(format: "%.3f", value))s\n"
                }
            }

            report += "\nStatus: \(isPassing ? "✅ PASSED" : "❌ FAILED")\n"

            return report
        }
    }

    // MARK: - GitHub Actions Integration

    public struct GitHubActionsOutput {
        static func setOutput(name: String, value: String) {
            print("::set-output name=\(name)::\(value)")
        }

        static func startGroup(name: String) {
            print("::group::\(name)")
        }

        static func endGroup() {
            print("::endgroup::")
        }

        static func error(message: String, file: String? = nil, line: Int? = nil) {
            var output = "::error"
            if let file = file {
                output += " file=\(file)"
            }
            if let line = line {
                output += ",line=\(line)"
            }
            print("\(output)::\(message)")
        }

        static func warning(message: String) {
            print("::warning::\(message)")
        }

        static func exportResults(_ results: TestResults) {
            setOutput(name: "total_tests", value: "\(results.totalTests)")
            setOutput(name: "passed_tests", value: "\(results.passedTests)")
            setOutput(name: "failed_tests", value: "\(results.failedTests)")
            setOutput(name: "success_rate", value: String(format: "%.1f", results.successRate))
            setOutput(name: "test_status", value: results.isPassing ? "passed" : "failed")

            if let coverage = results.coverage {
                setOutput(name: "code_coverage", value: String(format: "%.1f", coverage))
            }
        }
    }
}

// MARK: - Test Annotations

/// Mark tests with categories for CI/CD filtering
@propertyWrapper
public struct TestCategory {
    private let categories: Set<CICDTestConfiguration.TestCategory>

    public init(_ categories: CICDTestConfiguration.TestCategory...) {
        self.categories = Set(categories)
    }

    public var wrappedValue: Bool {
        true // Placeholder
    }
}

/// Mark flaky tests
@propertyWrapper
public struct FlakyTest {
    private let reason: String
    private let maxRetries: Int

    public init(reason: String, maxRetries: Int = 3) {
        self.reason = reason
        self.maxRetries = maxRetries
    }

    public var wrappedValue: Bool {
        true // Placeholder
    }
}

// MARK: - XCTest Extensions for CI/CD

extension XCTestCase {
    /// Run test with retry logic for flaky tests
    func runWithRetry(
        maxAttempts: Int = 3,
        test: () async throws -> Void
    ) async throws {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                try await test()
                return // Success
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    print("⚠️ Test failed (attempt \(attempt)/\(maxAttempts)), retrying...")
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                }
            }
        }

        throw lastError ?? NSError(domain: "TestRetry", code: -1)
    }

    /// Skip test based on environment
    func skipIfCI(reason: String = "Test not suitable for CI environment") throws {
        if ProcessInfo.processInfo.environment["CI"] != nil {
            throw XCTSkip(reason)
        }
    }

    /// Skip test if running on specific OS version
    func skipIfOSVersion(below minVersion: OperatingSystemVersion) throws {
        let currentVersion = ProcessInfo.processInfo.operatingSystemVersion
        if currentVersion.majorVersion < minVersion.majorVersion ||
           (currentVersion.majorVersion == minVersion.majorVersion &&
            currentVersion.minorVersion < minVersion.minorVersion) {
            throw XCTSkip("Requires macOS \(minVersion.majorVersion).\(minVersion.minorVersion) or later")
        }
    }
}
