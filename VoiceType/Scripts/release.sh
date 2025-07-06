#!/bin/bash
set -euo pipefail

# VoiceType Release Script
# Creates a release-ready DMG with notarization

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERSION="${1:-1.0.0}"
BUILD_NUMBER="${2:-1}"
PROJECT_NAME="VoiceType"
APP_PATH="build/$PROJECT_NAME.app"
DMG_NAME="$PROJECT_NAME-$VERSION.dmg"
VOLUME_NAME="$PROJECT_NAME $VERSION"
DMG_PATH="build/$DMG_NAME"
TEMP_DMG="build/temp.dmg"

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
    log_info "Checking release requirements..."
    
    # Check if app exists
    if [[ ! -d "$APP_PATH" ]]; then
        log_error "App not found at $APP_PATH"
        log_error "Please run ./Scripts/build.sh release first"
        exit 1
    fi
    
    # Check if app is signed
    if ! codesign -dvv "$APP_PATH" 2>&1 | grep -q "Developer ID"; then
        log_error "App is not signed with Developer ID"
        log_error "Please run ./Scripts/sign.sh first"
        exit 1
    fi
    
    # Check for create-dmg (optional but recommended)
    if ! command -v create-dmg &> /dev/null; then
        log_warn "create-dmg not found, will use basic DMG creation"
        log_warn "Install with: brew install create-dmg"
    fi
    
    log_info "All requirements satisfied"
}

update_version() {
    log_info "Updating version to $VERSION (build $BUILD_NUMBER)..."
    
    # Update Info.plist
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_PATH/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_PATH/Contents/Info.plist"
    
    # Re-sign after modification
    if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
        log_info "Re-signing app after version update..."
        ./Scripts/sign.sh "$APP_PATH"
    fi
}

create_dmg_fancy() {
    log_info "Creating DMG with installer UI..."
    
    # Create DMG with create-dmg tool
    create-dmg \
        --volname "$VOLUME_NAME" \
        --volicon "Resources/AppIcon.icns" \
        --background "Resources/dmg-background.png" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$PROJECT_NAME.app" 150 200 \
        --hide-extension "$PROJECT_NAME.app" \
        --app-drop-link 450 200 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_PATH"
}

create_dmg_basic() {
    log_info "Creating basic DMG..."
    
    # Create a temporary directory
    local TEMP_DIR="build/dmg-temp"
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    # Copy app to temporary directory
    cp -R "$APP_PATH" "$TEMP_DIR/"
    
    # Create a symbolic link to Applications
    ln -s /Applications "$TEMP_DIR/Applications"
    
    # Create DMG
    hdiutil create -volname "$VOLUME_NAME" \
        -srcfolder "$TEMP_DIR" \
        -ov -format UDZO \
        "$DMG_PATH"
    
    # Clean up
    rm -rf "$TEMP_DIR"
}

sign_dmg() {
    log_info "Signing DMG..."
    
    if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
        codesign --force --verify --verbose \
            --sign "$DEVELOPER_ID_APPLICATION" \
            "$DMG_PATH"
        
        log_info "DMG signed successfully"
    else
        log_warn "DEVELOPER_ID_APPLICATION not set, DMG will not be signed"
    fi
}

notarize_dmg() {
    log_info "Notarizing DMG..."
    
    # Check for Apple ID credentials
    if [[ -z "${APPLE_ID:-}" ]] || [[ -z "${APPLE_ID_PASSWORD:-}" ]] || [[ -z "${DEVELOPMENT_TEAM:-}" ]]; then
        log_warn "Apple ID credentials not set, skipping DMG notarization"
        return
    fi
    
    # Submit for notarization
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$APPLE_ID" \
        --password "$APPLE_ID_PASSWORD" \
        --team-id "$DEVELOPMENT_TEAM" \
        --wait \
        --verbose
    
    # Staple the ticket
    xcrun stapler staple "$DMG_PATH"
    
    log_info "DMG notarized successfully"
}

generate_update_manifest() {
    log_info "Generating update manifest..."
    
    # Calculate file size and checksum
    local FILE_SIZE=$(stat -f%z "$DMG_PATH")
    local SHA256=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
    local RELEASE_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Create appcast.xml for Sparkle updates
    cat > "build/appcast.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>$PROJECT_NAME Updates</title>
        <link>https://voicetype.app/appcast.xml</link>
        <description>Most recent changes with links to updates.</description>
        <language>en</language>
        <item>
            <title>Version $VERSION</title>
            <description><![CDATA[
                <h2>What's New in Version $VERSION</h2>
                <ul>
                    <li>Initial release of VoiceType</li>
                    <li>Voice transcription with Whisper models</li>
                    <li>System-wide text injection</li>
                    <li>Customizable hotkeys</li>
                </ul>
            ]]></description>
            <pubDate>$RELEASE_DATE</pubDate>
            <enclosure 
                url="https://voicetype.app/releases/$DMG_NAME" 
                sparkle:version="$BUILD_NUMBER"
                sparkle:shortVersionString="$VERSION"
                length="$FILE_SIZE"
                type="application/octet-stream"
                sparkle:edSignature="$SHA256" />
        </item>
    </channel>
</rss>
EOF
    
    # Create release notes
    cat > "build/RELEASE_NOTES.md" << EOF
# VoiceType v$VERSION

Released: $RELEASE_DATE

## Download
- [Download $DMG_NAME]($DMG_NAME) ($((FILE_SIZE / 1024 / 1024)) MB)
- SHA-256: \`$SHA256\`

## What's New
- Initial release of VoiceType
- Voice transcription with Whisper models
- System-wide text injection
- Customizable hotkeys

## System Requirements
- macOS 12.0 or later
- Apple Silicon or Intel processor

## Installation
1. Download the DMG file
2. Open the DMG and drag VoiceType to Applications
3. Launch VoiceType from Applications
4. Grant necessary permissions when prompted

## Known Issues
- First launch may require right-click → Open due to Gatekeeper

## Support
- GitHub: https://github.com/voicetype/voicetype
- Email: support@voicetype.app
EOF
    
    log_info "Update manifest generated"
    log_info "  - Appcast: build/appcast.xml"
    log_info "  - Release notes: build/RELEASE_NOTES.md"
}

create_release_archive() {
    log_info "Creating release archive..."
    
    # Create release directory
    local RELEASE_DIR="build/release-$VERSION"
    mkdir -p "$RELEASE_DIR"
    
    # Copy artifacts
    cp "$DMG_PATH" "$RELEASE_DIR/"
    cp "build/appcast.xml" "$RELEASE_DIR/"
    cp "build/RELEASE_NOTES.md" "$RELEASE_DIR/"
    
    # Create checksums file
    cat > "$RELEASE_DIR/checksums.txt" << EOF
SHA-256 checksums for VoiceType $VERSION:

$(shasum -a 256 "$RELEASE_DIR/$DMG_NAME" | awk '{print $1 "  " $2}' | sed "s|$RELEASE_DIR/||")
EOF
    
    # Create ZIP archive
    cd build
    zip -r "release-$VERSION.zip" "release-$VERSION"
    cd ..
    
    log_info "Release archive created: build/release-$VERSION.zip"
}

# Main execution
main() {
    log_info "Starting VoiceType release process..."
    log_info "Version: $VERSION"
    log_info "Build: $BUILD_NUMBER"
    echo ""
    
    check_requirements
    update_version
    
    # Remove any existing DMG
    rm -f "$DMG_PATH"
    
    # Create DMG using appropriate method
    if command -v create-dmg &> /dev/null; then
        create_dmg_fancy
    else
        create_dmg_basic
    fi
    
    sign_dmg
    notarize_dmg
    generate_update_manifest
    create_release_archive
    
    echo ""
    log_info "Release completed successfully!"
    log_info "Artifacts:"
    log_info "  - DMG: $DMG_PATH"
    log_info "  - Archive: build/release-$VERSION.zip"
    echo ""
    log_info "Next steps:"
    log_info "  1. Upload DMG to release server"
    log_info "  2. Update appcast.xml on server"
    log_info "  3. Create GitHub release with release notes"
    log_info "  4. Announce release"
}

# Run main function
main