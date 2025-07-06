# GitHub Actions Workflows

This directory contains CI/CD workflows for VoiceType.

## Workflows

### ci.yml
Runs on every push and pull request to validate code quality.
- Linting with SwiftLint
- Unit and integration tests
- Performance tests
- Security scanning
- Code coverage reporting

### release.yml
Creates official releases when pushing version tags.
- Builds universal binary
- Code signing with Developer ID
- Notarization with Apple
- DMG creation
- GitHub release creation

### nightly.yml
Runs daily to create development builds.
- Full test suite execution
- Performance regression detection
- Nightly build artifacts

## Required Secrets

Configure these secrets in your GitHub repository settings:

### Code Signing
- `DEVELOPER_ID_APPLICATION`: Your Developer ID certificate name
  - Format: "Developer ID Application: Your Name (TEAMID)"
  
- `DEVELOPMENT_TEAM`: Your Apple Developer Team ID
  - Format: "TEAMID" (10 characters)
  
- `CERTIFICATES_P12`: Base64-encoded P12 certificate file
  - Export from Keychain Access
  - Convert to base64: `base64 -i certificate.p12 | pbcopy`
  
- `CERTIFICATES_PASSWORD`: Password for the P12 file
  
- `KEYCHAIN_PASSWORD`: Temporary keychain password for CI

### Notarization
- `APPLE_ID`: Your Apple ID email
  
- `APPLE_ID_PASSWORD`: App-specific password
  - Generate at https://appleid.apple.com
  - Format: "xxxx-xxxx-xxxx-xxxx"

## Setting Up Secrets

1. Export your Developer ID certificate:
   ```bash
   security find-identity -v -p codesigning
   # Note your certificate name and team ID
   ```

2. Export certificate to P12:
   ```bash
   # In Keychain Access:
   # 1. Find your Developer ID Application certificate
   # 2. Right-click → Export
   # 3. Save as .p12 with password
   ```

3. Convert P12 to base64:
   ```bash
   base64 -i certificate.p12 | pbcopy
   # This copies the base64 string to clipboard
   ```

4. Create app-specific password:
   - Go to https://appleid.apple.com
   - Sign in → Security → App-Specific Passwords
   - Generate password for "VoiceType CI"

5. Add secrets to GitHub:
   - Go to Settings → Secrets and variables → Actions
   - Add each secret with the exact name listed above

## Testing Workflows Locally

Use [act](https://github.com/nektos/act) to test workflows locally:

```bash
# Install act
brew install act

# Test CI workflow
act -j test

# Test with secrets (create .secrets file first)
act -j build-and-release --secret-file .secrets
```

## Workflow Permissions

Ensure your repository has appropriate permissions:
- Settings → Actions → General
- Workflow permissions: Read and write permissions
- Allow GitHub Actions to create and approve pull requests

## Monitoring

- Check Actions tab for workflow runs
- Enable notifications for failed workflows
- Review logs for any issues
- Monitor performance metrics in nightly builds

## Troubleshooting

### Certificate Issues
- Ensure certificate hasn't expired
- Verify certificate is for Developer ID Application
- Check certificate has private key

### Notarization Failures
- Verify app-specific password is current
- Check Apple Developer account is in good standing
- Ensure bundle ID matches certificate

### Build Failures
- Check Xcode version compatibility
- Verify Swift version requirements
- Review dependency resolution logs