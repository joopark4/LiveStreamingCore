# LiveStreamingCore

<div align="center">

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Version](https://img.shields.io/badge/Version-1.1.0-purple.svg)

**Professional RTMP Live Streaming Framework for iOS**

[한국어](#한국어) | [English](#english)

</div>

---

# 한국어

iOS용 전문 RTMP 라이브 스트리밍 Swift Package입니다. HaishinKit을 기반으로 하드웨어 가속, 성능 최적화, 진단 기능을 제공합니다.

## ✨ 주요 기능

### 🎬 스트리밍
- **RTMP/RTMPS 프로토콜** 지원
- **화면 캡처 스트리밍** - 기기 전체 화면 실시간 스트리밍
- **YouTube Live, Twitch, Facebook** 등 모든 RTMP 호환 플랫폼 지원
- **자동 재연결** - 연결 실패 시 지수 백오프 방식의 자동 재연결

### ⚡ 성능 최적화
- **VideoToolbox 하드웨어 가속** - H.264 하드웨어 인코딩
- **Metal GPU 가속** - GPU 기반 이미지 처리
- **적응형 비트레이트** - 네트워크 상태에 따른 자동 품질 조절
- **하드웨어/소프트웨어 폴백** - 하드웨어 인코딩 실패 시 소프트웨어 인코딩으로 자동 전환

### 📊 모니터링 & 진단
- **실시간 통계** - 비트레이트, FPS, 드롭 프레임, 지연시간 모니터링
- **네트워크 품질 분석** - WiFi/셀룰러 감지, 품질 점수 산출
- **종합 진단 보고서** - A-F 등급 시스템, 권장사항 제공
- **성능 메트릭** - CPU/GPU 사용량, 프레임 처리 시간

### 🔒 보안
- **Keychain 연동** - 스트림 키 안전한 저장
- **기기 잠금 접근 제어** - 민감 정보 보호

### 🎨 추가 기능
- **텍스트 오버레이** - 실시간 텍스트 렌더링
- **다양한 프리셋** - YouTube, Twitch, Facebook 최적화 설정
- **SwiftData 지원** - 설정 영구 저장
- **한국어 완전 지원** - 전체 현지화

## 📋 요구사항

| 요구사항 | 버전 |
|---------|------|
| iOS | 17.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |

## 📦 의존성

| 라이브러리 | 버전 | 설명 |
|-----------|------|------|
| [HaishinKit](https://github.com/shogo4405/HaishinKit.swift) | 2.2.4 | RTMP 스트리밍 코어 라이브러리 |
| [Logboard](https://github.com/shogo4405/Logboard) | 2.6.0 | 구조화된 로깅 유틸리티 |

## 🚀 설치

### Swift Package Manager

`Package.swift` 파일에 다음을 추가하세요:

```swift
dependencies: [
    .package(path: "../Modules/LiveStreamingCore")
    // 또는 원격 저장소:
    // .package(url: "https://github.com/your-repo/LiveStreamingCore.git", from: "1.0.0")
]
```

타겟에 의존성을 추가합니다:

```swift
.target(
    name: "YourApp",
    dependencies: ["LiveStreamingCore"]
)
```

## 📖 사용 방법

### 1. 모듈 임포트

```swift
import LiveStreamingCore
```

### 2. 스트리밍 설정

#### SwiftData 기반 설정 (영구 저장)

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

#### Codable 기반 설정 (임시)

```swift
var settings = LiveStreamSettings()
settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
settings.streamKey = "your-stream-key"
settings.videoBitrate = 2500
settings.videoWidth = 1280
settings.videoHeight = 720
```

### 3. YouTube 프리셋 사용

```swift
var settings = LiveStreamSettings()
settings.applyYouTubeLivePreset(.hd720p)

// 현재 프리셋 감지
if let preset = settings.detectYouTubePreset() {
    print("현재 프리셋: \(preset.displayName)")
}
```

**사용 가능한 프리셋:**

| 프리셋 | 해상도 | FPS | 비트레이트 |
|--------|--------|-----|-----------|
| `.sd480p` | 848×480 | 30 | 1,500 kbps |
| `.hd720p` | 1280×720 | 30 | 2,500 kbps |
| `.fhd1080p` | 1920×1080 | 30 | 4,500 kbps |
| `.custom` | 사용자 정의 | - | - |

### 4. HaishinKitManager 사용

```swift
let manager = HaishinKitManager()

// 스트리밍 시작
Task {
    do {
        try await manager.startScreenCaptureStreaming(with: settings)
    } catch {
        print("스트리밍 시작 실패: \(error)")
    }
}

// 스트리밍 중지
Task {
    await manager.stopStreaming()
}
```

### 5. 연결 테스트

```swift
Task {
    let result = await manager.testConnection(to: settings)
    if result.isSuccessful {
        print("연결 성공! 지연시간: \(result.latency)ms")
    } else {
        print("연결 실패: \(result.message)")
    }
}
```

### 6. 실시간 통계 모니터링

```swift
// 데이터 전송 통계
let stats = manager.transmissionStats
print("비트레이트: \(stats.currentVideoBitrate) kbps")
print("FPS: \(stats.averageFrameRate)")
print("드롭된 프레임: \(stats.droppedFrames)")

// StreamStats 사용
let streamStats = StreamStats()
streamStats.startStreaming()
streamStats.updateStats(
    videoBitrate: 2500,
    frameRate: 30,
    latency: 50
)
print("품질 상태: \(streamStats.qualityStatus.displayName)")
```

### 7. 진단 보고서

```swift
var report = StreamingDiagnosisReport()
report.calculateOverallScore()

print("전체 점수: \(report.overallScore)")
print("등급: \(report.overallGrade)")
print("권장사항: \(report.getRecommendation())")

// 개별 상태 확인
print("설정 유효: \(report.configValidation.isValid)")
print("네트워크 상태: \(report.networkStatus.isValid)")
```

### 8. 텍스트 오버레이

```swift
var overlaySettings = TextOverlaySettings(
    text: "라이브 방송",
    fontSize: 24,
    textColor: .white,
    fontName: "System Bold"
)

let font = overlaySettings.uiFont
let color = overlaySettings.uiColor
```

### 9. 네트워크 모니터링

```swift
let networkManager = NetworkMonitoringManager()
networkManager.startMonitoring()

// 현재 네트워크 품질 확인
let quality = networkManager.currentQuality
print("네트워크 품질: \(quality.displayName)")
print("권장 비트레이트: \(quality.recommendedBitrate) kbps")
```

### 10. 로깅

```swift
let logger = LoggingManager.shared
logger.setLogLevel(.debug)
logger.log("스트리밍 시작", level: .info, category: .streaming)
```

## 📚 주요 타입

### 설정

| 타입 | 설명 |
|------|------|
| `LiveStreamSettingsModel` | SwiftData 기반 영구 저장 설정 |
| `LiveStreamSettings` | Codable 지원 임시 설정 |
| `YouTubeLivePreset` | YouTube 표준 해상도 프리셋 |
| `ResolutionPreset` | 해상도 프리셋 (SD, HD, FHD, 4K) |
| `QualityPreset` | 품질 프리셋 (Low, Medium, High, Ultra) |

### 상태 및 통계

| 타입 | 설명 |
|------|------|
| `StreamStats` | 스트리밍 통계 정보 (@Observable) |
| `ConnectionInfo` | 연결 정보 |
| `DataTransmissionStats` | 데이터 전송 통계 |
| `ScreenCaptureStats` | 화면 캡처 통계 |
| `NetworkQuality` | 네트워크 품질 수준 |

### 상태 열거형

| 타입 | 값 |
|------|-----|
| `LiveStreamStatus` | idle, connecting, connected, streaming, disconnecting, error |
| `ConnectionStatus` | disconnected, connecting, connected, failed |
| `ConnectionQuality` | excellent, good, fair, poor |
| `QualityStatus` | excellent, good, fair, poor, critical |

### 진단

| 타입 | 설명 |
|------|------|
| `StreamingDiagnosisReport` | 종합 진단 보고서 |
| `ConfigValidationResult` | 설정 검증 결과 |
| `NetworkValidationResult` | 네트워크 검증 결과 |
| `MediaMixerValidationResult` | 미디어 믹서 검증 결과 |

## ⚠️ 오류 처리

```swift
do {
    try await manager.startScreenCaptureStreaming(with: settings)
} catch let error as LiveStreamError {
    switch error {
    case .configurationError(let message):
        print("설정 오류: \(message)")
    case .connectionFailed(let message):
        print("연결 실패: \(message)")
    case .streamingFailed(let message):
        print("스트리밍 실패: \(message)")
    case .deviceNotFound(let message):
        print("장치 없음: \(message)")
    case .networkError(let message):
        print("네트워크 오류: \(message)")
    case .authenticationFailed(let message):
        print("인증 실패: \(message)")
    default:
        print("기타 오류: \(error.localizedDescription)")
    }
}
```

## 🔐 필요 권한

앱의 `Info.plist`에 다음을 추가하세요:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>라이브 스트리밍을 위해 마이크 접근이 필요합니다.</string>
<key>NSCameraUsageDescription</key>
<string>라이브 스트리밍을 위해 카메라 접근이 필요합니다.</string>
```

## 🏗️ 아키텍처

```
LiveStreamingCore/
├── Sources/LiveStreamingCore/
│   ├── Models/                    # 데이터 모델
│   │   ├── StreamStats.swift
│   │   ├── ConnectionInfo.swift
│   │   ├── TextOverlaySettings.swift
│   │   └── ScreenCaptureStats.swift
│   │
│   ├── LiveStreaming/
│   │   ├── Managers/              # 핵심 매니저
│   │   │   ├── HaishinKitManager.swift (메인)
│   │   │   ├── PerformanceOptimizationManager.swift
│   │   │   ├── StreamingStatsManager.swift
│   │   │   └── NetworkMonitoringManager.swift
│   │   │
│   │   ├── Protocols/             # 프로토콜
│   │   ├── Types/                 # 타입 정의
│   │   ├── Utilities/             # 유틸리티
│   │   ├── Factory/               # 팩토리
│   │   └── Alternative/           # 대체 구현
│   │
│   ├── LoggingManager.swift       # 로깅 시스템
│   ├── KeychainManager.swift      # 키체인 보안
│   ├── LiveStreamSettings.swift   # SwiftData 모델
│   └── Exports.swift              # 공개 API
│
└── Tests/                         # 테스트
```

## 📝 변경 이력

### v1.1.0 (2025-01-26)

#### 새로운 기능
- **샘플 프로젝트** 추가 (`Sample/SampleApp/`)
  - 라이브러리 사용 예제 코드
  - 20개의 단위 테스트

#### 변경 사항 (HaishinKit 2.x 호환성)
- `RTMPHaishinKit` 모듈 의존성 추가
- `@_exported import HaishinKit`, `@_exported import RTMPHaishinKit` 추가로 타입 직접 접근 가능
- `MediaMixer` 초기화 API 변경: `captureSessionMode: .manual` 사용
- `setVideoSettings`, `setAudioSettings`가 throwing 함수로 변경
- `isHardwareEncoderEnabled` 속성 제거 (HaishinKit 2.x에서 기본 활성화)

#### 마이그레이션 가이드
기존 프로젝트에서 업데이트 시 다음 사항을 확인하세요:

1. **타입 충돌 확인**: `RTMPStream`, `RTMPConnection`, `MediaMixer` 등 HaishinKit 타입이 직접 노출됩니다
2. **HaishinKit 버전**: 2.2.4 이상 필수
3. **빌드 오류 시**: 기존 HaishinKit 직접 의존성이 있다면 버전 충돌 확인

### v1.0.0 (2025-01-26)
- 최초 릴리스
- RTMP/RTMPS 스트리밍 지원
- 화면 캡처 스트리밍
- YouTube Live 프리셋
- 실시간 통계 모니터링
- 진단 보고서

## 📄 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다. HaishinKit은 BSD-3-Clause 라이선스를 따릅니다.

---

# English

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
    // .package(url: "https://github.com/your-repo/LiveStreamingCore.git", from: "1.0.0")
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
// Data transmission stats
let stats = manager.transmissionStats
print("Bitrate: \(stats.currentVideoBitrate) kbps")
print("FPS: \(stats.averageFrameRate)")
print("Dropped frames: \(stats.droppedFrames)")

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

// Check individual status
print("Config valid: \(report.configValidation.isValid)")
print("Network status: \(report.networkStatus.isValid)")
```

### 8. Text Overlay

```swift
var overlaySettings = TextOverlaySettings(
    text: "Live Broadcast",
    fontSize: 24,
    textColor: .white,
    fontName: "System Bold"
)

let font = overlaySettings.uiFont
let color = overlaySettings.uiColor
```

### 9. Network Monitoring

```swift
let networkManager = NetworkMonitoringManager()
networkManager.startMonitoring()

// Check current network quality
let quality = networkManager.currentQuality
print("Network quality: \(quality.displayName)")
print("Recommended bitrate: \(quality.recommendedBitrate) kbps")
```

### 10. Logging

```swift
let logger = LoggingManager.shared
logger.setLogLevel(.debug)
logger.log("Streaming started", level: .info, category: .streaming)
```

## 📚 Key Types

### Settings

| Type | Description |
|------|-------------|
| `LiveStreamSettingsModel` | SwiftData-based persistent settings |
| `LiveStreamSettings` | Codable-supported temporary settings |
| `YouTubeLivePreset` | YouTube standard resolution presets |
| `ResolutionPreset` | Resolution presets (SD, HD, FHD, 4K) |
| `QualityPreset` | Quality presets (Low, Medium, High, Ultra) |

### Status & Statistics

| Type | Description |
|------|-------------|
| `StreamStats` | Streaming statistics (@Observable) |
| `ConnectionInfo` | Connection information |
| `DataTransmissionStats` | Data transmission statistics |
| `ScreenCaptureStats` | Screen capture statistics |
| `NetworkQuality` | Network quality levels |

### Status Enums

| Type | Values |
|------|--------|
| `LiveStreamStatus` | idle, connecting, connected, streaming, disconnecting, error |
| `ConnectionStatus` | disconnected, connecting, connected, failed |
| `ConnectionQuality` | excellent, good, fair, poor |
| `QualityStatus` | excellent, good, fair, poor, critical |

### Diagnostics

| Type | Description |
|------|-------------|
| `StreamingDiagnosisReport` | Comprehensive diagnosis report |
| `ConfigValidationResult` | Configuration validation result |
| `NetworkValidationResult` | Network validation result |
| `MediaMixerValidationResult` | Media mixer validation result |

## ⚠️ Error Handling

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
    case .authenticationFailed(let message):
        print("Authentication failed: \(message)")
    default:
        print("Other error: \(error.localizedDescription)")
    }
}
```

## 🔐 Required Permissions

Add the following to your app's `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for live streaming.</string>
<key>NSCameraUsageDescription</key>
<string>Camera access is required for live streaming.</string>
```

## 🏗️ Architecture

```
LiveStreamingCore/
├── Sources/LiveStreamingCore/
│   ├── Models/                    # Data Models
│   │   ├── StreamStats.swift
│   │   ├── ConnectionInfo.swift
│   │   ├── TextOverlaySettings.swift
│   │   └── ScreenCaptureStats.swift
│   │
│   ├── LiveStreaming/
│   │   ├── Managers/              # Core Managers
│   │   │   ├── HaishinKitManager.swift (Main)
│   │   │   ├── PerformanceOptimizationManager.swift
│   │   │   ├── StreamingStatsManager.swift
│   │   │   └── NetworkMonitoringManager.swift
│   │   │
│   │   ├── Protocols/             # Protocols
│   │   ├── Types/                 # Type Definitions
│   │   ├── Utilities/             # Utilities
│   │   ├── Factory/               # Factories
│   │   └── Alternative/           # Alternative Implementations
│   │
│   ├── LoggingManager.swift       # Logging System
│   ├── KeychainManager.swift      # Keychain Security
│   ├── LiveStreamSettings.swift   # SwiftData Model
│   └── Exports.swift              # Public API
│
└── Tests/                         # Tests
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

## 📄 License

This project is licensed under the MIT License. HaishinKit is licensed under BSD-3-Clause.

---

<div align="center">

**Made with ❤️ for iOS Live Streaming**

</div>
