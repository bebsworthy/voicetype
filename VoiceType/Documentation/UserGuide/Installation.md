# VoiceType Installation Guide

This guide will walk you through downloading, installing, and setting up VoiceType on your Mac.

## Download VoiceType

### Official Download
1. Download VoiceType from [official source]
2. The download will be a `.dmg` file (disk image)
3. File size is approximately 50MB (includes the Fast model)

### System Check
Before installing, ensure your Mac meets the requirements:
- macOS 12.0 (Monterey) or later
- At least 4GB RAM
- 200MB free storage space

## Installation Steps

### 1. Mount the Disk Image
1. Locate the downloaded `VoiceType.dmg` file in your Downloads folder
2. Double-click to open it
3. A new window will appear showing the VoiceType app icon

### 2. Install the Application
1. Drag the VoiceType icon to the Applications folder
2. Wait for the copy to complete
3. Eject the disk image by clicking the eject button in Finder

### 3. First Launch
1. Open your Applications folder
2. Find VoiceType and double-click to launch
3. If you see a security warning:
   - Click "Open" to proceed
   - Or go to System Settings > Privacy & Security and click "Open Anyway"

## Initial Setup

### Welcome Screen
On first launch, VoiceType will guide you through initial setup:

[Screenshot placeholder: Welcome screen]

### Step 1: Grant Microphone Access
VoiceType needs access to your microphone to hear your voice:

1. Click "Request Microphone Access"
2. In the system dialog, click "Allow"
3. The status indicator will turn green when granted

[Screenshot placeholder: Microphone permission dialog]

**Why this permission?**
- Required to capture your voice for transcription
- Audio is processed locally and never sent anywhere
- You can revoke this permission anytime in System Settings

### Step 2: Grant Accessibility Access
VoiceType needs accessibility permissions to type text in other applications:

1. Click "Request Accessibility Access"
2. System Settings will open to the Privacy & Security section
3. Find VoiceType in the list and toggle it ON
4. You may need to enter your Mac password
5. Return to VoiceType - the status will update automatically

[Screenshot placeholder: Accessibility settings]

**Why this permission?**
- Allows VoiceType to insert text into any application
- Required for the global hotkey to work system-wide
- Does not give access to read your screen or files

### Step 3: Choose Your Language
Select your primary language or enable auto-detection:

1. Choose from 30+ available languages
2. Or select "Auto-detect" to automatically recognize the language you speak
3. You can change this later in Settings

[Screenshot placeholder: Language selection]

### Step 4: Configure Your Hotkey
Set up the keyboard shortcut to activate voice input:

1. Click in the hotkey field
2. Press your desired key combination (e.g., Cmd+Shift+V)
3. Make sure it doesn't conflict with other shortcuts
4. Click "Continue"

[Screenshot placeholder: Hotkey configuration]

**Recommended Hotkeys:**
- `Cmd+Shift+V` - Easy to remember (V for Voice)
- `Cmd+Option+Space` - Quick access
- `F5` - Single key activation

### Step 5: Select Initial Model
Choose which AI model to use:

[Screenshot placeholder: Model selection]

**Fast (Recommended for first use)**
- Pre-installed, works immediately
- Lowest resource usage
- Good for everyday dictation

**Balanced**
- Downloads on first use (74MB)
- Better accuracy
- Good balance of speed and quality

**Accurate**
- Downloads on first use (140MB)
- Highest accuracy
- Best for professional documents

## Verify Installation

### Test Your Setup
1. Click "Test Microphone" to ensure audio is working
2. Try the hotkey in a text application
3. Speak a test phrase and watch it appear

### Check Menu Bar
VoiceType runs in your menu bar:
1. Look for the VoiceType icon in the top-right corner
2. Click it to access quick settings
3. The icon shows recording status

[Screenshot placeholder: Menu bar icon]

## Model Downloads

### Automatic Downloads
When you select Balanced or Accurate models:
1. Download starts automatically
2. Progress appears in the settings window
3. You can use VoiceType with Fast model while downloading
4. Downloads resume if interrupted

### Manual Download
If automatic download fails:
1. Open VoiceType Settings (Cmd+,)
2. Go to the Models tab
3. Click "Download" next to the desired model
4. Check your internet connection if issues persist

## Optional Configuration

### Launch at Login
To have VoiceType start automatically:
1. Open Settings (Cmd+,)
2. Go to General tab
3. Enable "Launch at login"

### Menu Bar Options
Customize the menu bar presence:
1. Choose icon style (normal or monochrome)
2. Show/hide recording indicator
3. Enable/disable menu bar altogether

## Troubleshooting Installation

### "App can't be opened" Error
1. Right-click VoiceType in Applications
2. Select "Open" from the context menu
3. Click "Open" in the dialog

### Permissions Not Working
1. Quit VoiceType completely
2. Open System Settings > Privacy & Security
3. Remove and re-add VoiceType permissions
4. Restart VoiceType

### Model Download Fails
1. Check internet connection
2. Ensure you have enough storage space
3. Try switching to a different network
4. Contact support if issues persist

## Uninstallation

To remove VoiceType:
1. Quit VoiceType from the menu bar
2. Drag VoiceType from Applications to Trash
3. Remove settings (optional):
   - `~/Library/Preferences/com.voicetype.plist`
   - `~/Library/Application Support/VoiceType/`

## Next Steps

Installation complete! Now learn how to use VoiceType effectively:
- [Usage Guide](Usage.md) - Learn all the features
- [Troubleshooting](Troubleshooting.md) - Solve common issues
- [FAQ](FAQ.md) - Quick answers to common questions