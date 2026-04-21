# LiveStreamingCore

<div align="center">

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Version](https://img.shields.io/badge/Version-1.1.0-purple.svg)

**Professional RTMP Live Streaming Framework for iOS**

</div>

---

A professional RTMP live streaming Swift Package for iOS. Built on HaishinKit with hardware acceleration, performance optimization, and diagnostic capabilities.

## ✨ Key Features

### 🎬 Streaming
- **RTMP/RTMPS Protocol** support
- **Screen Capture Streaming** - Real-time full device screen streaming
- **Platform Support** - YouTube Live, Twitch, Facebook, and all RTMP-compatible platforms
- **Auto Reconnection** - Exponential backoff automatic reconnection on failure

### ⚡ Performance Optimization
- **VideoToolbox Hardware Acceleration** - H.264 hardware encoding
- **Metal GPU Acceleration** - GPU-based image processing
- **Adaptive Bitrate** - Automatic quality adjustment based on network conditions
- **Hardware/Software Fallback** - Automatic fallback to software encoding when hardware fails

### 📊 Monitoring & Diagnostics
- **Real-time Statistics** - Bitrate, FPS, dropped frames, latency monitoring
- **Network Quality Analysis** - WiFi/Cellular detection, quality scoring
- **Comprehensive Diagnosis Report** - A-F grading system with recommendations
- **Performance Metrics** - CPU/GPU usage, frame processing time

### 🔒 Security
- **Keychain Integration** - Secure stream key storage
- **Device-locked Access Control** - Sensitive data protection

### 🎨 Additional Features
- **Text Overlay** - Real-time text rendering on video
- **Multiple Presets** - Optimized settings for YouTube, Twitch, Facebook
- **SwiftData Support** - Persistent settings storage
- **Full Localization** - Complete Korean language support

## 📋 Requirements

| Requirement | Version |
|-------------|---------|
| iOS | 17.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |

## 📦 Dependencies

| Library | Version | Description |
|---------|---------|-------------|
| [HaishinKit](https://github.com/shogo4405/HaishinKit.swift) | 2.2.4 | RTMP streaming core library |
| [Logboard](https://github.com/shogo4405/Logboard) | 2.6.0 | Structured logging utilities |

## 🚀 Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../Modules/LiveStreamingCore")
    // Or remote repository:
    // .package(url: "https://github.com/your-repo/LiveStreamingCore.git", from: "1.1.0")
]
```

Add the dependency to your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["LiveStreamingCore"]
)
```

## 📖 Usage

### 1. Import Module

```swift
import LiveStreamingCore
```

### 2. Configure Streaming

#### SwiftData-based Settings (Persistent)

```swift
let settings = LiveStreamSettingsModel()
settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
settings.streamKey = "your-stream-key"
settings.videoBitrate = 2500  // kbps
settings.videoWidth = 1280
settings.videoHeight = 720
settings.frameRate = 30
settings.audioBitrate = 128  // kbps
```

#### Codable-based Settings (Temporary)

```swift
var settings = LiveStreamSettings()
settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
settings.streamKey = "your-stream-key"
settings.videoBitrate = 2500
settings.videoWidth = 1280
settings.videoHeight = 720
```

### 3. Using YouTube Presets

```swift
var settings = LiveStreamSettings()
settings.applyYouTubeLivePreset(.hd720p)

// Detect current preset
if let preset = settings.detectYouTubePreset() {
    print("Current preset: \(preset.displayName)")
}
```

**Available Presets:**

| Preset | Resolution | FPS | Bitrate |
|--------|------------|-----|---------|
| `.sd480p` | 848×480 | 30 | 1,500 kbps |
| `.hd720p` | 1280×720 | 30 | 2,500 kbps |
| `.fhd1080p` | 1920×1080 | 30 | 4,500 kbps |
| `.custom` | User-defined | - | - |

### 4. Using HaishinKitManager

```swift
let manager = HaishinKitManager()

// Start streaming
Task {
    do {
        try await manager.startScreenCaptureStreaming(with: settings)
    } catch {
        print("Failed to start streaming: \(error)")
    }
}

// Stop streaming
Task {
    await manager.stopStreaming()
}
```

### 5. Connection Testing

```swift
Task {
    let result = await manager.testConnection(to: settings)
    if result.isSuccessful {
        print("Connection successful! Latency: \(result.latency)ms")
    } else {
        print("Connection failed: \(result.message)")
    }
}
```

### 6. Real-time Statistics Monitoring

```swift
// Using StreamStats
let streamStats = StreamStats()
streamStats.startStreaming()
streamStats.updateStats(
    videoBitrate: 2500,
    frameRate: 30,
    latency: 50
)
print("Quality status: \(streamStats.qualityStatus.displayName)")
```

### 7. Diagnosis Report

```swift
var report = StreamingDiagnosisReport()
report.calculateOverallScore()

print("Overall score: \(report.overallScore)")
print("Grade: \(report.overallGrade)")
print("Recommendation: \(report.getRecommendation())")
```

## 📝 Changelog

### v1.1.0 (2025-01-26)

#### New Features
- **Sample Project** added (`Sample/SampleApp/`)
  - Library usage example code
  - 20 unit tests

#### Changes (HaishinKit 2.x Compatibility)
- Added `RTMPHaishinKit` module dependency
- Added `@_exported import HaishinKit`, `@_exported import RTMPHaishinKit` for direct type access
- `MediaMixer` initialization API changed: uses `captureSessionMode: .manual`
- `setVideoSettings`, `setAudioSettings` changed to throwing functions
- `isHardwareEncoderEnabled` property removed (enabled by default in HaishinKit 2.x)

#### Migration Guide
When updating from existing projects, check the following:

1. **Type Conflicts**: HaishinKit types like `RTMPStream`, `RTMPConnection`, `MediaMixer` are now directly exposed
2. **HaishinKit Version**: Requires 2.2.4 or higher
3. **Build Errors**: Check for version conflicts if you have existing direct HaishinKit dependencies

### v1.0.0 (2025-01-26)
- Initial release
- RTMP/RTMPS streaming support
- Screen capture streaming
- YouTube Live presets
- Real-time statistics monitoring
- Diagnosis reports

## 🔐 Required Permissions

Add the following to your app's `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for live streaming.</string>
<key>NSCameraUsageDescription</key>
<string>Camera access is required for live streaming.</string>
```

## 📄 License

This project is licensed under the MIT License. HaishinKit is licensed under BSD-3-Clause.

---

<div align="center">

**Made with ❤️ for iOS Live Streaming**

</div>
