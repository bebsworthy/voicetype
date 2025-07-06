#!/bin/bash
set -euo pipefail

# VoiceType Clean Script
# Removes all build artifacts and caches

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Main execution
log_info "Cleaning VoiceType build artifacts..."

# Clean Swift Package Manager
log_info "Cleaning Swift Package Manager..."
swift package clean
rm -rf .build
rm -rf .swiftpm

# Clean build directory
log_info "Cleaning build directory..."
rm -rf build

# Clean test artifacts
log_info "Cleaning test artifacts..."
rm -rf coverage.txt
rm -rf coverage-html
rm -rf coverage.lcov
rm -rf performance-*.json
rm -rf performance-*.log

# Clean Xcode derived data (optional)
if [[ "${1:-}" == "--deep" ]]; then
    log_warn "Performing deep clean (including Xcode derived data)..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/VoiceType-*
fi

# Clean OS generated files
log_info "Cleaning OS generated files..."
find . -name ".DS_Store" -delete

log_info "Clean complete!"

if [[ "${1:-}" != "--deep" ]]; then
    log_info "Tip: Use './Scripts/clean.sh --deep' to also clean Xcode derived data"
fi