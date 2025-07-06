# VoiceType

<div align="center">
  <img src="Documentation/assets/voicetype-logo.png" alt="VoiceType Logo" width="128" height="128" />
  
  **Privacy-first dictation for macOS**
  
  [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
  [![macOS 12.0+](https://img.shields.io/badge/macOS-12.0+-blue.svg)](https://www.apple.com/macos/)
  [![Swift 5.9+](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
  [![Build Status](https://github.com/yourusername/voicetype/workflows/CI/badge.svg)](https://github.com/yourusername/voicetype/actions)
</div>

## 🎯 What is VoiceType?

VoiceType is an open-source, privacy-first dictation tool for macOS that converts speech to text using local AI models. Unlike cloud-based solutions, VoiceType processes everything on your device, ensuring your voice never leaves your computer.

### ✨ Key Features

- **🔒 100% Privacy**: All processing happens on-device. No cloud, no data collection, no internet required
- **🚀 Fast & Accurate**: Real-time transcription with <5 second latency using OpenAI Whisper models
- **🌍 30+ Languages**: Built-in support for multiple languages with auto-detection
- **⌨️ Universal Compatibility**: Works with any macOS application that accepts text input
- **🎛️ Flexible Models**: Choose between speed and accuracy with multiple model sizes
- **🔌 Extensible**: Plugin system for custom audio processors and text injectors
- **📖 Open Source**: MIT licensed, community-driven development

## 🚀 Quick Start

### Download

Download the latest release from the [Releases](https://github.com/yourusername/voicetype/releases) page.

### First Launch

1. **Open VoiceType** - Look for the microphone icon in your menu bar
2. **Grant Permissions** - Allow microphone access when prompted
3. **Choose Your Model** - Select Fast (default) for quick results or Accurate for better quality
4. **Set Your Hotkey** - Default is `Ctrl+Shift+V`
5. **Start Dictating** - Press your hotkey in any app and start speaking!

## 📋 System Requirements

- macOS 12.0 (Monterey) or later
- 8GB RAM minimum (16GB recommended for larger models)
- Apple Silicon (M1/M2/M3) or Intel processor
- ~200MB disk space (plus model downloads)

## 🎮 How to Use

1. **Position your cursor** where you want to insert text
2. **Press your hotkey** (default: `Ctrl+Shift+V`)
3. **Speak clearly** for up to 5 seconds
4. **Watch your words appear** - VoiceType automatically inserts the text

### Pro Tips

- Speak naturally at a normal pace
- Minimize background noise for best results
- Use the Accurate model for technical terms
- Customize your hotkey in Settings

## 🛠️ Building from Source

### Prerequisites

- Xcode 15.0 or later
- macOS 13.0+ (for development)
- Apple Developer account (for code signing)

### Build Instructions

```bash
# Clone the repository
git clone https://github.com/yourusername/voicetype.git
cd voicetype/VoiceType

# Setup development environment
./Scripts/setup.sh

# Build the app
./Scripts/build.sh

# Run tests
./Scripts/test.sh

# Create release build
./Scripts/release.sh
```

### Development

```bash
# Open in Xcode
open VoiceType.xcodeproj

# Or use Swift Package Manager
swift build
swift test
```

## 🔧 Configuration

VoiceType can be customized through its settings panel or by editing the configuration file:

`~/Library/Application Support/VoiceType/config.json`

### Available Settings

- **Hotkey**: Customize your recording trigger
- **Model Selection**: Choose between Tiny (fast), Base (balanced), or Small (accurate)
- **Language**: Select from 30+ languages or use auto-detection
- **Audio Device**: Choose your preferred microphone

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](Documentation/DeveloperGuide/Contributing.md) for details.

### Areas for Contribution

- 🔌 **App-specific text injectors** - Add support for more applications
- 🎤 **Audio preprocessors** - Improve noise reduction and audio quality
- 🌐 **Translations** - Help translate the UI to more languages
- 📚 **Documentation** - Improve guides and tutorials
- 🐛 **Bug fixes** - Help us squash bugs

## 🏗️ Architecture

VoiceType uses a modular, protocol-first architecture:

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│   Menu Bar  │────▶│ Coordinator  │────▶│Audio Processor│
└─────────────┘     └──────────────┘     └──────────────┘
                            │                      │
                            ▼                      ▼
                    ┌──────────────┐     ┌──────────────┐
                    │ Transcriber  │────▶│Text Injector │
                    └──────────────┘     └──────────────┘
```

See our [Architecture Guide](Documentation/DeveloperGuide/Architecture.md) for details.

## 🐛 Troubleshooting

### Common Issues

**VoiceType doesn't appear in menu bar**
- Check if the app is running in Activity Monitor
- Try launching from Applications folder

**Hotkey doesn't work**
- Grant Input Monitoring permission in System Settings → Privacy & Security
- Check for conflicts with other apps

**No text appears after speaking**
- Verify microphone permission is granted
- Check audio input levels in Settings
- Try the clipboard fallback mode

See our [Troubleshooting Guide](Documentation/UserGuide/Troubleshooting.md) for more solutions.

## 📜 License

VoiceType is released under the MIT License. See [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [OpenAI Whisper](https://github.com/openai/whisper) for the amazing speech recognition models
- [Apple CoreML](https://developer.apple.com/machine-learning/core-ml/) for on-device inference
- The Swift and macOS developer communities

## 🔗 Links

- [Documentation](Documentation/UserGuide/README.md)
- [Report Issues](https://github.com/yourusername/voicetype/issues)
- [Discussions](https://github.com/yourusername/voicetype/discussions)
- [Changelog](CHANGELOG.md)

---

<div align="center">
  Made with ❤️ for privacy-conscious users everywhere
</div>