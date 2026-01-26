# LiveStreamingCore

<div align="center">

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Version](https://img.shields.io/badge/Version-1.1.0-purple.svg)

**iOS용 전문 RTMP 라이브 스트리밍 프레임워크**

</div>

---

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
    // .package(url: "https://github.com/your-repo/LiveStreamingCore.git", from: "1.1.0")
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

## 🔐 필요 권한

앱의 `Info.plist`에 다음을 추가하세요:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>라이브 스트리밍을 위해 마이크 접근이 필요합니다.</string>
<key>NSCameraUsageDescription</key>
<string>라이브 스트리밍을 위해 카메라 접근이 필요합니다.</string>
```

## 📄 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다. HaishinKit은 BSD-3-Clause 라이선스를 따릅니다.

---

<div align="center">

**Made with ❤️ for iOS Live Streaming**

</div>
