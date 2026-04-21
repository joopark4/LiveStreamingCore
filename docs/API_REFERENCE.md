# LiveStreamingCore API 레퍼런스

## 목차
1. [HaishinKitManager](#haborskitmanager)
2. [StreamStats](#streamstats)
3. [ConnectionInfo](#connectioninfo)
4. [TextOverlaySettings](#textoverlaysettings)
5. [StreamingDiagnosisReport](#streamingdiagnosisreport)
6. [YouTubeLivePreset](#youtubelivepreset)
7. [유틸리티 함수](#유틸리티-함수)

---

## HaishinKitManager

RTMP 스트리밍의 핵심 매니저 클래스입니다.

### 초기화

```swift
let manager = HaishinKitManager()
```

### 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `isStreaming` | `Bool` | 현재 스트리밍 중인지 여부 |
| `currentStatus` | `LiveStreamStatus` | 현재 스트리밍 상태 |
| `transmissionStats` | `DataTransmissionStats` | 데이터 전송 통계 |
| `networkQuality` | `NetworkQuality` | 네트워크 품질 |

### 메서드

#### startScreenCaptureStreaming(with:)

화면 캡처 스트리밍을 시작합니다.

```swift
func startScreenCaptureStreaming(with settings: LiveStreamSettings) async throws
```

**매개변수:**
- `settings`: 스트리밍 설정

**예외:**
- `LiveStreamError.configurationError`: 설정 오류
- `LiveStreamError.connectionTimeout`: 연결 타임아웃
- `LiveStreamError.streamingFailed`: 스트리밍 시작 실패

**예제:**
```swift
let manager = HaishinKitManager()
var settings = LiveStreamSettings()
settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
settings.streamKey = "your-stream-key"
settings.applyYouTubeLivePreset(.hd720p)

Task {
    do {
        try await manager.startScreenCaptureStreaming(with: settings)
        print("스트리밍 시작됨")
    } catch {
        print("오류: \(error)")
    }
}
```

---

#### stopStreaming()

스트리밍을 중지합니다.

```swift
func stopStreaming() async
```

**예제:**
```swift
Task {
    await manager.stopStreaming()
    print("스트리밍 중지됨")
}
```

---

#### testConnection(to:)

RTMP 서버 연결을 테스트합니다.

```swift
func testConnection(to settings: LiveStreamSettings) async -> ConnectionTestResult
```

**매개변수:**
- `settings`: 테스트할 설정

**반환값:**
- `ConnectionTestResult`: 연결 테스트 결과

**예제:**
```swift
Task {
    let result = await manager.testConnection(to: settings)

    if result.isSuccessful {
        print("연결 성공! 지연시간: \(result.latency)ms")
        print("네트워크 품질: \(result.networkQuality.displayName)")
    } else {
        print("연결 실패: \(result.message)")
    }
}
```

---

#### loadSettings()

저장된 설정을 불러옵니다.

```swift
func loadSettings() -> LiveStreamSettings
```

**반환값:**
- `LiveStreamSettings`: 저장된 설정 또는 기본 설정

**예제:**
```swift
let settings = manager.loadSettings()
print("RTMP URL: \(settings.rtmpURL)")
print("비트레이트: \(settings.videoBitrate) kbps")
```

---

#### saveSettings(_:)

설정을 저장합니다.

```swift
func saveSettings(_ settings: LiveStreamSettings)
```

**매개변수:**
- `settings`: 저장할 설정

**예제:**
```swift
var settings = LiveStreamSettings()
settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
settings.streamKey = "your-stream-key"
manager.saveSettings(settings)
```

---

#### getRTMPStream()

현재 RTMPStream 인스턴스를 반환합니다.

```swift
func getRTMPStream() -> RTMPStream?
```

**반환값:**
- `RTMPStream?`: 현재 스트림 인스턴스 또는 nil

---

## StreamStats

스트리밍 통계 정보를 관리하는 Observable 클래스입니다.

### 초기화

```swift
let stats = StreamStats()
```

### 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `videoBitrate` | `Double` | 현재 비디오 비트레이트 (kbps) |
| `audioBitrate` | `Double` | 현재 오디오 비트레이트 (kbps) |
| `frameRate` | `Double` | 현재 프레임 레이트 |
| `droppedFrames` | `Int` | 드롭된 프레임 수 |
| `totalFrames` | `Int` | 총 프레임 수 |
| `latency` | `Double` | 지연시간 (ms) |
| `packetLoss` | `Double` | 패킷 손실률 (%) |
| `uploadSpeed` | `Double` | 업로드 속도 (kbps) |
| `reconnectCount` | `Int` | 재연결 횟수 |
| `startTime` | `Date?` | 스트리밍 시작 시간 |
| `totalDataSent` | `Double` | 총 전송된 데이터 (MB) |
| `bufferHealth` | `Double` | 버퍼 상태 (%) |
| `encodingQuality` | `Int` | 인코딩 품질 점수 (0-100) |
| `networkStability` | `Int` | 네트워크 안정성 점수 (0-100) |
| `overallQuality` | `Int` | 전체 품질 점수 (0-100) |

### 계산 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `duration` | `TimeInterval` | 스트리밍 지속 시간 (초) |
| `durationString` | `String` | 스트리밍 지속 시간 문자열 |
| `averageBitrate` | `Double` | 평균 비트레이트 |
| `dataSentString` | `String` | 데이터 사용량 문자열 |
| `qualityStatus` | `QualityStatus` | 품질 상태 |

### 메서드

#### startStreaming()

스트리밍 시작을 기록합니다.

```swift
func startStreaming()
```

---

#### stopStreaming()

스트리밍 종료를 기록합니다.

```swift
func stopStreaming()
```

---

#### updateStats(...)

통계를 업데이트합니다.

```swift
func updateStats(
    videoBitrate: Double? = nil,
    audioBitrate: Double? = nil,
    frameRate: Double? = nil,
    droppedFrames: Int? = nil,
    uploadSpeed: Double? = nil,
    latency: Double? = nil,
    packetLoss: Double? = nil
)
```

---

#### incrementReconnectCount()

재연결 카운트를 증가시킵니다.

```swift
func incrementReconnectCount()
```

---

#### updateDataSent(_:)

전송 데이터를 업데이트합니다.

```swift
func updateDataSent(_ bytes: Int64)
```

---

#### reset()

통계를 초기화합니다.

```swift
func reset()
```

**예제:**
```swift
let stats = StreamStats()
stats.startStreaming()

// 통계 업데이트
stats.updateStats(
    videoBitrate: 2500.0,
    audioBitrate: 128.0,
    frameRate: 30.0,
    droppedFrames: 2,
    latency: 45.0,
    packetLoss: 0.1
)

print("품질 상태: \(stats.qualityStatus.displayName)")
print("스트리밍 시간: \(stats.duration)초")
print("스트리밍 시간 문자열: \(stats.durationString)")

// 스트리밍 종료
stats.stopStreaming()

// 완전 초기화
stats.reset()
```

---

## ConnectionInfo

연결 정보를 관리하는 Observable 클래스입니다.

### 초기화

```swift
let info = ConnectionInfo(
    serverAddress: "a.rtmp.youtube.com",
    port: 1935,
    status: .connected
)
```

### 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `serverAddress` | `String` | 서버 주소 (읽기 전용) |
| `port` | `Int` | 포트 번호 (읽기 전용) |
| `status` | `ConnectionStatus` | 연결 상태 |
| `connectedAt` | `Date?` | 연결 시작 시간 |
| `lastActivityAt` | `Date?` | 마지막 활동 시간 |
| `ipAddress` | `String?` | IP 주소 |
| `networkType` | `String?` | 네트워크 타입 (Wi-Fi, Cellular 등) |
| `signalStrength` | `Int` | 신호 강도 (0-100) |
| `connectionLatency` | `Double` | 연결 지연시간 (ms) |
| `bandwidth` | `Double` | 대역폭 (kbps) |
| `stabilityScore` | `Int` | 안정성 점수 (0-100) |
| `lastError` | `String?` | 마지막 에러 메시지 |
| `lastErrorAt` | `Date?` | 에러 발생 시간 |
| `totalErrorCount` | `Int` | 총 에러 발생 횟수 |

### 계산 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `connectionDuration` | `TimeInterval` | 연결 지속 시간 |
| `connectionDurationString` | `String` | 연결 지속 시간 문자열 |
| `displayServerAddress` | `String` | 서버 주소 표시용 (주소:포트) |
| `connectionQuality` | `ConnectionQuality` | 연결 품질 |

### 메서드

#### updateStatus(_:)

연결 상태를 업데이트합니다.

```swift
func updateStatus(_ newStatus: ConnectionStatus)
```

---

#### updatePerformanceMetrics(latency:bandwidth:)

성능 지표를 업데이트합니다.

```swift
func updatePerformanceMetrics(latency: Double? = nil, bandwidth: Double? = nil)
```

---

#### recordError(_:)

오류를 기록합니다.

```swift
func recordError(_ error: String)
```

---

#### updateNetworkInfo(ipAddress:networkType:signalStrength:)

네트워크 정보를 업데이트합니다.

```swift
func updateNetworkInfo(
    ipAddress: String? = nil,
    networkType: String? = nil,
    signalStrength: Int? = nil
)
```

---

#### reset()

연결 정보를 초기화합니다.

```swift
func reset()
```

**예제:**
```swift
let info = ConnectionInfo(
    serverAddress: "a.rtmp.youtube.com",
    port: 1935,
    status: .connecting
)

// 연결 성공
info.updateStatus(.connected)
info.updatePerformanceMetrics(latency: 50.0, bandwidth: 5000.0)
info.updateNetworkInfo(ipAddress: "192.168.1.100", networkType: "Wi-Fi", signalStrength: 85)

print("연결 품질: \(info.connectionQuality.displayName)")
print("안정성 점수: \(info.stabilityScore)")
print("서버: \(info.displayServerAddress)")
```

---

## TextOverlaySettings

텍스트 오버레이 설정 구조체입니다.

### 초기화

```swift
let overlay = TextOverlaySettings(
    text: "LIVE",
    fontSize: 24.0,
    textColor: .red,
    fontName: "System Bold"
)
```

### 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `text` | `String` | 표시할 텍스트 |
| `fontSize` | `CGFloat` | 글꼴 크기 |
| `textColor` | `Color` | 텍스트 색상 |
| `fontName` | `String` | 글꼴 이름 |

### 계산 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `uiFont` | `UIFont` | UIKit 글꼴 |
| `uiColor` | `UIColor` | UIKit 색상 |

### 관련 타입

#### AvailableFont

사용 가능한 폰트 열거형입니다.

```swift
public enum AvailableFont: String, CaseIterable {
    case system = "System"
    case systemBold = "System Bold"
    case helvetica = "Helvetica"
    case helveticaBold = "Helvetica Bold"
    case arial = "Arial"
    case arialBold = "Arial Bold"

    var displayName: String { ... }
    var previewFont: Font { ... }
}
```

#### TextOverlayColor

사전 정의된 텍스트 색상 열거형입니다.

```swift
public enum TextOverlayColor: String, CaseIterable {
    case white, black, red, blue, green, yellow, orange, purple

    var color: Color { ... }
    var displayName: String { ... }
}
```

**예제:**
```swift
var overlay = TextOverlaySettings(
    text: "라이브 방송",
    fontSize: 32.0,
    textColor: .white,
    fontName: "System Bold"
)

// UIKit에서 사용
let label = UILabel()
label.font = overlay.uiFont
label.textColor = overlay.uiColor
label.text = overlay.text
```

---

## StreamingDiagnosisReport

스트리밍 진단 보고서 구조체입니다.

### 초기화

```swift
var report = StreamingDiagnosisReport()
```

### 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `configValidation` | `ConfigValidationResult` | 설정 검증 결과 |
| `mediaMixerStatus` | `MediaMixerValidationResult` | MediaMixer 상태 |
| `rtmpStreamStatus` | `RTMPStreamValidationResult` | RTMP 스트림 상태 |
| `screenCaptureStatus` | `ScreenCaptureValidationResult` | 화면 캡처 상태 |
| `networkStatus` | `NetworkValidationResult` | 네트워크 상태 |
| `deviceStatus` | `DeviceValidationResult` | 기기 상태 |
| `overallScore` | `Int` | 전체 점수 (0-100) |
| `overallGrade` | `String` | 전체 등급 (A-F) |

### 메서드

#### calculateOverallScore()

전체 점수를 계산합니다.

```swift
mutating func calculateOverallScore()
```

---

#### getRecommendation()

권장사항을 반환합니다.

```swift
func getRecommendation() -> String
```

**예제:**
```swift
var report = StreamingDiagnosisReport()

// 각 항목 검증 후...
report.calculateOverallScore()

print("전체 점수: \(report.overallScore)")
print("등급: \(report.overallGrade)")
print("권장사항: \(report.getRecommendation())")

// 개별 상태 확인
if !report.networkStatus.isValid {
    print("네트워크 문제: \(report.networkStatus.message)")
}
```

---

## YouTubeLivePreset

YouTube Live 표준 프리셋 열거형입니다.

### 값

| 값 | 해상도 | FPS | 비트레이트 |
|----|--------|-----|-----------|
| `.sd480p` | 848×480 | 30 | 1,500 kbps |
| `.hd720p` | 1280×720 | 30 | 2,500 kbps |
| `.fhd1080p` | 1920×1080 | 30 | 4,500 kbps |
| `.custom` | 사용자 정의 | - | - |

### 속성

| 속성 | 타입 | 설명 |
|------|------|------|
| `displayName` | `String` | 표시 이름 |
| `description` | `String` | 설명 |
| `icon` | `String` | SF Symbol 아이콘 |
| `settings` | `Tuple` | 세부 설정값 |
| `bitrateRange` | `(min, max)` | 권장 비트레이트 범위 |

**예제:**
```swift
// 프리셋 적용
var settings = LiveStreamSettings()
settings.applyYouTubeLivePreset(.hd720p)

print("해상도: \(settings.videoWidth)x\(settings.videoHeight)")
print("비트레이트: \(settings.videoBitrate) kbps")

// 모든 프리셋 나열
for preset in YouTubeLivePreset.allCases {
    let s = preset.settings
    print("\(preset.displayName): \(s.width)x\(s.height) @ \(s.videoBitrate) kbps")
}

// 현재 설정과 일치하는 프리셋 감지
if let detected = settings.detectYouTubePreset() {
    print("현재 프리셋: \(detected.displayName)")
}
```

---

## 유틸리티 함수

### 설정 검증

```swift
// URL 검증
let isValidURL = ValidationExample.validateURL("rtmp://a.rtmp.youtube.com/live2")

// 비트레이트 검증
let isValidBitrate = ValidationExample.validateBitrate(2500, for: .hd720p)

// 해상도 검증
let isValidResolution = ValidationExample.validateResolution(1280, height: 720)

// 프레임 레이트 검증
let isValidFrameRate = ValidationExample.validateFrameRate(30)
```

### 전체 설정 검증

```swift
var settings = LiveStreamSettings()
settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
settings.streamKey = "your-stream-key"
settings.videoBitrate = 2500

let issues = ValidationExample.validateSettings(settings)

if issues.isEmpty {
    print("설정이 유효합니다")
} else {
    for issue in issues {
        print("문제: \(issue)")
    }
}
```

---

## 열거형 참조

### LiveStreamStatus

```swift
public enum LiveStreamStatus: Equatable {
    case idle              // 대기
    case connecting        // 연결 중
    case connected         // 연결됨
    case streaming         // 스트리밍 중
    case disconnecting     // 연결 해제 중
    case error(LiveStreamError)

    var iconName: String { ... }
    var color: String { ... }
    var description: String { ... }
    var isError: Bool { ... }
    var displayText: String { ... }
    var isActive: Bool { ... }
}
```

### ConnectionStatus

```swift
public enum ConnectionStatus: String, CaseIterable {
    case disconnected = "disconnected"
    case connecting = "connecting"
    case connected = "connected"
    case reconnecting = "reconnecting"
    case failed = "failed"

    var displayName: String { ... }
    var emoji: String { ... }
    var isConnected: Bool { ... }
    var isConnecting: Bool { ... }
}
```

### ConnectionQuality

```swift
public enum ConnectionQuality: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"

    var displayName: String { ... }
    var color: String { ... }
    var emoji: String { ... }
}
```

### QualityStatus

```swift
public enum QualityStatus: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"

    var displayName: String { ... }
    var color: String { ... }
    var emoji: String { ... }
}
```

### NetworkQuality

```swift
public enum NetworkQuality: CaseIterable, Equatable {
    case excellent
    case good
    case fair
    case poor
    case unknown

    var displayName: String { ... }
    var qualityScore: Double { ... }
    var recommendedBitrate: Int { ... }
    var color: String { ... }
}
```
