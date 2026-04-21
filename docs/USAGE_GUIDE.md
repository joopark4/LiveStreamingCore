# LiveStreamingCore 사용 가이드

## 목차
1. [빠른 시작](#빠른-시작)
2. [스트리밍 설정](#스트리밍-설정)
3. [스트리밍 시작/중지](#스트리밍-시작중지)
4. [연결 테스트](#연결-테스트)
5. [실시간 모니터링](#실시간-모니터링)
6. [진단 및 문제 해결](#진단-및-문제-해결)
7. [고급 사용법](#고급-사용법)

---

## 빠른 시작

### 1. 모듈 임포트

```swift
import LiveStreamingCore
```

### 2. 기본 스트리밍 예제

```swift
import SwiftUI
import LiveStreamingCore

struct ContentView: View {
    let manager = HaishinKitManager()
    @State private var isStreaming = false

    var body: some View {
        VStack {
            Button(isStreaming ? "스트리밍 중지" : "스트리밍 시작") {
                Task {
                    if isStreaming {
                        await manager.stopStreaming()
                    } else {
                        try? await startStreaming()
                    }
                    isStreaming.toggle()
                }
            }
        }
    }

    func startStreaming() async throws {
        var settings = LiveStreamSettings()
        settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
        settings.streamKey = "your-stream-key"
        settings.applyYouTubeLivePreset(.hd720p)

        try await manager.startScreenCaptureStreaming(with: settings)
    }
}
```

---

## 스트리밍 설정

### 기본 설정

```swift
var settings = LiveStreamSettings()

// 필수 설정
settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
settings.streamKey = "xxxx-xxxx-xxxx-xxxx"

// 비디오 설정
settings.videoWidth = 1280
settings.videoHeight = 720
settings.videoBitrate = 2500  // kbps
settings.frameRate = 30

// 오디오 설정
settings.audioBitrate = 128  // kbps

// 연결 설정
settings.autoReconnect = true
settings.connectionTimeout = 30  // 초
```

### YouTube Live 프리셋 사용

```swift
var settings = LiveStreamSettings()
settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
settings.streamKey = "your-stream-key"

// 프리셋 적용
settings.applyYouTubeLivePreset(.hd720p)  // 1280x720, 30fps, 2500kbps

// 사용 가능한 프리셋
// .sd480p   - 848×480, 30fps, 1500kbps (저사양)
// .hd720p   - 1280×720, 30fps, 2500kbps (권장)
// .fhd1080p - 1920×1080, 30fps, 4500kbps (고화질)
// .custom   - 사용자 정의
```

### 현재 프리셋 감지

```swift
// 현재 설정이 어떤 프리셋에 해당하는지 확인
if let preset = settings.detectYouTubePreset() {
    print("현재 프리셋: \(preset.displayName)")
    print("비트레이트 범위: \(preset.bitrateRange.min)-\(preset.bitrateRange.max) kbps")
} else {
    print("사용자 정의 설정")
}
```

### 설정 저장/불러오기

```swift
let manager = HaishinKitManager()

// 설정 저장 (UserDefaults + Keychain)
manager.saveSettings(settings)

// 설정 불러오기
let loadedSettings = manager.loadSettings()
```

---

## 스트리밍 시작/중지

### 화면 캡처 스트리밍 시작

```swift
let manager = HaishinKitManager()

Task {
    do {
        try await manager.startScreenCaptureStreaming(with: settings)
        print("스트리밍이 시작되었습니다")
    } catch let error as LiveStreamError {
        switch error {
        case .configurationError(let message):
            print("설정 오류: \(message)")
        case .connectionTimeout:
            print("연결 시간 초과")
        case .streamingFailed(let message):
            print("스트리밍 실패: \(message)")
        default:
            print("오류: \(error.localizedDescription)")
        }
    }
}
```

### 스트리밍 중지

```swift
Task {
    await manager.stopStreaming()
    print("스트리밍이 중지되었습니다")
}
```

### 상태 확인

```swift
// 스트리밍 중인지 확인
if manager.isStreaming {
    print("현재 스트리밍 중")
}

// 상태 확인
switch manager.currentStatus {
case .idle:
    print("대기 중")
case .connecting:
    print("연결 중...")
case .connected:
    print("연결됨")
case .streaming:
    print("스트리밍 중")
case .disconnecting:
    print("연결 해제 중...")
case .error(let error):
    print("오류: \(error.localizedDescription)")
}
```

---

## 연결 테스트

스트리밍을 시작하기 전에 RTMP 서버 연결을 테스트할 수 있습니다.

```swift
Task {
    let result = await manager.testConnection(to: settings)

    if result.isSuccessful {
        print("✅ 연결 성공!")
        print("  지연시간: \(result.latency)ms")
        print("  네트워크 품질: \(result.networkQuality.displayName)")
    } else {
        print("❌ 연결 실패")
        print("  사유: \(result.message)")
    }
}
```

---

## 실시간 모니터링

### 전송 통계 모니터링

```swift
// 전송 통계 접근
let stats = manager.transmissionStats

print("비디오 비트레이트: \(stats.currentVideoBitrate) kbps")
print("오디오 비트레이트: \(stats.currentAudioBitrate) kbps")
print("프레임 레이트: \(stats.averageFrameRate) fps")
print("드롭된 프레임: \(stats.droppedFrames)")
print("지연시간: \(stats.networkLatency) ms")
print("네트워크 품질: \(stats.connectionQuality)")
```

### StreamStats 사용 (SwiftUI)

```swift
import SwiftUI
import LiveStreamingCore

struct StatsView: View {
    @State private var stats = StreamStats()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("📊 스트리밍 통계")
                .font(.headline)

            Group {
                Text("비디오: \(Int(stats.videoBitrate)) kbps")
                Text("오디오: \(Int(stats.audioBitrate)) kbps")
                Text("FPS: \(String(format: "%.1f", stats.frameRate))")
                Text("드롭 프레임: \(stats.droppedFrames)")
                Text("지연시간: \(Int(stats.latency)) ms")
            }

            HStack {
                Text("품질:")
                Text(stats.qualityStatus.displayName)
                    .foregroundColor(qualityColor)
            }

            if stats.startTime != nil {
                Text("스트리밍 시간: \(stats.durationString)")
            }
        }
        .padding()
    }

    var qualityColor: Color {
        switch stats.qualityStatus {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }

}
```

### 네트워크 품질 모니터링

```swift
let networkQuality = manager.networkQuality

switch networkQuality {
case .excellent:
    print("🟢 네트워크 우수 - 4000kbps 권장")
case .good:
    print("🔵 네트워크 양호 - 2500kbps 권장")
case .fair:
    print("🟡 네트워크 보통 - 1500kbps 권장")
case .poor:
    print("🔴 네트워크 불량 - 800kbps 권장")
case .unknown:
    print("⚪ 네트워크 상태 확인 중")
}
```

---

## 진단 및 문제 해결

### 진단 보고서 생성

```swift
var report = StreamingDiagnosisReport()

// 점수 계산
report.calculateOverallScore()

print("=== 스트리밍 진단 보고서 ===")
print("전체 점수: \(report.overallScore)/100")
print("등급: \(report.overallGrade)")
print()

// 개별 상태 확인
print("설정 상태: \(report.configValidation.isValid ? "✅" : "❌")")
print("MediaMixer 상태: \(report.mediaMixerStatus.isValid ? "✅" : "❌")")
print("RTMP 스트림 상태: \(report.rtmpStreamStatus.isValid ? "✅" : "❌")")
print("화면 캡처 상태: \(report.screenCaptureStatus.isValid ? "✅" : "❌")")
print("네트워크 상태: \(report.networkStatus.isValid ? "✅" : "❌")")
print("기기 상태: \(report.deviceStatus.isValid ? "✅" : "❌")")
print()

// 권장사항
print("권장사항: \(report.getRecommendation())")
```

### 일반적인 오류 처리

```swift
do {
    try await manager.startScreenCaptureStreaming(with: settings)
} catch let error as LiveStreamError {
    switch error {
    case .configurationError(let message):
        // RTMP URL 또는 스트림 키 확인
        print("⚙️ 설정을 확인하세요: \(message)")

    case .connectionTimeout:
        // 네트워크 연결 확인
        print("⏱️ 연결 시간 초과 - 네트워크를 확인하세요")

    case .authenticationFailed(let message):
        // 스트림 키 확인
        print("🔐 인증 실패: \(message)")
        print("스트림 키가 올바른지 확인하세요")

    case .networkError(let message):
        // 네트워크 연결 확인
        print("🌐 네트워크 오류: \(message)")

    case .streamingFailed(let message):
        // 서버 상태 확인
        print("📡 스트리밍 실패: \(message)")

    case .deviceNotFound(let message):
        // 화면 캡처 권한 확인
        print("📱 장치 오류: \(message)")

    case .permissionDenied(let message):
        // 권한 설정 확인
        print("🚫 권한 거부: \(message)")

    default:
        print("❓ 오류: \(error.localizedDescription)")
    }
}
```

### YouTube Live 연결 진단

```swift
// YouTube Live 전용 진단
Task {
    let diagnosis = await manager.diagnoseYouTubeLiveConnection(settings)

    print("=== YouTube Live 진단 ===")
    print("RTMP URL 유효: \(diagnosis.isURLValid ? "✅" : "❌")")
    print("스트림 키 형식: \(diagnosis.isStreamKeyValid ? "✅" : "❌")")
    print("서버 연결: \(diagnosis.canConnect ? "✅" : "❌")")

    if !diagnosis.issues.isEmpty {
        print("\n발견된 문제:")
        for issue in diagnosis.issues {
            print("  - \(issue)")
        }
    }
}
```

---

## 고급 사용법

### 텍스트 오버레이

```swift
// 텍스트 오버레이 설정
let overlay = TextOverlaySettings(
    text: "🔴 LIVE",
    fontSize: 32.0,
    textColor: .red,
    fontName: "System Bold"
)

// UIKit에서 사용
let label = UILabel()
label.font = overlay.uiFont
label.textColor = overlay.uiColor
label.text = overlay.text
```

### 연결 정보 관리

```swift
let connectionInfo = ConnectionInfo(
    serverAddress: "a.rtmp.youtube.com",
    port: 1935,
    status: .connected
)

// 성능 지표 업데이트
connectionInfo.updatePerformanceMetrics(
    latency: 45.0,
    bandwidth: 5000.0
)

// 연결 품질 확인
print("연결 품질: \(connectionInfo.connectionQuality.displayName)")
print("안정성 점수: \(connectionInfo.stabilityScore)")
print("연결 시간: \(connectionInfo.connectionDurationString)")

// 오류 기록
connectionInfo.recordError("연결 불안정")
```

### 설정 내보내기/가져오기

```swift
// 설정 내보내기 (JSON)
if let data = manager.exportSettings() {
    let jsonString = String(data: data, encoding: .utf8)
    print("설정 JSON: \(jsonString ?? "")")

    // 파일로 저장
    try? data.write(to: URL(fileURLWithPath: "settings.json"))
}

// 설정 가져오기
if let data = try? Data(contentsOf: URL(fileURLWithPath: "settings.json")),
   let imported = manager.importSettings(from: data) {
    print("설정 가져오기 성공")
    manager.saveSettings(imported)
}
```

### 비트레이트 범위 확인

```swift
let preset = YouTubeLivePreset.hd720p
let range = preset.bitrateRange

print("720p 비트레이트 범위: \(range.min)-\(range.max) kbps")

// 비트레이트 유효성 검사
let bitrate = 3000
if bitrate >= range.min && bitrate <= range.max {
    print("비트레이트 \(bitrate)kbps는 720p에 적합합니다")
} else {
    print("비트레이트를 조정하세요")
}
```

---

## 권한 설정

앱의 `Info.plist`에 다음 권한을 추가하세요:

```xml
<!-- 마이크 권한 (오디오 캡처) -->
<key>NSMicrophoneUsageDescription</key>
<string>라이브 스트리밍을 위해 마이크 접근이 필요합니다.</string>

<!-- 카메라 권한 (카메라 스트리밍 시) -->
<key>NSCameraUsageDescription</key>
<string>라이브 스트리밍을 위해 카메라 접근이 필요합니다.</string>
```

화면 캡처의 경우 시스템 설정에서 화면 녹화 권한을 허용해야 합니다.

---

## 모범 사례

### 1. 스트리밍 전 연결 테스트

```swift
// 항상 스트리밍 전에 연결을 테스트하세요
let result = await manager.testConnection(to: settings)
if !result.isSuccessful {
    // 사용자에게 문제를 알림
    showAlert("연결 실패: \(result.message)")
    return
}

// 연결 성공 후 스트리밍 시작
try await manager.startScreenCaptureStreaming(with: settings)
```

### 2. 네트워크 상태에 따른 비트레이트 조절

```swift
let quality = manager.networkQuality

var settings = LiveStreamSettings()
switch quality {
case .excellent:
    settings.applyYouTubeLivePreset(.fhd1080p)
case .good:
    settings.applyYouTubeLivePreset(.hd720p)
case .fair, .poor, .unknown:
    settings.applyYouTubeLivePreset(.sd480p)
}
```

### 3. 오류 복구

```swift
// 자동 재연결 활성화
settings.autoReconnect = true

// 스트리밍 상태 모니터링
if case .error(let error) = manager.currentStatus {
    // 오류 로깅
    print("스트리밍 오류: \(error)")

    // 재시도
    Task {
        try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3초 대기
        try? await manager.startScreenCaptureStreaming(with: settings)
    }
}
```

### 4. 리소스 정리

```swift
// 앱 종료 또는 뷰 해제 시
deinit {
    Task {
        await manager.stopStreaming()
    }
}
```
