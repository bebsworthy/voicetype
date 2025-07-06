# VoiceType Frequently Asked Questions

Quick answers to common questions about VoiceType.

## General Questions

### What is VoiceType?
VoiceType is a privacy-focused voice-to-text application for macOS that converts your speech into text entirely offline. All processing happens locally on your Mac without any internet connection.

### How is VoiceType different from Siri dictation?
- **Privacy**: VoiceType processes everything locally, Siri sends audio to Apple servers
- **Offline**: Works without internet connection
- **Languages**: Supports 30+ languages with one-time model download
- **Customization**: Choose accuracy levels and processing options
- **Integration**: Works in any text field, not just Apple apps

### Is VoiceType really private?
Yes! VoiceType:
- Never connects to the internet for transcription
- Processes all audio on your device
- Doesn't collect any usage data or analytics
- Immediately discards audio after transcription
- Has no user accounts or cloud features

### What languages does VoiceType support?
VoiceType supports 30+ languages including:
English, Spanish, French, German, Italian, Portuguese, Dutch, Polish, Russian, Chinese, Japanese, Korean, Arabic, Hindi, Turkish, Vietnamese, Indonesian, Thai, Swedish, Norwegian, Danish, Finnish, Greek, Czech, Romanian, Hungarian, Ukrainian, Hebrew, Malay, and Tagalog.

### Does VoiceType work offline?
Yes! After initial installation and model download, VoiceType works completely offline. No internet connection is required for transcription.

## Installation & Setup

### What are the system requirements?
- **Minimum**: macOS 12.0, 4GB RAM, 200MB storage
- **Recommended**: macOS 13.0+, 8GB RAM, Apple Silicon Mac

### Why does VoiceType need accessibility permission?
Accessibility permission allows VoiceType to:
- Insert transcribed text into any application
- Monitor global hotkey presses
- Work system-wide across all apps

This permission doesn't allow reading your screen content or accessing files.

### Why does VoiceType need microphone permission?
Microphone access is required to capture your voice for transcription. Audio is processed locally and immediately discarded after conversion to text.

### Can I use VoiceType without giving permissions?
No, both permissions are essential:
- Without microphone access: Can't capture audio
- Without accessibility access: Can't insert text or use global hotkey

### How do I change permissions after installation?
1. Go to System Settings > Privacy & Security
2. For microphone: Privacy & Security > Microphone
3. For accessibility: Privacy & Security > Accessibility
4. Toggle VoiceType on/off as needed

## Usage Questions

### How do I start dictating?
1. Place cursor where you want text
2. Press and hold your hotkey (default: Cmd+Shift+V)
3. Speak clearly
4. Release hotkey to transcribe

### Can I change the hotkey?
Yes! Go to Settings > General and click in the hotkey field to set a new combination.

### How long can I record?
Recordings can be up to 30 seconds per session. For longer content, simply record multiple times.

### Can I use VoiceType in multiple languages?
Yes! Either:
- Enable auto-detection to switch languages automatically
- Manually select language in settings for faster processing

### Does VoiceType add punctuation automatically?
Yes, VoiceType intelligently adds periods, commas, and other punctuation. You can also say punctuation marks explicitly.

### Can I dictate special characters or formatting?
Yes, you can say:
- "Period" for .
- "Comma" for ,
- "New line" for line break
- "Capital [word]" for capitalization
- And more punctuation marks

## Model Questions

### What's the difference between Fast, Balanced, and Accurate models?

**Fast (27MB)**
- Quickest response time
- Good for everyday use
- Pre-installed
- Lowest resource usage

**Balanced (74MB)**
- Better accuracy
- Good speed
- Best for most users
- Downloads on first use

**Accurate (140MB)**
- Highest accuracy
- Slower processing
- Best for professional use
- Downloads on first use

### Do I need to download all models?
No, start with Fast (pre-installed). Download others only if you need better accuracy.

### Where are models stored?
Models are stored in `~/Library/Application Support/VoiceType/Models/`

### Can I delete models to save space?
Yes, you can delete models you don't use from Settings > Models. You can re-download them later.

### Will models be updated?
Models may receive updates for improved accuracy. Updates are optional and can be managed in settings.

## Privacy & Security

### Does VoiceType collect any data?
No. VoiceType:
- Doesn't collect usage statistics
- Has no analytics or telemetry
- Doesn't require user accounts
- Never connects to servers for transcription

### Is my audio recorded or stored?
No. Audio is:
- Processed in real-time
- Immediately converted to text
- Discarded right after transcription
- Never saved to disk

### Can VoiceType access my files or screen content?
No. Accessibility permission only allows:
- Inserting text at cursor position
- Detecting global hotkey presses
- Cannot read screen content or access files

### Is VoiceType open source?
VoiceType uses open technologies like OpenAI's Whisper but includes proprietary optimizations for macOS integration.

### How can I verify privacy claims?
- Monitor network activity - VoiceType makes no connections during use
- Check Activity Monitor for file/network access
- Use Little Snitch or similar tools to verify

## Troubleshooting

### Why isn't my hotkey working?
1. Check accessibility permission is granted
2. Ensure no other app uses the same hotkey
3. Try a different key combination
4. Restart VoiceType

### Why is transcription inaccurate?
- Speak more clearly
- Reduce background noise
- Try Balanced or Accurate model
- Check correct language is selected
- Ensure microphone is positioned properly

### Why does VoiceType use so much CPU?
- Switch to Fast model
- Enable low power mode in settings
- Reduce processing threads
- Disable GPU acceleration if issues persist

### Text appears in wrong place?
- Click in target text field first
- Ensure field has focus
- Try clipboard insertion method for problematic apps

### Can I use VoiceType with [specific app]?
VoiceType works with any app that accepts text input. Some apps may require clipboard insertion method (Settings > Advanced).

## Compatibility

### Does VoiceType work with Microsoft Office?
Yes, VoiceType works with Word, Excel, PowerPoint, and Outlook. Ensure documents aren't in protected view mode.

### Can I use VoiceType in web browsers?
Yes, VoiceType works in all major browsers (Safari, Chrome, Firefox, Edge). Click in the text field before dictating.

### Does VoiceType work with messaging apps?
Yes, including:
- Slack, Teams, Discord
- Messages, WhatsApp Web
- Email clients
- Social media sites

### Are there any apps VoiceType doesn't work with?
Some limitations:
- Games with custom text input
- Apps with non-standard text fields
- Terminal requires clipboard mode
- Some virtual machines

## Features & Limitations

### Can VoiceType transcribe audio files?
No, VoiceType only works with real-time microphone input. It's designed for live dictation, not file transcription.

### Can multiple people use VoiceType?
Yes, but:
- Settings are per-user on the Mac
- Each user needs their own permissions
- Models are shared between users

### Does VoiceType work with external microphones?
Yes! VoiceType works with:
- USB microphones
- Bluetooth headsets
- Built-in Mac microphone
- Audio interfaces

### Can I use VoiceType for live captions?
No, VoiceType is designed for dictation into text fields, not for captioning audio/video streams.

### Is there a mobile version?
No, VoiceType is exclusively for macOS. Mobile devices have different privacy and system constraints.

## Support

### How do I report a bug?
1. Enable debug logging in Settings > Advanced
2. Reproduce the issue
3. Send logs with description to [support email]

### Where can I suggest features?
Send feature requests to [feedback email] or post in our [community forum].

### Is there a user community?
Yes! Join our [Discord/Forum] for tips, help, and discussions with other users.

### How often is VoiceType updated?
VoiceType receives regular updates for:
- Bug fixes
- Performance improvements
- New features
- Model updates

### What if my question isn't answered here?
Check our:
- [Troubleshooting Guide](Troubleshooting.md)
- [Usage Guide](Usage.md)
- Contact support at [support email]