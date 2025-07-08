import Foundation
import VoiceTypeCore

/// Mock text injector for testing purposes
public class MockTextInjector: TextInjector {
    public var methodName: String { "Mock" }

    // Configuration
    public var shouldSucceed = true
    public var failureError: TextInjectionError = .injectionFailed(reason: "Mock failure")
    public var injectionDelay: TimeInterval = 0.1
    public var isCompatible = true

    // Tracking
    public private(set) var injectionHistory: [InjectionRecord] = []
    public var compatibilityCheckCount = 0

    public init() {}

    public func inject(text: String, completion: @escaping (Result<Void, TextInjectionError>) -> Void) {
        let record = InjectionRecord(
            text: text,
            timestamp: Date(),
            willSucceed: shouldSucceed
        )
        injectionHistory.append(record)

        // Simulate async operation
        DispatchQueue.global().asyncAfter(deadline: .now() + injectionDelay) { [weak self] in
            guard let self = self else {
                completion(.failure(.injectionFailed(reason: "Mock injector deallocated")))
                return
            }

            if self.shouldSucceed {
                completion(.success(()))
            } else {
                completion(.failure(self.failureError))
            }
        }
    }

    public func isCompatibleWithCurrentContext() -> Bool {
        compatibilityCheckCount += 1
        return isCompatible
    }

    // Test helpers
    public func reset() {
        injectionHistory.removeAll()
        compatibilityCheckCount = 0
        shouldSucceed = true
        isCompatible = true
        injectionDelay = 0.1
        failureError = .injectionFailed(reason: "Mock failure")
    }

    public func getLastInjectedText() -> String? {
        injectionHistory.last?.text
    }

    public func getTotalInjectionsCount() -> Int {
        injectionHistory.count
    }

    public func simulateRandomFailures(failureRate: Double = 0.3) {
        shouldSucceed = Double.random(in: 0...1) > failureRate
    }
}

// Recording structure for testing
public struct InjectionRecord {
    public let text: String
    public let timestamp: Date
    public let willSucceed: Bool
}

/// Advanced mock injector with configurable behaviors
public class ConfigurableMockInjector: MockTextInjector {
    override public var methodName: String { "ConfigurableMock" }

    // Advanced configuration
    public var failurePattern: FailurePattern = .never
    public var compatibilityPattern: CompatibilityPattern = .always

    private var injectionCount = 0

    public enum FailurePattern {
        case never
        case always
        case afterNAttempts(Int)
        case everyNthAttempt(Int)
        case random(probability: Double)
        case custom((Int, String) -> Bool) // (attemptNumber, text) -> shouldFail
    }

    public enum CompatibilityPattern {
        case always
        case never
        case alternating
        case afterNChecks(Int)
        case custom(() -> Bool)
    }

    override public func inject(text: String, completion: @escaping (Result<Void, TextInjectionError>) -> Void) {
        injectionCount += 1

        // Determine if this injection should fail based on pattern
        shouldSucceed = !shouldFail(attemptNumber: injectionCount, text: text)

        super.inject(text: text, completion: completion)
    }

    override public func isCompatibleWithCurrentContext() -> Bool {
        compatibilityCheckCount += 1

        switch compatibilityPattern {
        case .always:
            return true
        case .never:
            return false
        case .alternating:
            return compatibilityCheckCount % 2 == 1
        case .afterNChecks(let n):
            return compatibilityCheckCount > n
        case .custom(let checker):
            return checker()
        }
    }

    private func shouldFail(attemptNumber: Int, text: String) -> Bool {
        switch failurePattern {
        case .never:
            return false
        case .always:
            return true
        case .afterNAttempts(let n):
            return attemptNumber > n
        case .everyNthAttempt(let n):
            return attemptNumber % n == 0
        case .random(let probability):
            return Double.random(in: 0...1) < probability
        case .custom(let checker):
            return checker(attemptNumber, text)
        }
    }

    override public func reset() {
        super.reset()
        injectionCount = 0
        failurePattern = .never
        compatibilityPattern = .always
    }
}
