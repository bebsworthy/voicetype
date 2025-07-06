# VoiceType Performance Tests

This directory contains comprehensive performance and memory tests for the VoiceType application, validating all performance requirements from the specification.

## Test Categories

### 1. Memory Usage Tests (`MemoryUsageTests.swift`)
- **1-hour operation simulation**: Validates memory usage stays under limits during extended use
- **Model memory profiling**: Tests memory usage with different model sizes (Tiny, Base, Small)
- **Memory leak detection**: Identifies potential memory leaks through repeated operations
- **Peak memory validation**: Ensures peak memory stays under 100MB (active) and 200MB (with largest model)

### 2. Latency Measurement Tests (`LatencyMeasurementTests.swift`)
- **End-to-end latency**: Measures total time from recording start to text insertion
- **Component breakdown**: Individual timing for audio, transcription, and injection phases
- **Model inference timing**: Validates each model meets its latency targets
- **Concurrent operations**: Tests latency under load
- **Percentile analysis**: P50, P90, P95, P99 latency measurements

### 3. Model Loading Performance Tests (`ModelLoadingPerformanceTests.swift`)
- **Load time per model**: Validates Tiny (<1s), Base (<2s), Small (<3s) load times
- **Model switching**: Tests performance when switching between models
- **Cold vs warm start**: Compares initial load vs subsequent access
- **Parallel loading**: Tests concurrent model loading efficiency
- **Memory impact**: Monitors memory usage during model loading

### 4. Audio Processing Efficiency Tests (`AudioProcessingEfficiencyTests.swift`)
- **CPU usage monitoring**: Validates <15% average CPU during recording
- **Buffer efficiency**: Tests different buffer sizes for optimal performance
- **Real-time verification**: Ensures audio processing faster than real-time
- **Preprocessing efficiency**: Tests audio normalization, pre-emphasis, noise gate
- **Long recording efficiency**: Memory and CPU usage during extended recordings

### 5. Performance Benchmarking Tests (`PerformanceBenchmarkingTests.swift`)
- **Regression detection**: Automated detection of performance degradation
- **Device-specific baselines**: Different thresholds for Intel vs Apple Silicon
- **Report generation**: Comprehensive performance reports with statistics
- **Historical tracking**: Compares current performance against baselines

## Running Performance Tests

### Run All Performance Tests
```bash
# From Xcode
Product > Test > PerformanceTests

# From command line
xcodebuild test -scheme VoiceType -testPlan PerformanceTestPlan
```

### Run Specific Test Categories
```bash
# Memory tests only
xcodebuild test -scheme VoiceType -only-testing:PerformanceTests/MemoryUsageTests

# Latency tests only
xcodebuild test -scheme VoiceType -only-testing:PerformanceTests/LatencyMeasurementTests
```

### Run with Different Configurations
```bash
# Default performance tests
xcodebuild test -scheme VoiceType -testPlan PerformanceTestPlan -testConfiguration DEFAULT

# Stress tests (10x load)
xcodebuild test -scheme VoiceType -testPlan PerformanceTestPlan -testConfiguration STRESS

# Generate new baselines
xcodebuild test -scheme VoiceType -testPlan PerformanceTestPlan -testConfiguration BASELINE
```

## Performance Requirements Validation

The tests validate all requirements from the specification:

| Requirement | Test Coverage | Target |
|------------|---------------|---------|
| Total Latency | `testEndToEndLatency()`, `testTargetLatencyValidation()` | <5 seconds |
| Memory Usage (Active) | `testLongRunningMemoryUsage()`, `testPeakMemoryValidation()` | <100MB |
| Memory Usage (w/ Large Model) | `testMaxModelMemoryStress()` | <200MB |
| CPU Usage | `testCPUUsageDuringRecording()` | <15% average |
| Model Load Time (Tiny) | `testModelLoadingTimes()` | <1 second |
| Model Load Time (Base) | `testModelLoadingTimes()` | <2 seconds |
| Model Load Time (Small) | `testModelLoadingTimes()` | <3 seconds |

## Interpreting Results

### Performance Reports
Tests generate detailed reports in the Documents directory:
```
~/Documents/benchmark-[timestamp].txt
```

Reports include:
- Summary statistics (avg, min, max, p95)
- Performance validation results
- Recommendations for optimization

### Regression Detection
The `PerformanceBenchmarkingTests` automatically detect regressions:
- 10% threshold for latency increases
- 10% threshold for memory usage increases
- 20% threshold for CPU usage increases

### Device-Specific Results
Tests apply different baselines based on hardware:
- **Apple Silicon**: Lower latency, memory, and CPU targets
- **Intel**: Higher tolerances for older hardware

## Best Practices

1. **Run tests on target hardware**: Performance varies significantly between devices
2. **Multiple iterations**: Run tests multiple times for statistical significance
3. **Clean state**: Restart the app between test runs to ensure clean state
4. **Monitor trends**: Track performance metrics over time, not just single runs
5. **Real device testing**: Simulator results may not reflect real device performance

## CI/CD Integration

### GitHub Actions Example
```yaml
- name: Run Performance Tests
  run: |
    xcodebuild test \
      -scheme VoiceType \
      -testPlan PerformanceTestPlan \
      -resultBundlePath results.xcresult
    
- name: Parse Performance Results
  run: |
    xcrun xcresulttool get --path results.xcresult \
      --format json > performance.json
    
- name: Check for Regressions
  run: |
    # Custom script to parse performance.json
    # and compare against baselines
```

## Troubleshooting

### Tests Failing on CI
- Ensure CI runners have sufficient resources
- Increase timeout values for slower runners
- Use device-specific baselines

### Memory Warnings
- Check for retain cycles in implementation
- Verify autoreleasepool usage in tests
- Monitor for accumulating test data

### Inconsistent Results
- Run tests in isolation
- Check for background processes
- Ensure consistent test data sizes

## Future Enhancements

1. **Network conditions**: Test model download performance
2. **Battery impact**: Monitor energy usage during operations
3. **Thermal throttling**: Test performance under thermal pressure
4. **Storage I/O**: Test model loading from various storage types
5. **Concurrent app impact**: Test with other apps running