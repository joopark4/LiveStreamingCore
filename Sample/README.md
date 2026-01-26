# LiveStreamingCore Sample

This folder contains sample code demonstrating how to use the LiveStreamingCore library.

## Sample Usage Code

Below is a complete example of how to use LiveStreamingCore in your iOS app:

```swift
import SwiftUI
import LiveStreamingCore

// MARK: - Sample SwiftUI App

@main
struct LiveStreamingSampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var manager = HaishinKitManager()
    @State private var isStreaming = false
    @State private var settings = LiveStreamingCoreNamespace.LiveStreamSettings()
    @State private var stats = StreamStats()

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Settings Section
                Section("Stream Settings") {
                    TextField("RTMP URL", text: $settings.rtmpURL)
                    SecureField("Stream Key", text: $settings.streamKey)

                    Picker("Preset", selection: $selectedPreset) {
                        ForEach([YouTubeLivePreset.sd480p, .hd720p, .fhd1080p], id: \.self) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                }

                // MARK: Stream Info Section
                Section("Stream Info") {
                    LabeledContent("Resolution", value: "\(settings.videoWidth)x\(settings.videoHeight)")
                    LabeledContent("Frame Rate", value: "\(settings.frameRate) fps")
                    LabeledContent("Video Bitrate", value: "\(settings.videoBitrate) kbps")
                    LabeledContent("Audio Bitrate", value: "\(settings.audioBitrate) kbps")
                }

                // MARK: Statistics Section
                if isStreaming {
                    Section("Live Statistics") {
                        LabeledContent("Current Bitrate", value: "\(Int(stats.currentVideoBitrate)) kbps")
                        LabeledContent("Frame Rate", value: String(format: "%.1f fps", stats.currentFrameRate))
                        LabeledContent("Dropped Frames", value: "\(stats.droppedFrames)")
                        LabeledContent("Latency", value: "\(Int(stats.latency)) ms")
                        LabeledContent("Quality", value: stats.qualityStatus.displayName)
                    }
                }

                // MARK: Controls Section
                Section {
                    Button(isStreaming ? "Stop Streaming" : "Start Streaming") {
                        toggleStreaming()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isStreaming ? .red : .green)
                }
            }
            .navigationTitle("LiveStreamingCore Demo")
        }
    }

    @State private var selectedPreset: YouTubeLivePreset = .hd720p {
        didSet {
            settings.applyYouTubeLivePreset(selectedPreset)
        }
    }

    private func toggleStreaming() {
        Task {
            if isStreaming {
                await manager.stopStreaming()
                isStreaming = false
            } else {
                do {
                    try await manager.startScreenCaptureStreaming(with: settings)
                    isStreaming = true
                    stats.startStreaming()
                } catch {
                    print("Streaming failed: \(error)")
                }
            }
        }
    }
}
```

## Integration Steps

### 1. Add LiveStreamingCore Package

In your Xcode project, go to **File > Add Package Dependencies** and add:

```
path: ../LiveStreamingCore
```

Or if using a remote repository:

```
url: https://github.com/your-repo/LiveStreamingCore.git
```

### 2. Configure Info.plist

Add these required permissions to your app's Info.plist:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for live streaming.</string>
<key>NSCameraUsageDescription</key>
<string>Camera access is required for live streaming.</string>
```

### 3. Import and Use

```swift
import LiveStreamingCore

// Create settings
var settings = LiveStreamingCoreNamespace.LiveStreamSettings()
settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
settings.streamKey = "your-stream-key"
settings.applyYouTubeLivePreset(.hd720p)

// Create manager and start streaming
let manager = HaishinKitManager()
try await manager.startScreenCaptureStreaming(with: settings)
```

## Testing the Library

Run the unit tests to verify the library is working correctly:

```bash
cd /path/to/LiveStreamingCore
swift test
```

## Key Components Demo

### 1. Settings Configuration

```swift
var settings = LiveStreamingCoreNamespace.LiveStreamSettings()
settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
settings.streamKey = "your-stream-key"
settings.videoBitrate = 2500
settings.audioBitrate = 128
settings.videoWidth = 1280
settings.videoHeight = 720
settings.frameRate = 30
```

### 2. YouTube Presets

```swift
var settings = LiveStreamingCoreNamespace.LiveStreamSettings()
settings.applyYouTubeLivePreset(.hd720p)  // 1280x720, 30fps, 2500kbps

// Detect current preset
if let detected = settings.detectYouTubePreset() {
    print("Current preset: \(detected.displayName)")
}
```

### 3. Stream Statistics

```swift
let stats = StreamStats()
stats.startStreaming()

// Access real-time statistics
print("Bitrate: \(stats.currentVideoBitrate) kbps")
print("FPS: \(stats.currentFrameRate)")
print("Quality: \(stats.qualityStatus.displayName)")
```

### 4. Validation

```swift
// Validate RTMP URL
let isValid = StreamingValidation.validateRTMPURL("rtmp://server.com/live")

// Validate bitrate
let bitrateOK = StreamingValidation.validateBitrate(2500)

// Validate resolution
let resolutionOK = StreamingValidation.validateResolution(width: 1920, height: 1080)
```

### 5. Diagnosis Report

```swift
var report = StreamingDiagnosisReport()
report.configValidation.isValid = true
report.networkStatus.isValid = true
report.calculateOverallScore()

print("Score: \(report.overallScore)/100")
print("Grade: \(report.overallGrade)")
print("Recommendation: \(report.getRecommendation())")
```

### 6. Text Overlay

```swift
var overlay = TextOverlaySettings()
overlay.text = "LIVE"
overlay.isEnabled = true
overlay.fontSize = 24.0
overlay.fontName = TextOverlaySettings.FontName.systemBold.rawValue
overlay.textColor = TextOverlaySettings.TextColor.red.rawValue
```

### 7. Connection Info

```swift
var connectionInfo = ConnectionInfo()
connectionInfo.status = .connected
connectionInfo.latency = 45.0
connectionInfo.quality = .good

print("Status: \(connectionInfo.status.displayName)")
print("Quality: \(connectionInfo.quality.displayName)")
```

## Platform Presets

| Platform | Preset | Resolution | FPS | Bitrate |
|----------|--------|------------|-----|---------|
| YouTube | SD 480p | 848×480 | 30 | 1,500 kbps |
| YouTube | HD 720p | 1280×720 | 30 | 2,500 kbps |
| YouTube | FHD 1080p | 1920×1080 | 30 | 4,500 kbps |

## Quality Status Indicators

| Status | Color | Emoji | Description |
|--------|-------|-------|-------------|
| Excellent | Green | 🟢 | Perfect streaming quality |
| Good | Blue | 🔵 | Good streaming quality |
| Fair | Orange | 🟡 | Acceptable but may have issues |
| Poor | Red | 🔴 | Poor quality, action needed |

## Error Handling

```swift
do {
    try await manager.startScreenCaptureStreaming(with: settings)
} catch let error as LiveStreamError {
    switch error {
    case .configurationError(let message):
        print("Configuration error: \(message)")
    case .connectionFailed(let message):
        print("Connection failed: \(message)")
    case .streamingFailed(let message):
        print("Streaming failed: \(message)")
    case .deviceNotFound(let message):
        print("Device not found: \(message)")
    case .networkError(let message):
        print("Network error: \(message)")
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```
