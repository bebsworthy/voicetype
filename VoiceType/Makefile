# VoiceType Makefile
# Convenience commands for common development tasks

.PHONY: all setup build test clean release help

# Default target
all: build

# Setup development environment
setup:
	@echo "Setting up development environment..."
	@./Scripts/setup.sh

# Build targets
build:
	@echo "Building VoiceType (debug)..."
	@./Scripts/build.sh debug

build-release:
	@echo "Building VoiceType (release)..."
	@./Scripts/build.sh release

build-universal:
	@echo "Building VoiceType (universal release)..."
	@./Scripts/build.sh release universal

# Test targets
test:
	@echo "Running all tests..."
	@./Scripts/test.sh all

test-unit:
	@echo "Running unit tests..."
	@./Scripts/test.sh unit

test-integration:
	@echo "Running integration tests..."
	@./Scripts/test.sh integration

test-performance:
	@echo "Running performance tests..."
	@./Scripts/test.sh performance

test-coverage:
	@echo "Running tests with coverage..."
	@./Scripts/test.sh all true

# Code quality
lint:
	@echo "Running SwiftLint..."
	@swiftlint lint --quiet

format:
	@echo "Formatting code..."
	@./Scripts/format.sh

format-check:
	@echo "Checking code formatting..."
	@./Scripts/format.sh --check

# Signing and release
sign:
	@echo "Signing application..."
	@./Scripts/sign.sh

release:
	@echo "Creating release package..."
	@if [ -z "$(VERSION)" ]; then \
		echo "Error: VERSION not specified. Use: make release VERSION=1.0.0"; \
		exit 1; \
	fi
	@./Scripts/release.sh $(VERSION) $(or $(BUILD),1)

# Clean
clean:
	@echo "Cleaning build artifacts..."
	@./Scripts/clean.sh

clean-all:
	@echo "Deep cleaning (including Xcode derived data)..."
	@./Scripts/clean.sh --deep

# Run the app
run: build
	@echo "Running VoiceType..."
	@./build/VoiceType.app/Contents/MacOS/VoiceType

# Open in Xcode
xcode:
	@echo "Generating and opening Xcode project..."
	@swift package generate-xcodeproj
	@open VoiceType.xcodeproj

# Documentation
docs:
	@echo "Generating documentation..."
	@swift-doc generate Sources --module-name VoiceType --output docs

# Dependencies
deps-check:
	@echo "Checking dependencies..."
	@swift package resolve
	@swift package show-dependencies

deps-update:
	@echo "Updating dependencies..."
	@swift package update

# CI simulation
ci-local:
	@echo "Running CI pipeline locally..."
	@make clean
	@make lint
	@make build
	@make test

# Help
help:
	@echo "VoiceType Development Commands"
	@echo "=============================="
	@echo ""
	@echo "Setup:"
	@echo "  make setup              - Set up development environment"
	@echo ""
	@echo "Build:"
	@echo "  make build              - Build debug version"
	@echo "  make build-release      - Build release version"
	@echo "  make build-universal    - Build universal release"
	@echo ""
	@echo "Test:"
	@echo "  make test               - Run all tests"
	@echo "  make test-unit          - Run unit tests only"
	@echo "  make test-integration   - Run integration tests only"
	@echo "  make test-performance   - Run performance tests"
	@echo "  make test-coverage      - Run tests with coverage"
	@echo ""
	@echo "Code Quality:"
	@echo "  make lint               - Run SwiftLint"
	@echo "  make format             - Format code"
	@echo "  make format-check       - Check code formatting"
	@echo ""
	@echo "Release:"
	@echo "  make sign               - Sign the application"
	@echo "  make release VERSION=x.y.z - Create release (BUILD=n optional)"
	@echo ""
	@echo "Other:"
	@echo "  make run                - Build and run the app"
	@echo "  make clean              - Clean build artifacts"
	@echo "  make clean-all          - Deep clean including Xcode"
	@echo "  make xcode              - Open in Xcode"
	@echo "  make docs               - Generate documentation"
	@echo "  make ci-local           - Run CI pipeline locally"
	@echo "  make help               - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make release VERSION=1.0.0 BUILD=42"
	@echo "  make test-coverage"
	@echo "  make build-universal"