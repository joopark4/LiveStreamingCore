# LiveStreamingCore 아키텍처 문서

## 목차
1. [개요](#개요)
2. [프로젝트 구조](#프로젝트-구조)
3. [핵심 매니저 클래스](#핵심-매니저-클래스)
4. [프로토콜](#프로토콜)
5. [데이터 흐름](#데이터-흐름)
6. [타입 및 열거형](#타입-및-열거형)
7. [보안](#보안)

---

## 개요

LiveStreamingCore는 iOS용 RTMP 라이브 스트리밍 프레임워크입니다. HaishinKit을 기반으로 하며, 하드웨어 가속, 성능 최적화, 실시간 모니터링, 진단 기능을 제공합니다.

### 핵심 특징
- VideoToolbox 하드웨어 가속 (H.264 인코딩)
- Metal GPU 가속 이미지 처리
- 실시간 네트워크 품질 모니터링
- 자동 재연결 및 오류 복구
- YouTube Live 최적화 프리셋

---

## 프로젝트 구조

```
Sources/LiveStreamingCore/
├── Models/                         # 데이터 모델
│   ├── StreamStats.swift           # 스트리밍 통계 (@Observable)
│   ├── ConnectionInfo.swift        # 연결 정보
│   ├── TextOverlaySettings.swift   # 텍스트 오버레이 설정
│   └── ScreenCaptureStats.swift    # 화면 캡처 통계
│
├── LiveStreaming/
│   ├── Managers/                   # 핵심 매니저
│   │   ├── HaishinKitManager.swift           # 메인 스트리밍 매니저
│   │   ├── HaishinKitManager+Protocol.swift  # 프로토콜 구현
│   │   ├── HaishinKitManager+ScreenCapture.swift
│   │   ├── HaishinKitManager+MediaMixer.swift
│   │   ├── HaishinKitManager+TextOverlay.swift
│   │   ├── PerformanceOptimizationManager.swift
│   │   ├── StreamingStatsManager.swift
│   │   ├── NetworkMonitoringManager.swift
│   │   └── StreamingLogger.swift
│   │
│   ├── Protocols/                  # 프로토콜 정의
│   │   └── LiveStreamServiceProtocol.swift
│   │
│   ├── Types/                      # 타입 정의
│   │   ├── StreamingModels.swift
│   │   ├── StreamingConstants.swift
│   │   └── StreamingValidation.swift
│   │
│   ├── Utilities/                  # 유틸리티
│   │   ├── ColorSpaceHelper.swift
│   │   └── StatusColorMapping.swift
│   │
│   ├── Factory/                    # 팩토리 패턴
│   │   └── StreamingServiceFactory.swift
│   │
│   └── Alternative/                # 대체 구현
│       └── VideoCodecWorkaroundManager.swift
│
├── LoggingManager.swift            # 로깅 시스템
├── KeychainManager.swift           # 키체인 보안
├── LiveStreamSettings.swift        # SwiftData 모델
├── CameraFrameDelegate.swift       # 카메라 프레임 델리게이트
└── Exports.swift                   # 공개 API
```

---

## 핵심 매니저 클래스

### 1. HaishinKitManager

**위치**: `LiveStreaming/Managers/HaishinKitManager.swift`

RTMP 스트리밍의 핵심 매니저로, HaishinKit을 래핑하여 스트리밍 기능을 제공합니다.

#### 💡 설계 이유

| 결정 | 이유 | 이점 |
|------|------|------|
| HaishinKit 래핑 | 외부 라이브러리 직접 노출 시 API 변경에 취약 | 내부 구현 변경 시 외부 코드 영향 없음 |
| Extension 분리 | 단일 파일 3000줄+ 방지 | 협업 시 충돌 감소, 기능별 파일 탐색 용이 |
| lazy var mixer | 앱 시작 시 불필요한 리소스 할당 방지 | 메모리 효율, 초기화 실패 시점 제어 |
| captureSessionMode: .manual | 화면 캡처는 ReplayKit 사용, 시스템 세션 불필요 | 캡처 타이밍 직접 제어 가능 |

#### 주요 속성

```swift
public class HaishinKitManager: NSObject, HaishinKitManagerProtocol {
    // 상태
    var status: LiveStreamStatus = .idle
    var isStreaming: Bool = false

    // 핵심 컴포넌트
    lazy var mixer = MediaMixer(captureSessionMode: .manual, multiTrackAudioMixingEnabled: false)
    var mediaMixer: MediaMixer?
    var streamSwitcher: StreamSwitcher?

    // 모니터링
    var performanceOptimizer: PerformanceOptimizationManager?
    var networkMonitor: NWPathMonitor?
    var transmissionStats: DataTransmissionStats

    // 설정
    var currentSettings: LiveStreamSettings?
    var textOverlaySettings: TextOverlaySettings?
}
```

#### 주요 메서드

| 메서드 | 설명 |
|--------|------|
| `startScreenCaptureStreaming(with:)` | 화면 캡처 스트리밍 시작 |
| `stopStreaming()` | 스트리밍 중지 |
| `testConnection(to:)` | RTMP 서버 연결 테스트 |
| `loadSettings()` | 저장된 설정 불러오기 |
| `saveSettings(_:)` | 설정 저장 (UserDefaults + Keychain) |
| `getRTMPStream()` | 현재 RTMPStream 인스턴스 반환 |

#### 스트리밍 시작 흐름

```swift
func startScreenCaptureStreaming(with settings: LiveStreamSettings) async throws {
    // 1. 설정 검증
    guard validateSettings(settings) else { throw LiveStreamError.configurationError("...") }

    // 2. MediaMixer 설정
    await setupScreenCaptureMediaMixer()

    // 3. VideoToolbox 설정
    await applyStreamSettings(settings)

    // 4. StreamSwitcher 연결
    let preference = Preference(uri: rtmpURL + "/" + cleanStreamKey)
    streamSwitcher?.setPreference(preference)

    // 5. 스트리밍 시작
    try await streamSwitcher?.startStreaming()

    // 6. 모니터링 시작
    startNetworkMonitoring()
    startDataMonitoring()
}
```

---

### 2. PerformanceOptimizationManager

**위치**: `LiveStreaming/Managers/PerformanceOptimizationManager.swift`

VideoToolbox 하드웨어 가속 및 성능 최적화를 담당합니다.

#### 💡 설계 이유

| 결정 | 이유 | 이점 |
|------|------|------|
| VideoToolbox 사용 | CPU 인코딩 대비 80% 전력 절감, 전용 하드웨어 칩 활용 | 배터리 수명 연장, 발열 감소, 안정적 30fps |
| 소프트웨어 폴백 | 시뮬레이터/구형 기기에서 하드웨어 인코더 미지원 | 모든 환경에서 동작 보장, 개발 테스트 용이 |
| CIContext 캐싱 | 매 프레임마다 생성 시 성능 저하 (30fps = 초당 30회 생성) | 한 번 생성 후 재사용으로 오버헤드 제거 |
| 픽셀 버퍼 풀 | 매번 메모리 할당/해제 시 단편화 발생 | 메모리 재사용으로 GC 압박 감소 |

#### 주요 기능

```swift
public class PerformanceOptimizationManager {
    // GPU/CPU/메모리 사용량 모니터링
    var gpuUsage: Float
    var cpuUsage: Float
    var memoryUsage: Float

    // 압축 세션 관리
    var compressionSession: VTCompressionSession?
    var metalDevice: MTLDevice?
    var ciContext: CIContext?

    // 통계
    var compressionStats: CompressionStatistics
}
```

#### 주요 메서드

| 메서드 | 설명 |
|--------|------|
| `setupCompression(width:height:)` | 압축 세션 초기화 |
| `compressFrame(_:)` | 프레임 압축 |
| `adjustQualityForNetwork(_:)` | 네트워크 상태에 따른 품질 조절 |
| `getPerformanceMetrics()` | 성능 지표 반환 |

#### VideoToolbox 설정

```swift
func setupCompression(width: Int, height: Int) throws {
    var session: VTCompressionSession?

    let status = VTCompressionSessionCreate(
        allocator: kCFAllocatorDefault,
        width: Int32(width),
        height: Int32(height),
        codecType: kCMVideoCodecType_H264,
        encoderSpecification: nil,
        imageBufferAttributes: nil,
        compressedDataAllocator: nil,
        outputCallback: compressionCallback,
        refcon: Unmanaged.passUnretained(self).toOpaque(),
        compressionSessionOut: &session
    )

    guard status == noErr else { throw CompressionError.setupFailed }

    // 하드웨어 인코딩 설정
    VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
    VTSessionSetProperty(session!, key: kVTCompressionPropertyKey_ProfileLevel,
                         value: kVTProfileLevel_H264_High_AutoLevel)
}
```

---

### 3. StreamingStatsManager

**위치**: `LiveStreaming/Managers/StreamingStatsManager.swift`

실시간 스트리밍 통계를 수집하고 관리합니다.

#### 💡 설계 이유

| 결정 | 이유 | 이점 |
|------|------|------|
| 1초 수집 간격 | 0.1초는 과도한 오버헤드, 5초는 실시간 느낌 부족 | 사용자가 "실시간"으로 인식하는 최적 주기 |
| @MainActor UI 업데이트 | 백그라운드에서 UI 수정 시 크래시 위험 | 스레드 안전한 UI 업데이트 보장 |
| [weak self] 캡처 | Timer가 Manager를 강하게 참조 시 메모리 누수 | Manager 해제 시 자동 정리 |
| Protocol 기반 주입 | 테스트 시 실제 HaishinKitManager 필요 | Mock 객체로 단위 테스트 가능 |

#### 주요 기능

```swift
public class StreamingStatsManager: StreamingStatsManagerProtocol {
    // 통계 데이터
    var currentStreamingInfo: StreamingInfo?
    var currentTransmissionStats: DataTransmissionStats?

    // 모니터링
    private var monitoringTimer: Timer?
    private weak var haishinKitManager: HaishinKitManagerProtocol?
}
```

#### 통계 수집 주기

```swift
func startMonitoring() {
    monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
        Task { @MainActor in
            self?.collectStats()
            self?.updateUI()
        }
    }
}

private func collectStats() {
    guard let stream = haishinKitManager?.getRTMPStream() else { return }

    currentTransmissionStats = DataTransmissionStats(
        videoBytesPerSecond: stream.info.currentBytesOutPerSecond,
        networkLatency: calculateLatency(),
        currentVideoBitrate: Double(stream.videoSettings.bitRate) / 1000.0,
        averageFrameRate: stream.info.currentFPS,
        droppedFrames: stream.info.droppedVideoFrames
    )
}
```

---

### 4. NetworkMonitoringManager

**위치**: `LiveStreaming/Managers/NetworkMonitoringManager.swift`

네트워크 상태를 모니터링하고 품질을 평가합니다.

#### 💡 설계 이유

| 결정 | 이유 | 이점 |
|------|------|------|
| NWPathMonitor 사용 | Reachability 대비 최신 API, 더 정확한 상태 감지 | 실시간 네트워크 변경 감지, 연결 타입 구분 |
| 전용 DispatchQueue | 메인 스레드 블로킹 방지 | UI 응답성 유지 |
| 연결 타입별 품질 매핑 | 유선 > WiFi > 셀룰러 순으로 안정성 차이 | 네트워크에 맞는 비트레이트 자동 권장 |
| 적응형 비트레이트 연동 | 네트워크 변동 시 고정 비트레이트는 버퍼 오버플로우 유발 | 끊김 없는 스트리밍 |

#### 주요 기능

```swift
public class NetworkMonitoringManager: NetworkMonitoringManagerProtocol {
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    var currentNetworkQuality: NetworkQuality = .unknown
    var connectionType: NetworkConnectionType = .unknown
}
```

#### 네트워크 품질 평가

```swift
func assessNetworkQuality() async {
    let path = monitor.currentPath

    switch path.status {
    case .satisfied:
        if path.usesInterfaceType(.wifi) {
            currentNetworkQuality = .good
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            currentNetworkQuality = .fair
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            currentNetworkQuality = .excellent
            connectionType = .ethernet
        }
    case .unsatisfied, .requiresConnection:
        currentNetworkQuality = .poor
        connectionType = .unknown
    @unknown default:
        currentNetworkQuality = .unknown
    }
}
```

---

### 5. VideoCodecWorkaroundManager

**위치**: `LiveStreaming/Alternative/VideoCodecWorkaroundManager.swift`

VideoCodec 오류(-12902 등) 발생 시 대체 전략을 제공합니다.

#### 💡 설계 이유

| 결정 | 이유 | 이점 |
|------|------|------|
| 별도 Manager 분리 | 오류 복구 로직이 메인 Manager와 혼재 시 복잡도 증가 | 코드 가독성, 오류 복구 로직 독립적 테스트 |
| 코덱 사전 초기화 | 스트리밍 시작 시 -12902 오류 빈번 발생 | 미리 초기화하여 오류 발생률 대폭 감소 |
| 폴백 설정 제공 | 특정 해상도/비트레이트 조합에서 인코더 실패 가능 | 안전한 기본값으로 자동 전환 |
| @Published 상태 | SwiftUI에서 코덱 상태 실시간 표시 필요 | UI 자동 업데이트 |

#### 주요 기능

```swift
public class VideoCodecWorkaroundManager: ObservableObject {
    @Published var codecStatus: String = ""
    @Published var isVideoCodecPreinitialized: Bool = false

    // 코덱 사전 초기화
    func preinitializeVideoCodec(for stream: RTMPStream, settings: LiveStreamSettings) async throws

    // 폴백 전략
    func applyFallbackSettings(to stream: RTMPStream) async
}
```

---

## 프로토콜

### 💡 프로토콜 기반 설계를 선택한 이유

| 결정 | 이유 | 이점 |
|------|------|------|
| 프로토콜 추상화 | 구현체에 직접 의존 시 테스트/교체 어려움 | Mock 객체로 단위 테스트 가능 |
| AnyObject 제약 | 클래스만 허용하여 참조 의미론 보장 | weak 참조로 순환 참조 방지 가능 |
| async 메서드 | 네트워크/인코딩 작업은 비동기 필수 | 콜백 지옥 없이 깔끔한 비동기 코드 |
| 의존성 주입 | 컴파일 타임에 구현체 결정 불필요 | 테스트/프로덕션 환경별 다른 구현 사용 |

### LiveStreamServiceProtocol

스트리밍 서비스의 기본 인터페이스를 정의합니다.

```swift
public protocol LiveStreamServiceProtocol: AnyObject {
    // 상태
    var status: LiveStreamStatus { get }
    var streamingInfo: StreamingInfo? { get }
    var transmissionStats: DataTransmissionStats? { get }
    var networkQuality: NetworkQuality { get }
    var connectionTestResult: ConnectionTestResult? { get }
    var recommendations: StreamingRecommendations? { get }

    // 연결 테스트
    func testConnection(to settings: LiveStreamSettings) async -> ConnectionTestResult

    // 설정 관리
    func loadSettings() -> LiveStreamSettings?
    func saveSettings(_ settings: LiveStreamSettings)
    func exportSettings() -> Data?
    func importSettings(from data: Data) -> LiveStreamSettings?
}
```

### HaishinKitManagerProtocol

HaishinKitManager의 공개 인터페이스입니다.

```swift
public protocol HaishinKitManagerProtocol: AnyObject {
    // 스트리밍 제어
    func startScreenCaptureStreaming(with settings: LiveStreamSettings) async throws
    func stopStreaming() async

    // 상태 확인
    var isStreaming: Bool { get }
    var currentStatus: LiveStreamStatus { get }
    var transmissionStats: DataTransmissionStats { get }

    // 연결 테스트
    func testConnection(to settings: LiveStreamSettings) async -> ConnectionTestResult

    // 설정 관리
    func loadSettings() -> LiveStreamSettings
    func saveSettings(_ settings: LiveStreamSettings)

    // 스트림 접근
    func getRTMPStream() -> RTMPStream?
}
```

### StreamingStatsManagerProtocol

통계 수집 매니저의 인터페이스입니다.

```swift
public protocol StreamingStatsManagerProtocol: AnyObject {
    var currentStreamingInfo: StreamingInfo? { get }
    var currentTransmissionStats: DataTransmissionStats? { get }

    func setHaishinKitManager(_ manager: HaishinKitManagerProtocol)
    func updateSettings(_ settings: LiveStreamSettings)
    func startMonitoring()
    func stopMonitoring()
}
```

### CameraFrameDelegate

카메라/화면 프레임 처리를 위한 델리게이트입니다.

```swift
public protocol CameraFrameDelegate: AnyObject {
    func didReceiveVideoFrame(_ sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
}
```

---

## 데이터 흐름

### 스트리밍 시작 시퀀스

```
┌─────────────────────────────────────────────────────────────────┐
│                    사용자: 스트리밍 시작 요청                      │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              HaishinKitManager.startScreenCaptureStreaming()     │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
        ┌───────────────────┴───────────────────┐
        ▼                                       ▼
┌───────────────────┐                 ┌───────────────────┐
│  설정 검증         │                 │  MediaMixer 설정   │
│  (validateSettings)│                 │  (setupScreenCapture│
└───────────────────┘                 │   MediaMixer)      │
                                      └───────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│            PerformanceOptimizationManager                        │
│            - VideoToolbox 압축 세션 생성                          │
│            - H.264 하드웨어 인코더 설정                           │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    StreamSwitcher                                │
│            - RTMP URL + Stream Key 설정                          │
│            - 서버 연결 (8초 타임아웃)                              │
│            - 스트림 발행 (6초 타임아웃)                            │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
        ┌───────────────────┴───────────────────┐
        ▼                                       ▼
┌───────────────────┐                 ┌───────────────────┐
│ NetworkMonitoring │                 │ StreamingStats    │
│ Manager 시작      │                 │ Manager 시작      │
└───────────────────┘                 └───────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    스트리밍 상태: .streaming                      │
└─────────────────────────────────────────────────────────────────┘
```

### 실시간 데이터 흐름

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ 화면 캡처   │ ──▶ │ MediaMixer  │ ──▶ │ VideoToolbox│
│ (Screen     │     │ (오디오/    │     │ (H.264      │
│  Capture)   │     │  비디오 믹싱)│     │  인코딩)    │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                                               ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ UI 업데이트 │ ◀── │ Stats       │ ◀── │ RTMPStream  │
│ (Main       │     │ Manager     │     │ .publish()  │
│  Thread)    │     │             │     │             │
└─────────────┘     └─────────────┘     └──────┬──────┘
                                               │
                           ┌───────────────────┘
                           ▼
                    ┌─────────────┐
                    │ RTMP 서버   │
                    │ (YouTube,   │
                    │  Twitch 등) │
                    └─────────────┘
```

### 네트워크 품질 모니터링 흐름

```
┌─────────────────────────────────────────────────────────────────┐
│                    NWPathMonitor                                 │
│                    (네트워크 상태 감지)                           │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│            NetworkMonitoringManager.assessNetworkQuality()       │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ WiFi          │   │ Cellular      │   │ Ethernet      │
│ → Good        │   │ → Fair        │   │ → Excellent   │
└───────────────┘   └───────────────┘   └───────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│            transmissionStats.connectionQuality 업데이트          │
└───────────────────────────┬─────────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│            UI 네트워크 상태 표시 업데이트                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 타입 및 열거형

### 상태 열거형

#### LiveStreamStatus

```swift
public enum LiveStreamStatus: Equatable {
    case idle              // 대기 중
    case connecting        // 연결 시도 중
    case connected         // 연결됨 (스트리밍 전)
    case streaming         // 스트리밍 중
    case disconnecting     // 연결 해제 중
    case error(LiveStreamError)  // 오류 발생
}
```

#### LiveStreamError

```swift
public enum LiveStreamError: Error, LocalizedError, Equatable {
    case initializationFailed(String)   // 초기화 실패
    case deviceNotFound(String)         // 장치 없음
    case networkError(String)           // 네트워크 오류
    case authenticationFailed(String)   // 인증 실패
    case streamingFailed(String)        // 스트리밍 실패
    case configurationError(String)     // 설정 오류
    case permissionDenied(String)       // 권한 거부
    case incompatibleSettings(String)   // 호환되지 않는 설정
    case connectionTimeout              // 연결 타임아웃
    case serverError(Int, String)       // 서버 오류
    case unknown(String)                // 알 수 없는 오류
}
```

### 네트워크 열거형

#### NetworkQuality

```swift
public enum NetworkQuality: CaseIterable, Equatable {
    case excellent  // 우수 (유선, 점수: 1.0, 권장 비트레이트: 4000 kbps)
    case good       // 양호 (WiFi, 점수: 0.8, 권장 비트레이트: 2500 kbps)
    case fair       // 보통 (셀룰러, 점수: 0.6, 권장 비트레이트: 1500 kbps)
    case poor       // 불량 (점수: 0.4, 권장 비트레이트: 800 kbps)
    case unknown    // 알 수 없음 (점수: 0.0, 권장 비트레이트: 1000 kbps)

    var displayName: String { ... }
    var qualityScore: Double { ... }
    var recommendedBitrate: Int { ... }
}
```

#### NetworkConnectionType

```swift
public enum NetworkConnectionType {
    case wifi       // WiFi
    case cellular   // 셀룰러 (LTE/5G)
    case ethernet   // 유선 이더넷
    case unknown    // 알 수 없음
}
```

### 설정 구조체

#### LiveStreamSettings

```swift
public struct LiveStreamSettings: Codable {
    var streamTitle: String              // 스트림 제목
    var rtmpURL: String                  // RTMP URL
    var streamKey: String                // 스트림 키
    var videoBitrate: Int                // 비디오 비트레이트 (kbps)
    var audioBitrate: Int                // 오디오 비트레이트 (kbps)
    var videoWidth: Int                  // 비디오 너비
    var videoHeight: Int                 // 비디오 높이
    var frameRate: Int                   // 프레임 레이트
    var autoReconnect: Bool              // 자동 재연결
    var isEnabled: Bool                  // 활성화 여부
    var videoEncoder: String             // 비디오 인코더 ("H.264")
    var audioEncoder: String             // 오디오 인코더 ("AAC")
    var useHardwareAcceleration: Bool    // 하드웨어 가속 사용
    var h264ProfileLevel: String         // H.264 프로파일 레벨
    var bufferSize: Int                  // 버퍼 크기 (MB)
    var connectionTimeout: Int           // 연결 타임아웃 (초)

    // YouTube Live 프리셋 적용
    mutating func applyYouTubeLivePreset(_ preset: YouTubeLivePreset)

    // 현재 설정과 일치하는 프리셋 감지
    func detectYouTubePreset() -> YouTubeLivePreset?
}
```

#### YouTubeLivePreset

```swift
public enum YouTubeLivePreset: String, CaseIterable, Identifiable {
    case sd480p = "youtube_480p"    // 848×480 @ 30fps, 1500 kbps
    case hd720p = "youtube_720p"    // 1280×720 @ 30fps, 2500 kbps
    case fhd1080p = "youtube_1080p" // 1920×1080 @ 30fps, 4500 kbps
    case custom                     // 사용자 정의

    var settings: (width: Int, height: Int, frameRate: Int,
                   videoBitrate: Int, audioBitrate: Int, keyframeInterval: Int)
    var bitrateRange: (min: Int, max: Int)
    var displayName: String
    var description: String
}
```

### 통계 구조체

#### DataTransmissionStats

```swift
public struct DataTransmissionStats {
    var videoBytesPerSecond: Double        // 초당 비디오 바이트
    var networkLatency: Double             // 네트워크 지연시간 (ms)
    var videoFramesTransmitted: Int        // 전송된 비디오 프레임 수
    var audioFramesTransmitted: Int        // 전송된 오디오 프레임 수
    var totalBytesTransmitted: Int64       // 총 전송 바이트
    var currentVideoBitrate: Double        // 현재 비디오 비트레이트 (kbps)
    var currentAudioBitrate: Double        // 현재 오디오 비트레이트 (kbps)
    var averageFrameRate: Double           // 평균 프레임 레이트
    var droppedFrames: Int                 // 드롭된 프레임 수
    var connectionQuality: NetworkTransmissionQuality
    var lastTransmissionTime: Date         // 마지막 전송 시간
}
```

#### StreamStats (@Observable)

```swift
@Observable
public final class StreamStats {
    // 비트레이트
    private(set) var videoBitrate: Double
    private(set) var audioBitrate: Double

    // 프레임
    private(set) var frameRate: Double
    private(set) var droppedFrames: Int
    private(set) var totalFrames: Int

    // 네트워크
    private(set) var uploadSpeed: Double
    private(set) var latency: Double
    private(set) var packetLoss: Double

    // 품질
    private(set) var encodingQuality: Int
    private(set) var networkStability: Int
    private(set) var overallQuality: Int

    // 상태
    private(set) var startTime: Date?
    private(set) var reconnectCount: Int
    private(set) var totalDataSent: Double
    private(set) var bufferHealth: Double

    // 계산 속성
    var qualityStatus: QualityStatus { ... }
    var duration: TimeInterval { ... }
    var durationString: String { ... }
    var averageBitrate: Double { ... }
    var dataSentString: String { ... }

    func startStreaming()
    func stopStreaming()
    func reset()
    func updateStats(videoBitrate:audioBitrate:frameRate:droppedFrames:uploadSpeed:latency:packetLoss:)
    func incrementReconnectCount()
    func updateDataSent(_ bytes: Int64)
}
```

### 진단 구조체

#### StreamingDiagnosisReport

```swift
public struct StreamingDiagnosisReport {
    var configValidation: ConfigValidationResult
    var mediaMixerStatus: MediaMixerValidationResult
    var rtmpStreamStatus: RTMPStreamValidationResult
    var screenCaptureStatus: ScreenCaptureValidationResult
    var networkStatus: NetworkValidationResult
    var deviceStatus: DeviceValidationResult
    var dataFlowStatus: DataFlowValidationResult

    var overallScore: Int    // 0-100
    var overallGrade: String // A, B, C, D, F

    mutating func calculateOverallScore()
    func getRecommendation() -> String
}
```

---

## 보안

### 💡 보안 설계 이유

| 결정 | 이유 | 이점 |
|------|------|------|
| Keychain 사용 | UserDefaults는 평문 저장, 백업에 포함됨 | Secure Enclave 하드웨어 암호화 |
| kSecAttrAccessibleWhenUnlockedThisDeviceOnly | 기기 잠금 시에도 접근 가능하면 보안 취약 | 잠금 해제 시만 접근, 다른 기기 복원 불가 |
| 마이그레이션 기능 | 기존 UserDefaults 사용자 데이터 보존 필요 | 업데이트 시 자동으로 안전한 저장소로 이동 |
| 데이터 분리 저장 | 모든 데이터를 Keychain에 저장 시 성능 저하 | 민감 정보만 Keychain, 나머지는 UserDefaults |

### KeychainManager

스트림 키와 같은 민감한 정보를 안전하게 저장합니다.

```swift
public class KeychainManager {
    // 스트림 키 저장
    func saveStreamKey(_ key: String) throws

    // 스트림 키 불러오기
    func loadStreamKey() throws -> String?

    // 스트림 키 삭제
    func deleteStreamKey() throws

    // UserDefaults에서 Keychain으로 마이그레이션
    func migrateFromUserDefaults() throws
}
```

### 저장 위치

| 데이터 | 저장 위치 | 이유 |
|--------|----------|------|
| 스트림 키 | Keychain | 민감 정보, 암호화 저장 |
| RTMP URL | UserDefaults | 일반 설정 |
| 비디오 설정 | UserDefaults | 일반 설정 |
| 오디오 설정 | UserDefaults | 일반 설정 |

---

## 참고

- [HaishinKit GitHub](https://github.com/shogo4405/HaishinKit.swift)
- [VideoToolbox 문서](https://developer.apple.com/documentation/videotoolbox)
- [Network Framework](https://developer.apple.com/documentation/network)
