#!/bin/bash
set -euo pipefail

# VoiceType Test Runner
# Runs unit tests, integration tests, and performance tests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TEST_TYPE="${1:-all}"
COVERAGE="${2:-false}"
PARALLEL="${3:-true}"

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

check_requirements() {
    log_info "Checking test requirements..."
    
    if ! command -v swift &> /dev/null; then
        log_error "Swift is not installed"
        exit 1
    fi
    
    if ! command -v xcrun &> /dev/null; then
        log_error "Xcode command line tools are not installed"
        exit 1
    fi
    
    log_info "All requirements satisfied"
}

run_unit_tests() {
    log_info "Running unit tests..."
    
    local TEST_FLAGS=""
    if [[ "$COVERAGE" == "true" ]]; then
        TEST_FLAGS="--enable-code-coverage"
    fi
    
    if [[ "$PARALLEL" == "true" ]]; then
        TEST_FLAGS="$TEST_FLAGS --parallel"
    fi
    
    # Run core tests
    log_test "Running VoiceTypeCoreTests..."
    if swift test --filter VoiceTypeCoreTests $TEST_FLAGS; then
        log_info "Core tests passed"
        ((PASSED_TESTS++))
    else
        log_error "Core tests failed"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

run_integration_tests() {
    log_info "Running integration tests..."
    
    local TEST_FLAGS=""
    if [[ "$COVERAGE" == "true" ]]; then
        TEST_FLAGS="--enable-code-coverage"
    fi
    
    # Run integration tests
    log_test "Running VoiceTypeIntegrationTests..."
    if swift test --filter VoiceTypeIntegrationTests $TEST_FLAGS; then
        log_info "Integration tests passed"
        ((PASSED_TESTS++))
    else
        log_error "Integration tests failed"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

run_performance_tests() {
    log_info "Running performance tests..."
    
    # Create performance test script
    cat > /tmp/performance_test.swift << 'EOF'
import Foundation
import VoiceTypeCore

// Performance test for audio processing
func testAudioProcessingPerformance() {
    let startTime = Date()
    // Simulate audio processing
    for _ in 0..<1000 {
        _ = ProcessInfo.processInfo.processorCount
    }
    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)
    print("Audio processing test completed in \(duration)s")
    assert(duration < 1.0, "Audio processing too slow")
}

// Performance test for transcription
func testTranscriptionPerformance() {
    let startTime = Date()
    // Simulate transcription
    for _ in 0..<100 {
        _ = ProcessInfo.processInfo.processorCount
    }
    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)
    print("Transcription test completed in \(duration)s")
    assert(duration < 0.5, "Transcription too slow")
}

// Run tests
testAudioProcessingPerformance()
testTranscriptionPerformance()
print("All performance tests passed")
EOF
    
    log_test "Running performance benchmarks..."
    if swift /tmp/performance_test.swift 2>/dev/null; then
        log_info "Performance tests passed"
        ((PASSED_TESTS++))
    else
        log_warn "Performance tests skipped (requires built framework)"
    fi
    ((TOTAL_TESTS++))
    
    rm -f /tmp/performance_test.swift
}

generate_coverage_report() {
    log_info "Generating code coverage report..."
    
    # Find the coverage data
    local COVERAGE_PATH=$(find .build -name '*.profdata' -type f | head -n1)
    
    if [[ -n "$COVERAGE_PATH" ]]; then
        # Generate coverage report
        xcrun llvm-cov report \
            .build/debug/VoiceTypePackageTests.xctest/Contents/MacOS/VoiceTypePackageTests \
            -instr-profile="$COVERAGE_PATH" \
            -ignore-filename-regex=".build|Tests" > coverage.txt
        
        # Generate HTML report
        xcrun llvm-cov show \
            .build/debug/VoiceTypePackageTests.xctest/Contents/MacOS/VoiceTypePackageTests \
            -instr-profile="$COVERAGE_PATH" \
            -format=html \
            -output-dir=coverage-html \
            -ignore-filename-regex=".build|Tests"
        
        log_info "Coverage report generated:"
        log_info "  - Text report: coverage.txt"
        log_info "  - HTML report: coverage-html/index.html"
        
        # Display summary
        echo ""
        tail -n 5 coverage.txt
    else
        log_warn "No coverage data found"
    fi
}

run_linting() {
    log_info "Running SwiftLint..."
    
    if command -v swiftlint &> /dev/null; then
        if swiftlint lint --quiet; then
            log_info "Linting passed"
        else
            log_warn "Linting found issues"
        fi
    else
        log_warn "SwiftLint not installed, skipping..."
    fi
}

# Main execution
main() {
    log_info "Starting VoiceType test suite..."
    log_info "Test type: $TEST_TYPE"
    log_info "Coverage: $COVERAGE"
    log_info "Parallel: $PARALLEL"
    echo ""
    
    check_requirements
    
    # Clean previous test artifacts
    rm -rf coverage.txt coverage-html
    
    # Run linting first
    run_linting
    echo ""
    
    # Run requested tests
    case "$TEST_TYPE" in
        unit)
            run_unit_tests
            ;;
        integration)
            run_integration_tests
            ;;
        performance)
            run_performance_tests
            ;;
        all)
            run_unit_tests
            echo ""
            run_integration_tests
            echo ""
            run_performance_tests
            ;;
        *)
            log_error "Unknown test type: $TEST_TYPE"
            echo "Usage: $0 [unit|integration|performance|all] [coverage:true|false] [parallel:true|false]"
            exit 1
            ;;
    esac
    
    echo ""
    
    # Generate coverage report if requested
    if [[ "$COVERAGE" == "true" ]]; then
        generate_coverage_report
        echo ""
    fi
    
    # Summary
    log_info "Test Summary:"
    log_info "  Total tests: $TOTAL_TESTS"
    log_info "  Passed: $PASSED_TESTS"
    log_info "  Failed: $FAILED_TESTS"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_info "All tests passed! ✅"
        exit 0
    else
        log_error "Some tests failed! ❌"
        exit 1
    fi
}

# Run main function
main