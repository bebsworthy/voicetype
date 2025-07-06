#!/bin/bash
set -euo pipefail

# VoiceType Build Script
# Handles debug and release builds with proper code signing

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="VoiceType"
BUNDLE_ID="com.voicetype.app"
BUILD_DIR="build"
CONFIGURATION="${1:-debug}"
ARCH="${2:-universal}"

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

check_requirements() {
    log_info "Checking build requirements..."
    
    # Check for Xcode
    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode is not installed"
        exit 1
    fi
    
    # Check for Swift
    if ! command -v swift &> /dev/null; then
        log_error "Swift is not installed"
        exit 1
    fi
    
    # Check Swift version
    SWIFT_VERSION=$(swift --version | grep -o 'Swift version [0-9.]*' | cut -d' ' -f3)
    REQUIRED_VERSION="5.9"
    if ! printf '%s\n' "$REQUIRED_VERSION" "$SWIFT_VERSION" | sort -V | head -n1 | grep -q "$REQUIRED_VERSION"; then
        log_error "Swift $REQUIRED_VERSION or higher is required (found $SWIFT_VERSION)"
        exit 1
    fi
    
    log_info "All requirements satisfied"
}

clean_build() {
    log_info "Cleaning previous build artifacts..."
    rm -rf "$BUILD_DIR"
    swift package clean
}

build_project() {
    local config="$1"
    local arch="$2"
    
    log_info "Building $PROJECT_NAME ($config) for $arch..."
    
    # Set build flags based on configuration
    local BUILD_FLAGS=""
    if [[ "$config" == "release" ]]; then
        BUILD_FLAGS="-c release -Xswiftc -O"
    else
        BUILD_FLAGS="-c debug -Xswiftc -Onone"
    fi
    
    # Set architecture flags
    local ARCH_FLAGS=""
    if [[ "$arch" == "universal" ]]; then
        ARCH_FLAGS="--arch arm64 --arch x86_64"
    elif [[ "$arch" == "arm64" ]]; then
        ARCH_FLAGS="--arch arm64"
    elif [[ "$arch" == "x86_64" ]]; then
        ARCH_FLAGS="--arch x86_64"
    fi
    
    # Create build directory
    mkdir -p "$BUILD_DIR"
    
    # Build the project
    if swift build $BUILD_FLAGS $ARCH_FLAGS; then
        log_info "Build completed successfully"
    else
        log_error "Build failed"
        exit 1
    fi
    
    # Copy executable to build directory
    local BUILD_CONFIG_DIR=".build/$config"
    if [[ -f "$BUILD_CONFIG_DIR/$PROJECT_NAME" ]]; then
        cp "$BUILD_CONFIG_DIR/$PROJECT_NAME" "$BUILD_DIR/"
        log_info "Executable copied to $BUILD_DIR/$PROJECT_NAME"
    else
        log_error "Executable not found at $BUILD_CONFIG_DIR/$PROJECT_NAME"
        exit 1
    fi
}

create_app_bundle() {
    local config="$1"
    
    log_info "Creating app bundle..."
    
    local APP_NAME="$PROJECT_NAME.app"
    local APP_PATH="$BUILD_DIR/$APP_NAME"
    
    # Create app bundle structure
    mkdir -p "$APP_PATH/Contents/MacOS"
    mkdir -p "$APP_PATH/Contents/Resources"
    mkdir -p "$APP_PATH/Contents/Frameworks"
    
    # Copy executable
    cp "$BUILD_DIR/$PROJECT_NAME" "$APP_PATH/Contents/MacOS/$PROJECT_NAME"
    chmod +x "$APP_PATH/Contents/MacOS/$PROJECT_NAME"
    
    # Create Info.plist
    cat > "$APP_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$PROJECT_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>VoiceType needs access to your microphone for voice transcription.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>VoiceType needs accessibility permissions to inject transcribed text.</string>
</dict>
</plist>
EOF
    
    # Copy resources if they exist
    if [[ -d "Resources" ]]; then
        cp -R Resources/* "$APP_PATH/Contents/Resources/"
    fi
    
    log_info "App bundle created at $APP_PATH"
}

sign_app() {
    local config="$1"
    local APP_PATH="$BUILD_DIR/$PROJECT_NAME.app"
    
    # Check if we should sign
    if [[ "$config" == "release" ]] && [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
        log_info "Signing app with Developer ID: $DEVELOPER_ID_APPLICATION"
        
        # Sign the app
        codesign --force --deep --verify --verbose \
            --sign "$DEVELOPER_ID_APPLICATION" \
            --options runtime \
            --entitlements "ApplicationConfigs/Entitlements.plist" \
            "$APP_PATH"
        
        # Verify signature
        codesign --verify --deep --strict --verbose=2 "$APP_PATH"
        log_info "App signed successfully"
    else
        log_warn "Skipping code signing (debug build or no certificate specified)"
    fi
}

# Main execution
main() {
    log_info "Starting VoiceType build process..."
    log_info "Configuration: $CONFIGURATION"
    log_info "Architecture: $ARCH"
    
    check_requirements
    clean_build
    build_project "$CONFIGURATION" "$ARCH"
    create_app_bundle "$CONFIGURATION"
    sign_app "$CONFIGURATION"
    
    log_info "Build completed successfully!"
    log_info "Output: $BUILD_DIR/$PROJECT_NAME.app"
}

# Run main function
main