# VoiceType Privacy Policy

Last updated: [Date]

## Our Commitment to Privacy

VoiceType is built on a foundation of absolute privacy. We believe your words, thoughts, and voice are yours alone. This document explains in detail how VoiceType protects your privacy.

## Core Privacy Principles

### 1. Local Processing Only
Every aspect of VoiceType's speech recognition happens on your device:
- Audio capture from your microphone
- Conversion to text using AI models
- Text insertion into applications
- All settings and preferences

**No exceptions. No "anonymized" data. No analytics.**

### 2. No Internet Required
After initial download and installation:
- VoiceType works completely offline
- No features require internet connection
- Model updates are optional and manual
- No cloud services or accounts

### 3. Zero Data Collection
VoiceType does not collect, store, or transmit:
- Your voice recordings
- Transcribed text
- Usage patterns
- Error reports
- System information
- Any personally identifiable information

## Technical Privacy Details

### Audio Processing

**What happens to your voice:**
1. Audio is captured from your selected microphone
2. Converted to digital format in memory (not saved to disk)
3. Processed by the AI model locally
4. Immediately discarded after text generation
5. No audio is ever written to storage

**Technical implementation:**
- Audio buffer exists only in RAM
- Overwritten immediately after processing
- No temporary files created
- No caching mechanisms

### Text Processing

**How your text is handled:**
1. Generated text exists briefly in memory
2. Inserted at cursor position in target app
3. No copy retained by VoiceType
4. No logging of transcribed content
5. No pattern analysis or learning

### Model Storage

**AI models on your device:**
- Stored in `~/Library/Application Support/VoiceType/Models/`
- Read-only files after download
- No modification based on your usage
- No personal data embedded
- Can be deleted anytime

### Settings Storage

**Your preferences:**
- Stored locally in `~/Library/Preferences/com.voicetype.plist`
- Contains only:
  - Selected language
  - Hotkey configuration
  - Audio device selection
  - UI preferences
- No usage data or history

## Permissions Explained

### Microphone Access
**Why needed:** To capture your voice for transcription

**What it allows:**
- Recording audio when you activate the hotkey
- Monitoring audio levels for the level meter

**What it doesn't allow:**
- Recording without your explicit action
- Accessing microphone when app is quit
- Sending audio anywhere

**You can:**
- Revoke permission anytime in System Settings
- VoiceType will clearly indicate when it cannot function

### Accessibility Access
**Why needed:** To insert text and monitor hotkeys system-wide

**What it allows:**
- Inserting transcribed text at cursor position
- Detecting when you press the hotkey
- Working across all applications

**What it doesn't allow:**
- Reading your screen content
- Accessing existing text
- Monitoring other keystrokes
- Accessing files or passwords

**You can:**
- Revoke permission anytime in System Settings
- VoiceType will only work in its own window without this

## Network Communication

### During Installation
VoiceType connects to the internet only for:
1. **Initial download** from official source
2. **Model downloads** when you select Balanced/Accurate models
3. **Manual update checks** if you choose to check

### During Use
**VoiceType makes NO network connections during normal operation**

You can verify this:
- Use Little Snitch or similar network monitors
- Check Activity Monitor's Network tab
- Monitor your router's connection logs
- Use tcpdump or Wireshark

### Updates
- Update checks are manual only
- You must explicitly choose to check
- Can be completely disabled
- Updates download from official source only

## Data Security

### Encryption
- Models are code-signed and verified
- Preferences use macOS standard encryption
- No sensitive data is stored to encrypt

### Access Control
- Only VoiceType process can access its files
- Standard macOS file permissions apply
- No network services or APIs

### Memory Security
- Audio buffers cleared immediately
- No swap file usage for audio data
- Memory released promptly

## Third-Party Services

**VoiceType uses NO third-party services:**
- No analytics providers
- No crash reporting services
- No cloud storage
- No user accounts
- No licensing servers
- No telemetry

## Open Technologies

VoiceType builds on open technologies:
- **Whisper AI models** (from OpenAI, modified for local use)
- **Core ML** (Apple's on-device machine learning)
- **Standard macOS APIs**

These are used entirely locally with no external communication.

## Your Rights

### You Always Have the Right To:
1. **Use VoiceType completely offline**
2. **Delete all VoiceType data instantly**
3. **Revoke permissions anytime**
4. **Inspect what files VoiceType creates**
5. **Monitor all VoiceType's activities**
6. **Use without any account or registration**

### Data Deletion

To completely remove VoiceType and all its data:

```bash
# 1. Quit VoiceType

# 2. Remove application
rm -rf /Applications/VoiceType.app

# 3. Remove all data
rm -rf ~/Library/Application Support/VoiceType/
rm ~/Library/Preferences/com.voicetype.plist
rm -rf ~/Library/Caches/com.voicetype/

# 4. Remove from accessibility and microphone permissions
# (Via System Settings > Privacy & Security)
```

## Compliance

### GDPR (European Users)
- No personal data is collected, so GDPR doesn't apply
- You maintain complete control of any text you create
- No data to request or delete

### CCPA (California Users)  
- No personal information is collected or sold
- No data sharing with third parties
- Complete user control

### COPPA (Children's Privacy)
- VoiceType doesn't knowingly collect any data from anyone
- Safe for users of all ages
- No account creation required

## Transparency Reports

Since VoiceType collects no data:
- We have no data to share with governments
- We receive no data requests
- We have no user data to breach
- We maintain no logs to subpoena

## Contact

Questions about privacy? Contact:
- Email: [privacy email]
- Address: [company address]

**For verification:**
- Monitor VoiceType's network activity yourself
- Inspect all files VoiceType creates
- We encourage security researchers to verify our claims

## Changes to Privacy Policy

This privacy policy may be updated to:
- Clarify existing practices
- Reflect new features (always privacy-first)
- Improve transparency

We will never:
- Start collecting data
- Add analytics
- Require accounts
- Compromise local-only processing

---

**Bottom Line:** Your voice is yours. Your words are yours. Your privacy is absolute. VoiceType is a tool, not a service. It works for you, on your device, with your data staying exactly where it belongs - with you.