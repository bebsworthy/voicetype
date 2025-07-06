# VoiceType Build Scripts

This directory contains build and automation scripts for the VoiceType project.

## Available Scripts

### setup.sh
Sets up a new development environment for contributors.
```bash
./Scripts/setup.sh
```
- Checks system requirements (macOS, Xcode, Swift)
- Installs development dependencies via Homebrew
- Sets up Git hooks
- Creates local configuration files
- Optionally configures VS Code

### build.sh
Builds the VoiceType application.
```bash
./Scripts/build.sh [configuration] [architecture]
```
- `configuration`: debug (default) or release
- `architecture`: arm64, x86_64, or universal (default)

Example:
```bash
./Scripts/build.sh release universal
```

### test.sh
Runs the test suite.
```bash
./Scripts/test.sh [test-type] [coverage] [parallel]
```
- `test-type`: unit, integration, performance, or all (default)
- `coverage`: true or false (default)
- `parallel`: true (default) or false

Example:
```bash
./Scripts/test.sh all true true
```

### sign.sh
Signs the application for distribution.
```bash
./Scripts/sign.sh [app-path]
```
- `app-path`: Path to the .app bundle (default: build/VoiceType.app)

Required environment variables:
- `DEVELOPER_ID_APPLICATION`: Your Developer ID certificate name
- `DEVELOPMENT_TEAM`: Your Apple Developer Team ID
- `APPLE_ID`: Your Apple ID (for notarization)
- `APPLE_ID_PASSWORD`: App-specific password (for notarization)

### release.sh
Creates a release-ready DMG package.
```bash
./Scripts/release.sh [version] [build-number]
```
- `version`: Version number (e.g., 1.0.0)
- `build-number`: Build number (e.g., 1)

Example:
```bash
./Scripts/release.sh 1.0.0 42
```

### clean.sh
Removes build artifacts and caches.
```bash
./Scripts/clean.sh [--deep]
```
- `--deep`: Also cleans Xcode derived data

### format.sh
Formats Swift code using SwiftFormat.
```bash
./Scripts/format.sh [--check]
```
- `--check`: Only check formatting without making changes

## CI/CD Integration

These scripts are designed to work both locally and in CI/CD environments:

1. **Local Development**: Run scripts directly from the command line
2. **GitHub Actions**: Scripts are called from workflow files in `.github/workflows/`
3. **Environment Variables**: Use `.env.local` for local settings

## Best Practices

1. Always run `setup.sh` when setting up a new development environment
2. Use `build.sh debug` for development builds
3. Run `test.sh all` before committing changes
4. Use `release.sh` only for official releases
5. Keep scripts executable: `chmod +x Scripts/*.sh`

## Troubleshooting

### Build Failures
- Run `clean.sh --deep` to clean all caches
- Ensure Xcode is properly installed and licensed
- Check that all required environment variables are set

### Signing Issues
- Verify your Developer ID certificate is installed
- Check that environment variables are properly exported
- Ensure your certificate hasn't expired

### Test Failures
- Run tests individually to isolate issues
- Check test logs in the build directory
- Ensure all dependencies are installed

## Contributing

When adding new scripts:
1. Follow the existing script structure and style
2. Include proper error handling and logging
3. Document the script in this README
4. Make the script executable
5. Test on both Intel and Apple Silicon Macs