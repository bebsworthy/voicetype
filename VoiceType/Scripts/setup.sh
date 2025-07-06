#!/bin/bash
set -euo pipefail

# VoiceType Development Environment Setup
# Sets up a new development environment for contributors

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MACOS_MIN_VERSION="12.0"
XCODE_MIN_VERSION="14.0"
SWIFT_MIN_VERSION="5.9"

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

check_macos_version() {
    log_step "Checking macOS version..."
    
    local OS_VERSION=$(sw_vers -productVersion)
    local OS_MAJOR=$(echo "$OS_VERSION" | cut -d. -f1)
    local OS_MINOR=$(echo "$OS_VERSION" | cut -d. -f2)
    
    if [[ $OS_MAJOR -lt 12 ]]; then
        log_error "macOS $MACOS_MIN_VERSION or later is required (found $OS_VERSION)"
        return 1
    fi
    
    log_info "macOS $OS_VERSION detected ✓"
    return 0
}

check_xcode() {
    log_step "Checking Xcode installation..."
    
    if ! command -v xcodebuild &> /dev/null; then
        log_error "Xcode is not installed"
        log_info "Please install Xcode from the App Store"
        return 1
    fi
    
    local XCODE_VERSION=$(xcodebuild -version | grep "Xcode" | cut -d' ' -f2)
    log_info "Xcode $XCODE_VERSION detected"
    
    # Check Xcode command line tools
    if ! command -v xcrun &> /dev/null; then
        log_warn "Xcode Command Line Tools not installed"
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        log_info "Please complete the installation and run this script again"
        return 1
    fi
    
    # Accept Xcode license if needed
    if ! xcrun --show-sdk-path &> /dev/null; then
        log_warn "Xcode license needs to be accepted"
        sudo xcodebuild -license accept
    fi
    
    log_info "Xcode setup complete ✓"
    return 0
}

check_swift() {
    log_step "Checking Swift version..."
    
    if ! command -v swift &> /dev/null; then
        log_error "Swift is not installed"
        return 1
    fi
    
    local SWIFT_VERSION=$(swift --version | grep -o 'Swift version [0-9.]*' | cut -d' ' -f3)
    
    if ! printf '%s\n' "$SWIFT_MIN_VERSION" "$SWIFT_VERSION" | sort -V | head -n1 | grep -q "$SWIFT_MIN_VERSION"; then
        log_error "Swift $SWIFT_MIN_VERSION or higher is required (found $SWIFT_VERSION)"
        return 1
    fi
    
    log_info "Swift $SWIFT_VERSION detected ✓"
    return 0
}

install_homebrew() {
    log_step "Checking Homebrew..."
    
    if ! command -v brew &> /dev/null; then
        log_warn "Homebrew not found"
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon
        if [[ -f "/opt/homebrew/bin/brew" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
    fi
    
    log_info "Homebrew installed ✓"
    
    # Update Homebrew
    log_info "Updating Homebrew..."
    brew update
}

install_dependencies() {
    log_step "Installing development dependencies..."
    
    # Install SwiftLint for code linting
    if ! command -v swiftlint &> /dev/null; then
        log_info "Installing SwiftLint..."
        brew install swiftlint
    else
        log_info "SwiftLint already installed ✓"
    fi
    
    # Install create-dmg for release packaging
    if ! command -v create-dmg &> /dev/null; then
        log_info "Installing create-dmg..."
        brew install create-dmg
    else
        log_info "create-dmg already installed ✓"
    fi
    
    # Install xcbeautify for better Xcode output
    if ! command -v xcbeautify &> /dev/null; then
        log_info "Installing xcbeautify..."
        brew install xcbeautify
    else
        log_info "xcbeautify already installed ✓"
    fi
}

setup_git_hooks() {
    log_step "Setting up Git hooks..."
    
    # Create hooks directory if needed
    mkdir -p .git/hooks
    
    # Create pre-commit hook
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# VoiceType pre-commit hook

# Run SwiftLint
if command -v swiftlint &> /dev/null; then
    echo "Running SwiftLint..."
    swiftlint lint --quiet
    if [ $? -ne 0 ]; then
        echo "SwiftLint found issues. Please fix them before committing."
        exit 1
    fi
fi

# Run tests
echo "Running tests..."
./Scripts/test.sh unit
if [ $? -ne 0 ]; then
    echo "Tests failed. Please fix them before committing."
    exit 1
fi

echo "Pre-commit checks passed!"
EOF
    
    chmod +x .git/hooks/pre-commit
    log_info "Git hooks installed ✓"
}

create_local_config() {
    log_step "Creating local configuration..."
    
    # Create .env.local for local settings
    if [[ ! -f .env.local ]]; then
        cat > .env.local << EOF
# Local development configuration
# This file is ignored by git

# Code signing (optional for debug builds)
# DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
# DEVELOPMENT_TEAM="TEAMID"

# Notarization (optional)
# APPLE_ID="your@email.com"
# APPLE_ID_PASSWORD="xxxx-xxxx-xxxx-xxxx"

# Build settings
BUILD_CONFIGURATION="debug"
BUILD_ARCH="$(uname -m)"
EOF
        log_info "Created .env.local configuration file"
    else
        log_info ".env.local already exists ✓"
    fi
    
    # Add to .gitignore if not already there
    if ! grep -q ".env.local" .gitignore 2>/dev/null; then
        echo ".env.local" >> .gitignore
    fi
}

build_project() {
    log_step "Building project..."
    
    log_info "Running initial build to verify setup..."
    if ./Scripts/build.sh debug; then
        log_info "Build successful ✓"
    else
        log_error "Build failed"
        log_info "Please check the error messages above"
        return 1
    fi
}

setup_vscode() {
    log_step "Setting up VS Code (optional)..."
    
    if command -v code &> /dev/null; then
        log_info "VS Code detected, creating workspace settings..."
        
        mkdir -p .vscode
        
        # Create settings.json
        cat > .vscode/settings.json << EOF
{
    "swift.path": "/usr/bin/swift",
    "swift.buildArguments": [
        "-c", "debug"
    ],
    "swift.testArguments": [
        "--parallel"
    ],
    "editor.formatOnSave": true,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "files.exclude": {
        "**/.build": true,
        "**/.swiftpm": true,
        "**/build": true
    }
}
EOF
        
        # Create launch.json
        cat > .vscode/launch.json << EOF
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "swift",
            "request": "launch",
            "name": "Debug VoiceType",
            "program": "\${workspaceFolder}/.build/debug/VoiceType",
            "args": [],
            "cwd": "\${workspaceFolder}",
            "preLaunchTask": "swift: Build Debug VoiceType"
        }
    ]
}
EOF
        
        log_info "VS Code workspace configured ✓"
    else
        log_info "VS Code not found, skipping workspace setup"
    fi
}

print_next_steps() {
    echo ""
    echo "========================================="
    echo ""
    log_info "Setup completed successfully! 🎉"
    echo ""
    echo "Next steps:"
    echo "  1. Review the project documentation:"
    echo "     - README.md - Project overview"
    echo "     - Documentation/ - Technical documentation"
    echo ""
    echo "  2. Build and run the project:"
    echo "     ./Scripts/build.sh debug"
    echo "     ./build/VoiceType.app/Contents/MacOS/VoiceType"
    echo ""
    echo "  3. Run tests:"
    echo "     ./Scripts/test.sh all"
    echo ""
    echo "  4. For code signing (release builds):"
    echo "     - Edit .env.local with your Developer ID"
    echo "     - Run: source .env.local"
    echo "     - Run: ./Scripts/build.sh release"
    echo ""
    echo "Happy coding! 🚀"
    echo "========================================="
}

# Main execution
main() {
    log_info "VoiceType Development Environment Setup"
    log_info "======================================"
    echo ""
    
    # Check system requirements
    check_macos_version || exit 1
    check_xcode || exit 1
    check_swift || exit 1
    
    echo ""
    
    # Install tools
    install_homebrew
    install_dependencies
    
    echo ""
    
    # Setup development environment
    setup_git_hooks
    create_local_config
    
    echo ""
    
    # Optional IDE setup
    setup_vscode
    
    echo ""
    
    # Verify setup with build
    build_project || exit 1
    
    # Show next steps
    print_next_steps
}

# Run main function
main