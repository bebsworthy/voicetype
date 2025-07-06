# VoiceType Troubleshooting Guide

Having issues with VoiceType? This guide covers common problems and their solutions.

## Quick Fixes

Before diving into specific issues, try these general solutions:

1. **Restart VoiceType**: Quit from menu bar and relaunch
2. **Check Permissions**: Ensure both microphone and accessibility access are granted
3. **Update macOS**: Some issues are resolved with system updates
4. **Reboot Mac**: Clears temporary system issues

## Common Issues

### VoiceType Won't Start

#### Symptoms
- App doesn't appear in menu bar
- Crashes immediately after launching
- Beach ball or frozen on startup

#### Solutions

**1. Check System Requirements**
- Ensure macOS 12.0 or later
- Verify 4GB+ RAM available
- Check 200MB+ storage space

**2. Reset Preferences**
```bash
# In Terminal:
rm ~/Library/Preferences/com.voicetype.plist
```

**3. Clear Application Support**
```bash
# In Terminal:
rm -rf ~/Library/Application Support/VoiceType/
```

**4. Reinstall Application**
1. Quit VoiceType
2. Drag to Trash from Applications
3. Empty Trash
4. Download fresh copy
5. Reinstall

### Hotkey Not Working

#### Symptoms
- Pressing hotkey does nothing
- No recording indicator appears
- Other apps respond to the hotkey instead

#### Solutions

**1. Check Accessibility Permission**
1. System Settings > Privacy & Security > Accessibility
2. Ensure VoiceType is listed and checked
3. If not, click + and add VoiceType
4. Toggle OFF and ON if already enabled

**2. Verify Hotkey Configuration**
1. Open VoiceType Settings
2. Check hotkey is properly set
3. Try a different combination
4. Avoid system-reserved shortcuts

**3. Test Conflict**
1. Quit other apps one by one
2. Test hotkey after each
3. Identify conflicting application
4. Change hotkey in either app

**4. Reset Hotkey Manager**
1. Settings > General
2. Clear hotkey field
3. Restart VoiceType
4. Set new hotkey

### No Audio Input / Microphone Issues

#### Symptoms
- No waveform during recording
- Transcription always empty
- "No audio detected" message

#### Solutions

**1. Check Microphone Permission**
1. System Settings > Privacy & Security > Microphone
2. Ensure VoiceType is enabled
3. Toggle OFF and ON to refresh

**2. Verify Audio Device**
1. Settings > Audio
2. Select correct input device
3. Check level meter for activity
4. Test with different microphone

**3. Test System Audio**
1. Open System Settings > Sound
2. Select Input tab
3. Speak and check level meter
4. Adjust input volume

**4. Check External Devices**
- Ensure microphone is plugged in
- Try different USB port
- Test microphone in other apps
- Check Bluetooth connection

### Poor Transcription Accuracy

#### Symptoms
- Many errors in transcribed text
- Wrong words frequently
- Misses entire phrases
- Poor punctuation

#### Solutions

**1. Improve Audio Quality**
- Move to quieter environment
- Position microphone properly (6-12 inches)
- Enable noise suppression
- Check for background noise

**2. Optimize Speech**
- Speak clearly and at moderate pace
- Avoid mumbling or whispering
- Maintain consistent volume
- Pause between sentences

**3. Try Different Model**
- Switch to Balanced or Accurate model
- Download if not installed
- Trade speed for accuracy

**4. Check Language Setting**
- Ensure correct language selected
- Try disabling auto-detect
- Match language to your accent

### Model Download Problems

#### Symptoms
- Download stuck at 0%
- "Download failed" error
- Extremely slow download
- Model corruption message

#### Solutions

**1. Check Internet Connection**
- Verify connection is active
- Test download speed
- Try different network
- Disable VPN if active

**2. Storage Space**
- Ensure 200MB+ free space
- Clear cache if needed
- Check download location

**3. Reset Download**
1. Settings > Models
2. Cancel stuck download
3. Quit VoiceType
4. Delete partial download:
```bash
rm -rf ~/Library/Application Support/VoiceType/Models/*.partial
```
5. Restart and retry

**4. Manual Download**
- Contact support for direct download link
- Place in Models folder manually
- Restart VoiceType to detect

### Text Not Inserting

#### Symptoms
- Recording works but no text appears
- Text appears in wrong location
- Only works in some apps
- Clipboard has text but not pasted

#### Solutions

**1. Verify Accessibility Permission**
- Critical for text insertion
- Must be enabled in System Settings
- Restart after enabling

**2. Check Target Application**
- Click in text field first
- Ensure field has focus
- Try different application
- Some apps need special handling

**3. Switch Insertion Method**
1. Settings > Advanced
2. Enable "Use clipboard insertion"
3. Test in problematic app
4. May be slightly slower

**4. App-Specific Issues**
- **Microsoft Office**: Ensure not in protected view
- **Web Browsers**: Click in text field, not page
- **Terminal**: May need clipboard method
- **Games**: Often incompatible

### High CPU/Memory Usage

#### Symptoms
- Mac runs slowly during use
- Fan runs constantly
- Battery drains quickly
- Beach balls frequently

#### Solutions

**1. Use Efficient Model**
- Switch to Fast model
- Trade accuracy for performance
- Good for most use cases

**2. Adjust Processing Settings**
1. Settings > Advanced
2. Reduce processing threads
3. Disable GPU acceleration
4. Enable low power mode

**3. Limit Recording Duration**
- Keep recordings under 30 seconds
- Process in smaller chunks
- Prevents memory buildup

**4. Check for Memory Leaks**
- Monitor Activity Monitor
- Restart VoiceType periodically
- Report persistent issues

### Permission Prompts Keep Appearing

#### Symptoms
- Repeatedly asked for permissions
- Settings don't stick
- Permissions reset on restart

#### Solutions

**1. Full Disk Access**
1. System Settings > Privacy & Security > Full Disk Access
2. Add VoiceType (optional but may help)
3. Restart Mac

**2. Reset Privacy Database**
```bash
# In Terminal (requires restart):
tccutil reset All com.voicetype
```

**3. Check Security Software**
- Antivirus may interfere
- Add VoiceType to allowlist
- Temporarily disable to test

## Advanced Troubleshooting

### Enable Debug Logging

1. Settings > Advanced > "Enable debug logging"
2. Reproduce issue
3. Find logs at:
```
~/Library/Logs/VoiceType/
```
4. Share with support team

### Safe Mode Start

Hold Option key while launching VoiceType:
- Loads with default settings
- Disables custom configurations
- Helps identify setting issues

### Complete Reset

Remove all VoiceType data:
```bash
# Quit VoiceType first
rm -rf ~/Library/Application Support/VoiceType/
rm ~/Library/Preferences/com.voicetype.plist
rm -rf ~/Library/Caches/com.voicetype/
```

## Performance Tips

### For Older Macs
- Use Fast model exclusively
- Disable all visual effects
- Close unnecessary apps
- Increase memory if possible

### For Best Results
- Use wired headset/microphone
- Minimize background apps
- Regular restarts
- Keep macOS updated

## Getting Help

### Before Contacting Support

1. Note your:
   - macOS version
   - VoiceType version (menu bar > About)
   - Mac model and year
   - Specific error messages

2. Try:
   - All relevant solutions above
   - Searching FAQ
   - Latest version

3. Gather:
   - Debug logs if enabled
   - Screenshots of issues
   - Steps to reproduce

### Support Channels
- Email: [support email]
- Documentation: [website]
- Community: [forum/discord]

## Next Steps

- [FAQ](FAQ.md) - Quick answers to common questions
- [Usage Guide](Usage.md) - Learn to use VoiceType effectively
- [Privacy](Privacy.md) - Understand our privacy guarantees