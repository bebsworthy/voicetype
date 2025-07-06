#!/bin/bash
set -euo pipefail

# VoiceType Code Formatting Script
# Formats Swift code using SwiftFormat

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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for SwiftFormat
check_swiftformat() {
    if ! command -v swiftformat &> /dev/null; then
        log_error "SwiftFormat not found"
        log_info "Install with: brew install swiftformat"
        exit 1
    fi
}

# Main execution
main() {
    log_info "Formatting VoiceType codebase..."
    
    check_swiftformat
    
    # Create .swiftformat config if it doesn't exist
    if [[ ! -f .swiftformat ]]; then
        log_info "Creating .swiftformat configuration..."
        cat > .swiftformat << 'EOF'
# VoiceType SwiftFormat Configuration

# Format Options
--swiftversion 5.9
--indent 4
--indentcase false
--trimwhitespace always
--voidtype tuple
--nospaceoperators ..<,...
--wrapcollections before-first
--wraparguments before-first
--wrapparameters before-first
--maxwidth 120

# Rules
--enable blankLinesAroundMark
--enable consecutiveSpaces
--enable duplicateImports
--enable elseOnSameLine
--enable emptyBraces
--enable indent
--enable linebreaks
--enable numberFormatting
--enable redundantBreak
--enable redundantExtensionACL
--enable redundantFileprivate
--enable redundantGet
--enable redundantInit
--enable redundantLet
--enable redundantLetError
--enable redundantNilInit
--enable redundantObjc
--enable redundantParens
--enable redundantPattern
--enable redundantRawValues
--enable redundantReturn
--enable redundantSelf
--enable redundantType
--enable redundantVoidReturnType
--enable semicolons
--enable sortImports
--enable spaceAroundBraces
--enable spaceAroundBrackets
--enable spaceAroundComments
--enable spaceAroundGenerics
--enable spaceAroundOperators
--enable spaceAroundParens
--enable spaceInsideBraces
--enable spaceInsideBrackets
--enable spaceInsideComments
--enable spaceInsideGenerics
--enable spaceInsideParens
--enable todos
--enable trailingClosures
--enable trailingCommas
--enable trailingSpace
--enable typeSugar
--enable unusedArguments
--enable void
--enable wrapArguments
--enable wrapAttributes
--enable wrapMultilineStatementBraces

# Disabled Rules
--disable andOperator
--disable wrapConditionalBodies
--disable wrapEnumCases
--disable wrapSwitchCases

# Excluded Paths
--exclude .build
--exclude build
--exclude Tests/Resources
EOF
    fi
    
    # Format check or format based on argument
    if [[ "${1:-}" == "--check" ]]; then
        log_info "Checking formatting..."
        if swiftformat --lint .; then
            log_info "All files are properly formatted ✓"
            exit 0
        else
            log_error "Some files need formatting"
            log_info "Run './Scripts/format.sh' to fix formatting"
            exit 1
        fi
    else
        log_info "Formatting Swift files..."
        swiftformat .
        log_info "Formatting complete!"
    fi
}

# Run main function
main "$@"