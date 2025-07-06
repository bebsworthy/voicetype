#!/bin/bash
set -euo pipefail

# VoiceType Code Signing Script
# Handles code signing, notarization, and stapling

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
APP_PATH="${1:-build/VoiceType.app}"
IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
TEAM_ID="${DEVELOPMENT_TEAM:-}"
BUNDLE_ID="com.voicetype.app"
ENTITLEMENTS_PATH="ApplicationConfigs/Entitlements.plist"

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
    log_info "Checking signing requirements..."
    
    # Check if app exists
    if [[ ! -d "$APP_PATH" ]]; then
        log_error "App not found at $APP_PATH"
        exit 1
    fi
    
    # Check if identity is set
    if [[ -z "$IDENTITY" ]]; then
        log_error "DEVELOPER_ID_APPLICATION environment variable not set"
        echo "Please export DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)'"
        exit 1
    fi
    
    # Check if team ID is set
    if [[ -z "$TEAM_ID" ]]; then
        log_error "DEVELOPMENT_TEAM environment variable not set"
        echo "Please export DEVELOPMENT_TEAM='TEAMID'"
        exit 1
    fi
    
    # Check for codesign
    if ! command -v codesign &> /dev/null; then
        log_error "codesign not found"
        exit 1
    fi
    
    # Check for notarytool
    if ! command -v xcrun &> /dev/null; then
        log_error "xcrun not found"
        exit 1
    fi
    
    log_info "All requirements satisfied"
}

create_entitlements() {
    log_info "Creating entitlements file..."
    
    # Create ApplicationConfigs directory if it doesn't exist
    mkdir -p "$(dirname "$ENTITLEMENTS_PATH")"
    
    # Create entitlements file
    cat > "$ENTITLEMENTS_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required for audio recording -->
    <key>com.apple.security.device.audio-input</key>
    <true/>
    
    <!-- Required for accessibility features -->
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    
    <!-- Required for hardened runtime -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
    
    <!-- Network access for model downloads -->
    <key>com.apple.security.network.client</key>
    <true/>
    
    <!-- File access for model storage -->
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <key>com.apple.security.files.downloads.read-write</key>
    <true/>
</dict>
</plist>
EOF
    
    log_info "Entitlements file created at $ENTITLEMENTS_PATH"
}

sign_frameworks() {
    log_info "Signing embedded frameworks..."
    
    local FRAMEWORKS_PATH="$APP_PATH/Contents/Frameworks"
    
    if [[ -d "$FRAMEWORKS_PATH" ]]; then
        # Sign each framework
        find "$FRAMEWORKS_PATH" -name "*.framework" -o -name "*.dylib" | while read -r framework; do
            log_info "Signing $(basename "$framework")..."
            codesign --force --verify --verbose \
                --sign "$IDENTITY" \
                --options runtime \
                --timestamp \
                "$framework"
        done
    else
        log_info "No embedded frameworks found"
    fi
}

sign_app() {
    log_info "Signing application..."
    
    # Remove any existing signatures
    codesign --remove-signature "$APP_PATH" 2>/dev/null || true
    
    # Sign the app with hardened runtime
    codesign --force --deep --verify --verbose \
        --sign "$IDENTITY" \
        --options runtime \
        --entitlements "$ENTITLEMENTS_PATH" \
        --timestamp \
        "$APP_PATH"
    
    # Verify signature
    log_info "Verifying signature..."
    codesign --verify --deep --strict --verbose=2 "$APP_PATH"
    
    # Check signature info
    codesign -dvvv "$APP_PATH"
    
    log_info "App signed successfully"
}

notarize_app() {
    log_info "Preparing for notarization..."
    
    # Check for Apple ID credentials
    if [[ -z "${APPLE_ID:-}" ]]; then
        log_warn "APPLE_ID not set, skipping notarization"
        log_warn "To enable notarization, export APPLE_ID='your@email.com'"
        return
    fi
    
    if [[ -z "${APPLE_ID_PASSWORD:-}" ]]; then
        log_warn "APPLE_ID_PASSWORD not set, skipping notarization"
        log_warn "To enable notarization, create an app-specific password and export APPLE_ID_PASSWORD='xxxx-xxxx-xxxx-xxxx'"
        return
    fi
    
    # Create a ZIP for notarization
    local ZIP_PATH="${APP_PATH%.app}.zip"
    log_info "Creating ZIP archive for notarization..."
    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
    
    # Submit for notarization
    log_info "Submitting app for notarization..."
    xcrun notarytool submit "$ZIP_PATH" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$TEAM_ID" \
        --wait \
        --verbose
    
    # Remove the ZIP
    rm "$ZIP_PATH"
    
    log_info "Notarization completed"
}

staple_app() {
    log_info "Stapling notarization ticket..."
    
    xcrun stapler staple "$APP_PATH"
    
    # Verify stapling
    xcrun stapler validate "$APP_PATH"
    
    log_info "Notarization ticket stapled successfully"
}

verify_gatekeeper() {
    log_info "Verifying Gatekeeper acceptance..."
    
    # Check Gatekeeper
    spctl -a -t exec -vvv "$APP_PATH"
    
    log_info "Gatekeeper verification passed"
}

# Main execution
main() {
    log_info "Starting VoiceType code signing process..."
    log_info "App: $APP_PATH"
    log_info "Identity: $IDENTITY"
    log_info "Team ID: $TEAM_ID"
    echo ""
    
    check_requirements
    create_entitlements
    sign_frameworks
    sign_app
    
    # Only notarize if credentials are available
    if [[ -n "${APPLE_ID:-}" ]] && [[ -n "${APPLE_ID_PASSWORD:-}" ]]; then
        notarize_app
        staple_app
        verify_gatekeeper
    else
        log_warn "Notarization skipped (no Apple ID credentials)"
        log_info "The app is signed but not notarized"
        log_info "Users may need to right-click and select 'Open' on first launch"
    fi
    
    echo ""
    log_info "Code signing completed successfully!"
}

# Run main function
main