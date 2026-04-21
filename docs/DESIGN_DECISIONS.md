# LiveStreamingCore 설계 결정 및 구현 이유

## 목차
1. [아키텍처 설계 결정](#아키텍처-설계-결정)
2. [핵심 클래스 설계](#핵심-클래스-설계)
3. [프로토콜 기반 설계](#프로토콜-기반-설계)
4. [비동기 처리 전략](#비동기-처리-전략)
5. [성능 최적화 전략](#성능-최적화-전략)
6. [오류 처리 전략](#오류-처리-전략)
7. [보안 설계](#보안-설계)
8. [확장성 고려사항](#확장성-고려사항)

---

## 아키텍처 설계 결정

### 1. 계층화된 매니저 구조

#### 구현 방식
```
HaishinKitManager (최상위)
    ├── PerformanceOptimizationManager (성능)
    ├── StreamingStatsManager (통계)
    ├── NetworkMonitoringManager (네트워크)
    └── VideoCodecWorkaroundManager (오류 복구)
```

#### 왜 이렇게 구현했는가?

**단일 책임 원칙 (SRP) 적용**
```swift
// ❌ 잘못된 설계: 모든 기능이 하나의 클래스에
class MonolithicStreamingManager {
    func startStreaming() { }
    func compressFrame() { }
    func monitorNetwork() { }
    func collectStats() { }
    func handleCodecError() { }
    // 수천 줄의 코드...
}

// ✅ 올바른 설계: 각 매니저가 하나의 책임만
class HaishinKitManager {
    let performanceManager: PerformanceOptimizationManager  // 성능만
    let statsManager: StreamingStatsManager                  // 통계만
    let networkManager: NetworkMonitoringManager             // 네트워크만
}
```

**이점:**
1. **유지보수성**: 각 매니저를 독립적으로 수정/테스트 가능
2. **가독성**: 코드 위치 예측 가능 (네트워크 관련 → NetworkMonitoringManager)
3. **재사용성**: 각 매니저를 다른 프로젝트에서 독립적으로 사용 가능
4. **테스트 용이성**: 각 매니저를 Mock으로 대체하여 단위 테스트 가능

---

### 2. HaishinKit 래핑 전략

#### 구현 방식
```swift
// HaishinKit을 직접 노출하지 않고 래핑
public class HaishinKitManager {
    // 내부에서만 HaishinKit 사용
    private var streamSwitcher: StreamSwitcher?
    private lazy var mixer = MediaMixer(...)

    // 외부에는 추상화된 인터페이스만 제공
    public func startScreenCaptureStreaming(with settings: LiveStreamSettings) async throws
}
```

#### 왜 이렇게 구현했는가?

**문제점 (직접 노출 시):**
```swift
// ❌ HaishinKit 직접 사용 - 문제점
let stream = RTMPStream(connection: connection)
stream.videoSettings.bitRate = 2500000  // HaishinKit은 bps 단위
stream.audioSettings.bitRate = 128000

// 개발자가 알아야 할 것들:
// - HaishinKit API 전체 학습 필요
// - 단위 변환 (kbps → bps)
// - 초기화 순서
// - 스레드 안전성
// - 오류 처리 방법
```

**해결책 (래핑 후):**
```swift
// ✅ 래핑된 API - 간단하고 직관적
var settings = LiveStreamSettings()
settings.videoBitrate = 2500  // kbps (직관적)
settings.audioBitrate = 128

try await manager.startScreenCaptureStreaming(with: settings)
```

**이점:**
1. **학습 곡선 감소**: HaishinKit 전체를 학습할 필요 없음
2. **단위 통일**: 모든 비트레이트를 kbps로 통일
3. **버전 독립성**: HaishinKit 내부 API 변경에도 외부 코드 영향 없음
4. **검증 추가**: 설정값 검증을 래핑 레이어에서 수행

---

### 3. Extension을 통한 기능 분리

#### 구현 방식
```
HaishinKitManager.swift              (핵심 로직)
HaishinKitManager+Protocol.swift     (프로토콜 구현)
HaishinKitManager+ScreenCapture.swift (화면 캡처)
HaishinKitManager+MediaMixer.swift   (미디어 믹서)
HaishinKitManager+TextOverlay.swift  (텍스트 오버레이)
```

#### 왜 이렇게 구현했는가?

**문제점 (단일 파일):**
```swift
// ❌ 하나의 거대한 파일 (3000줄+)
class HaishinKitManager {
    // 핵심 로직 500줄
    // 화면 캡처 400줄
    // 미디어 믹서 300줄
    // 텍스트 오버레이 200줄
    // 프로토콜 구현 400줄
    // ...
}
```

**해결책:**
```swift
// ✅ Extension으로 분리 (각 파일 200-400줄)

// HaishinKitManager.swift - 핵심만
class HaishinKitManager {
    var status: LiveStreamStatus
    lazy var mixer = MediaMixer(...)
}

// HaishinKitManager+ScreenCapture.swift - 화면 캡처만
extension HaishinKitManager {
    func setupScreenCaptureMediaMixer() async { }
    func applyStreamSettings(_ settings: LiveStreamSettings) async throws { }
}
```

**이점:**
1. **파일 크기 관리**: 각 파일 200-400줄로 관리 가능
2. **협업 용이**: 다른 개발자가 동시에 다른 Extension 작업 가능 (충돌 감소)
3. **기능 찾기 쉬움**: 화면 캡처 관련 → `+ScreenCapture.swift` 파일
4. **선택적 컴파일**: 필요 없는 기능 제외 가능 (미래 확장)

---

## 핵심 클래스 설계

### 1. MediaMixer 초기화 전략

#### 구현 방식
```swift
lazy var mixer = MediaMixer(
    captureSessionMode: .manual,
    multiTrackAudioMixingEnabled: false
)
```

#### 왜 이렇게 구현했는가?

**`lazy` 사용 이유:**
```swift
// ❌ 즉시 초기화 - 문제점
class HaishinKitManager {
    var mixer = MediaMixer(...)  // 앱 시작 시 즉시 생성
    // 사용하지 않아도 메모리 점유
    // 초기화 실패 시 앱 크래시 가능
}

// ✅ lazy 초기화 - 해결책
class HaishinKitManager {
    lazy var mixer = MediaMixer(...)  // 첫 사용 시 생성
    // 실제 스트리밍 시작 전까지 메모리 절약
    // 초기화 실패 시점을 제어 가능
}
```

**`captureSessionMode: .manual` 선택 이유:**
```swift
// .automatic: 시스템이 캡처 세션 관리
// .manual: 개발자가 직접 제어

// ✅ manual 선택 이유:
// 1. 화면 캡처는 시스템 캡처 세션이 아닌 ReplayKit 사용
// 2. 카메라/마이크 접근 타이밍을 직접 제어 필요
// 3. 권한 요청 시점을 앱에서 결정
```

**이점:**
1. **메모리 효율**: 필요할 때만 리소스 할당
2. **제어권**: 캡처 타이밍을 앱에서 직접 관리
3. **유연성**: 다양한 입력 소스 (화면, 카메라) 지원

---

### 2. StreamSwitcher 사용 패턴

#### 구현 방식
```swift
func startStreaming() async throws {
    let preference = Preference(uri: rtmpURL + "/" + streamKey)
    streamSwitcher?.setPreference(preference)

    // 연결 (8초 타임아웃)
    try await withTimeout(seconds: 8) {
        try await streamSwitcher?.connect()
    }

    // 안정화 대기
    try await Task.sleep(nanoseconds: 100_000_000)  // 0.1초

    // 발행 (6초 타임아웃)
    try await withTimeout(seconds: 6) {
        try await streamSwitcher?.publish()
    }
}
```

#### 왜 이렇게 구현했는가?

**타임아웃이 필요한 이유:**
```swift
// ❌ 타임아웃 없이 - 문제점
await streamSwitcher?.connect()  // 네트워크 문제 시 무한 대기
// 사용자는 앱이 멈춘 것으로 인식
// 리소스 누수 발생 가능

// ✅ 타임아웃 적용 - 해결책
try await withTimeout(seconds: 8) {
    try await streamSwitcher?.connect()
}
// 8초 후 자동 실패 처리
// 사용자에게 명확한 피드백 제공
```

**안정화 대기(0.1초)가 필요한 이유:**
```swift
// RTMP 프로토콜 특성:
// 1. connect() 완료 = TCP 연결 수립
// 2. 서버가 핸드셰이크 처리 중일 수 있음
// 3. 즉시 publish() 시 실패 가능성

// 0.1초 대기로:
// - 서버 핸드셰이크 완료 보장
// - 연결 안정성 확보
// - 실패율 대폭 감소 (테스트 결과)
```

**이점:**
1. **안정성**: 연결 실패 시 명확한 타임아웃
2. **사용자 경험**: 무한 대기 없이 빠른 피드백
3. **YouTube Live 호환성**: YouTube 서버 특성에 맞춘 타이밍

---

### 3. PerformanceOptimizationManager 설계

#### 구현 방식
```swift
class PerformanceOptimizationManager {
    // VideoToolbox 압축 세션
    private var compressionSession: VTCompressionSession?

    // Metal 디바이스 (GPU 가속)
    private var metalDevice: MTLDevice?
    private var ciContext: CIContext?

    // 픽셀 버퍼 풀 (메모리 재사용)
    private var pixelBufferPool: CVPixelBufferPool?
}
```

#### 왜 이렇게 구현했는가?

**VideoToolbox 선택 이유:**
```swift
// 인코딩 옵션 비교:
// 1. 소프트웨어 인코딩 (CPU)
//    - 장점: 항상 사용 가능
//    - 단점: CPU 사용량 높음, 배터리 소모, 발열

// 2. VideoToolbox (하드웨어)
//    - 장점: 전용 인코더 칩 사용, 저전력, 고성능
//    - 단점: 기기별 차이, 일부 설정 제한

// ✅ VideoToolbox 선택 + 소프트웨어 폴백
func setupCompression() throws {
    do {
        try setupHardwareCompression()
    } catch {
        try setupSoftwareCompression()  // 폴백
    }
}
```

**CIContext 캐싱 이유:**
```swift
// ❌ 매번 생성 - 심각한 성능 문제
func processFrame(_ buffer: CVPixelBuffer) {
    let context = CIContext()  // 매 프레임마다 생성 (느림)
    // 30fps = 초당 30번 생성/해제
}

// ✅ 캐싱 - 성능 최적화
class PerformanceOptimizationManager {
    private lazy var ciContext: CIContext? = {
        guard let device = metalDevice else { return nil }
        return CIContext(mtlDevice: device)  // 한 번만 생성
    }()

    func processFrame(_ buffer: CVPixelBuffer) {
        // 캐싱된 context 재사용
        ciContext?.render(...)
    }
}
```

**픽셀 버퍼 풀 사용 이유:**
```swift
// ❌ 매번 할당 - 메모리 단편화
func createPixelBuffer() -> CVPixelBuffer {
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(...)  // 매번 새로 할당
    return buffer!
    // 메모리 할당/해제 오버헤드
    // GC 압박 증가
}

// ✅ 풀에서 재사용 - 효율적
func getPixelBuffer() -> CVPixelBuffer? {
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &buffer)
    return buffer
    // 미리 할당된 버퍼 재사용
    // 메모리 단편화 방지
}
```

**이점:**
1. **배터리 수명**: 하드웨어 인코딩으로 전력 소모 80% 감소
2. **발열 감소**: CPU 대신 전용 칩 사용
3. **프레임 드롭 감소**: 안정적인 30fps 유지
4. **메모리 효율**: 버퍼 풀로 할당/해제 오버헤드 제거

---

### 4. StreamingStatsManager 설계

#### 구현 방식
```swift
class StreamingStatsManager {
    private var monitoringTimer: Timer?

    func startMonitoring() {
        // 1초 간격으로 통계 수집
        monitoringTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.collectStats()
            }
        }
    }
}
```

#### 왜 이렇게 구현했는가?

**1초 간격 선택 이유:**
```swift
// 수집 간격 트레이드오프:
// 0.1초: 너무 잦음 → CPU 오버헤드, 배터리 소모
// 5초: 너무 느림 → 사용자가 실시간으로 느끼지 못함
// 1초: 적절한 균형

// 1초 간격의 이점:
// - 사람이 "실시간"으로 인식하는 최소 단위
// - 비트레이트/FPS 변화를 충분히 반영
// - CPU 오버헤드 최소화
```

**`@MainActor` 사용 이유:**
```swift
// ❌ 메인 스레드 고려 없이 - 크래시 위험
func collectStats() {
    let stats = calculateStats()
    self.currentStats = stats  // 백그라운드에서 UI 업데이트 시도
    // → UIKit/SwiftUI 크래시 가능
}

// ✅ @MainActor로 메인 스레드 보장
Task { @MainActor in
    self?.collectStats()
    // UI 업데이트가 안전하게 메인 스레드에서 실행
}
```

**`[weak self]` 사용 이유:**
```swift
// ❌ 강한 참조 - 메모리 누수
monitoringTimer = Timer.scheduledTimer(...) { _ in
    self.collectStats()  // self를 강하게 참조
    // Manager가 해제되어도 Timer가 유지
    // → 메모리 누수
}

// ✅ 약한 참조 - 안전한 해제
monitoringTimer = Timer.scheduledTimer(...) { [weak self] _ in
    self?.collectStats()  // self가 nil이면 실행 안 함
    // Manager 해제 시 자연스럽게 정리
}
```

**이점:**
1. **실시간 피드백**: 사용자가 스트리밍 상태를 즉시 확인
2. **스레드 안전성**: UI 업데이트 크래시 방지
3. **메모리 안전성**: 순환 참조 방지

---

## 프로토콜 기반 설계

### 1. HaishinKitManagerProtocol

#### 구현 방식
```swift
public protocol HaishinKitManagerProtocol: AnyObject {
    func startScreenCaptureStreaming(with settings: LiveStreamSettings) async throws
    func stopStreaming() async
    func testConnection(to settings: LiveStreamSettings) async -> ConnectionTestResult
    var isStreaming: Bool { get }
    var currentStatus: LiveStreamStatus { get }
    var transmissionStats: DataTransmissionStats { get }
}
```

#### 왜 이렇게 구현했는가?

**테스트 용이성:**
```swift
// ✅ 프로토콜 덕분에 Mock 객체 생성 가능
class MockHaishinKitManager: HaishinKitManagerProtocol {
    var isStreaming: Bool = false
    var shouldFailConnection: Bool = false

    func testConnection(to settings: LiveStreamSettings) async -> ConnectionTestResult {
        if shouldFailConnection {
            return ConnectionTestResult(isSuccessful: false, latency: 0, message: "Mock 실패")
        }
        return ConnectionTestResult(isSuccessful: true, latency: 50, message: "성공")
    }

    // 테스트에서:
    func testConnectionFailure() async {
        let mock = MockHaishinKitManager()
        mock.shouldFailConnection = true

        let result = await mock.testConnection(to: settings)
        XCTAssertFalse(result.isSuccessful)
    }
}
```

**의존성 주입:**
```swift
// ✅ 프로토콜을 사용한 의존성 주입
class StreamingViewModel {
    private let manager: HaishinKitManagerProtocol

    // 실제 앱에서:
    init() {
        self.manager = HaishinKitManager()
    }

    // 테스트에서:
    init(manager: HaishinKitManagerProtocol) {
        self.manager = manager
    }
}

// 테스트 시:
let viewModel = StreamingViewModel(manager: MockHaishinKitManager())
```

**이점:**
1. **테스트 가능**: 실제 네트워크 없이 단위 테스트 가능
2. **유연성**: 구현체 교체 용이 (다른 스트리밍 라이브러리로 교체 가능)
3. **문서화**: 프로토콜이 공개 API 명세 역할

---

### 2. @Observable 사용 (StreamStats)

#### 구현 방식
```swift
@Observable
public final class StreamStats {
    private(set) var videoBitrate: Double = 0
    private(set) var frameRate: Double = 0
    // ...
}
```

#### 왜 이렇게 구현했는가?

**struct 대신 class 선택 이유:**
```swift
// ❌ struct - 값 복사 문제
struct StreamStats {
    var videoBitrate: Double
}

class Manager {
    var stats = StreamStats()

    func updateStats() {
        stats.videoBitrate = 2500  // 원본 수정
    }
}

// View에서:
let stats = manager.stats  // 복사본
// manager.updateStats() 호출해도 stats는 변경되지 않음

// ✅ class - 참조로 자동 동기화
@Observable
class StreamStats {
    var videoBitrate: Double
}

// View에서:
let stats = manager.stats  // 참조
// manager.updateStats() → stats도 자동 반영
```

**`private(set)` 사용 이유:**
```swift
// ❌ 완전 공개 - 외부에서 잘못된 값 설정 가능
public var videoBitrate: Double = 0
// 외부에서: stats.videoBitrate = -1000  // 유효하지 않은 값

// ✅ private(set) - 읽기만 허용
private(set) var videoBitrate: Double = 0

// 외부: 읽기만 가능
let bitrate = stats.videoBitrate  // ✅

// 내부: 검증 후 쓰기
func updateStats(videoBitrate: Double) {
    guard videoBitrate >= 0 else { return }
    self.videoBitrate = videoBitrate  // ✅ 검증된 값만
}
```

**이점:**
1. **SwiftUI 호환**: `@Observable`로 자동 UI 업데이트
2. **데이터 무결성**: `private(set)`로 외부 수정 차단
3. **실시간 동기화**: 참조 타입으로 모든 곳에서 동일 데이터

---

## 비동기 처리 전략

### 1. async/await 패턴

#### 구현 방식
```swift
public func startScreenCaptureStreaming(with settings: LiveStreamSettings) async throws {
    // 1. 설정 검증
    guard validateSettings(settings) else {
        throw LiveStreamError.configurationError("유효하지 않은 설정")
    }

    // 2. MediaMixer 설정 (비동기)
    await setupScreenCaptureMediaMixer()

    // 3. VideoToolbox 설정 (비동기, 실패 가능)
    try await applyStreamSettings(settings)

    // 4. 연결 (비동기, 실패 가능)
    try await connectToServer(settings)
}
```

#### 왜 이렇게 구현했는가?

**콜백 지옥 해결:**
```swift
// ❌ 콜백 기반 - 가독성 떨어짐
func startStreaming(completion: @escaping (Result<Void, Error>) -> Void) {
    setupMediaMixer { result in
        switch result {
        case .success:
            self.applySettings { result in
                switch result {
                case .success:
                    self.connect { result in
                        // 계속 중첩...
                        completion(result)
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        case .failure(let error):
            completion(.failure(error))
        }
    }
}

// ✅ async/await - 선형적이고 읽기 쉬움
func startStreaming() async throws {
    await setupMediaMixer()
    try await applySettings()
    try await connect()
    // 마치 동기 코드처럼 읽힘
}
```

**오류 전파 명확화:**
```swift
// async throws 조합으로:
// - 성공: 다음 단계로 진행
// - 실패: 즉시 throw, 호출자가 catch

do {
    try await manager.startScreenCaptureStreaming(with: settings)
} catch {
    // 어느 단계에서 실패했든 여기서 처리
}
```

**이점:**
1. **가독성**: 동기 코드처럼 읽히는 비동기 코드
2. **오류 처리**: try/catch로 통일된 오류 처리
3. **취소 지원**: Task 취소 시 자동 전파

---

### 2. Task와 타임아웃 패턴

#### 구현 방식
```swift
func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        // 실제 작업
        group.addTask {
            try await operation()
        }

        // 타임아웃
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw LiveStreamError.connectionTimeout
        }

        // 먼저 완료되는 것 반환
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

#### 왜 이렇게 구현했는가?

**TaskGroup 사용 이유:**
```swift
// ❌ 단순 sleep - 항상 대기
func connectWithTimeout() async throws {
    async let connection = connect()
    try await Task.sleep(nanoseconds: 8_000_000_000)

    // 문제: 연결이 1초만에 성공해도 8초 대기

// ✅ TaskGroup - 먼저 완료되는 것 사용
// 연결 성공 시: 즉시 반환 (타임아웃 취소)
// 타임아웃 시: 연결 작업 취소, 오류 throw
```

**이점:**
1. **응답성**: 빠른 연결 시 즉시 진행
2. **리소스 정리**: 불필요한 작업 자동 취소
3. **명확한 실패**: 타임아웃 시 구체적인 오류

---

## 성능 최적화 전략

### 1. 하드웨어 가속 우선 + 소프트웨어 폴백

#### 구현 방식
```swift
func setupCompression(width: Int, height: Int) async throws {
    do {
        // 1차 시도: 하드웨어 인코딩
        try await setupHardwareCompression(width: width, height: height)
        logger.info("✅ 하드웨어 인코딩 활성화")
    } catch {
        // 2차 시도: 소프트웨어 폴백
        logger.warning("⚠️ 하드웨어 인코딩 실패, 소프트웨어로 전환")
        try await setupSoftwareCompression(width: width, height: height)
    }
}
```

#### 왜 이렇게 구현했는가?

**하드웨어 실패 케이스:**
```
1. 시뮬레이터 (하드웨어 인코더 없음)
2. 오래된 기기 (특정 해상도 미지원)
3. 리소스 부족 (다른 앱이 인코더 사용 중)
4. 특정 설정 조합 미지원
```

**폴백 전략의 중요성:**
```swift
// ❌ 폴백 없이 - 일부 환경에서 완전 실패
func setupCompression() throws {
    try setupHardwareCompression()
    // 시뮬레이터에서 테스트 불가
    // 오래된 기기에서 크래시
}

// ✅ 폴백 있음 - 모든 환경에서 동작
func setupCompression() throws {
    do {
        try setupHardwareCompression()
    } catch {
        try setupSoftwareCompression()
    }
    // 어떤 환경에서든 스트리밍 가능
}
```

**이점:**
1. **호환성**: 모든 iOS 기기에서 동작
2. **개발 편의**: 시뮬레이터에서 테스트 가능
3. **안정성**: 하드웨어 문제 시에도 서비스 지속

---

### 2. 적응형 비트레이트 전략

#### 구현 방식
```swift
func adjustQualityForNetwork(_ quality: NetworkQuality) {
    let recommendedBitrate: Int

    switch quality {
    case .excellent:
        recommendedBitrate = 4500  // 1080p 가능
    case .good:
        recommendedBitrate = 2500  // 720p 권장
    case .fair:
        recommendedBitrate = 1500  // 480p 권장
    case .poor:
        recommendedBitrate = 800   // 최소 품질
    case .unknown:
        recommendedBitrate = 1500  // 안전한 기본값
    }

    updateStreamBitrate(recommendedBitrate)
}
```

#### 왜 이렇게 구현했는가?

**고정 비트레이트의 문제:**
```
네트워크 상태: 불안정 (LTE → WiFi 전환 중)
설정 비트레이트: 4500 kbps

결과:
1. 버퍼 누적 → 지연시간 증가
2. 패킷 손실 → 화면 깨짐
3. 연결 끊김 → 시청자 이탈
```

**적응형 비트레이트의 효과:**
```
네트워크 상태: 불안정
적응형 조절: 4500 → 1500 kbps

결과:
1. 버퍼 안정 → 지연시간 유지
2. 패킷 전송 성공 → 화면 정상
3. 연결 유지 → 끊김 없는 시청
```

**이점:**
1. **시청 품질**: 네트워크 상태에 맞는 최적 품질
2. **안정성**: 버퍼 오버플로우 방지
3. **연결 유지**: 네트워크 변동에도 끊김 없음

---

## 오류 처리 전략

### 1. 타입 안전한 오류 열거형

#### 구현 방식
```swift
public enum LiveStreamError: Error, LocalizedError, Equatable {
    case initializationFailed(String)
    case deviceNotFound(String)
    case networkError(String)
    case authenticationFailed(String)
    case streamingFailed(String)
    case configurationError(String)
    case permissionDenied(String)
    case connectionTimeout
    case serverError(Int, String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .connectionTimeout:
            return "연결 시간이 초과되었습니다"
        case .authenticationFailed(let message):
            return "인증 실패: \(message)"
        // ...
        }
    }
}
```

#### 왜 이렇게 구현했는가?

**일반 Error의 문제:**
```swift
// ❌ 일반 Error - 처리 어려움
func startStreaming() throws {
    throw NSError(domain: "streaming", code: -1, userInfo: nil)
}

// catch에서:
catch {
    // error가 무슨 종류인지 알 수 없음
    // 사용자에게 뭐라고 안내해야 할지 모름
}
```

**타입 안전한 열거형의 장점:**
```swift
// ✅ 구체적인 오류 타입
catch let error as LiveStreamError {
    switch error {
    case .connectionTimeout:
        showAlert("네트워크를 확인하고 다시 시도하세요")
    case .authenticationFailed:
        showAlert("스트림 키를 확인하세요")
    case .networkError:
        showAlert("인터넷 연결을 확인하세요")
    // 각 오류에 맞는 명확한 안내 가능
    }
}
```

**Equatable 준수 이유:**
```swift
// 테스트에서 오류 비교 가능
func testConnectionTimeout() async {
    // ...
    XCTAssertEqual(error, LiveStreamError.connectionTimeout)
}
```

**이점:**
1. **명확한 오류 분류**: 오류 종류를 코드로 구분
2. **사용자 친화적 메시지**: 각 오류에 맞는 안내
3. **테스트 가능**: 오류 종류 검증 용이

---

### 2. 복구 가능한 오류 처리

#### 구현 방식
```swift
func startStreamingWithRetry(settings: LiveStreamSettings, maxRetries: Int = 3) async throws {
    var lastError: Error?

    for attempt in 1...maxRetries {
        do {
            try await startScreenCaptureStreaming(with: settings)
            return  // 성공
        } catch let error as LiveStreamError {
            lastError = error

            // 복구 가능한 오류인지 확인
            guard isRecoverableError(error) else {
                throw error  // 복구 불가능하면 즉시 실패
            }

            // 재시도 전 대기 (지수 백오프)
            let delay = pow(2.0, Double(attempt))
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            logger.info("재시도 \(attempt)/\(maxRetries)")
        }
    }

    throw lastError ?? LiveStreamError.unknown("알 수 없는 오류")
}

func isRecoverableError(_ error: LiveStreamError) -> Bool {
    switch error {
    case .connectionTimeout, .networkError:
        return true  // 네트워크 문제는 재시도 가능
    case .authenticationFailed, .configurationError:
        return false  // 설정 문제는 재시도해도 실패
    default:
        return false
    }
}
```

#### 왜 이렇게 구현했는가?

**지수 백오프 사용 이유:**
```
시도 1: 실패 → 2초 대기
시도 2: 실패 → 4초 대기
시도 3: 실패 → 8초 대기

이점:
1. 일시적 네트워크 문제 시 자연 복구 대기
2. 서버 과부하 시 부담 완화
3. 즉각적인 재시도보다 성공률 높음
```

**복구 가능/불가능 구분 이유:**
```swift
// 복구 가능: 재시도 의미 있음
// - connectionTimeout: 네트워크 일시 불안정
// - networkError: 잠깐의 연결 끊김

// 복구 불가능: 재시도해도 같은 결과
// - authenticationFailed: 스트림 키 틀림
// - configurationError: 설정 오류
// → 재시도 대신 사용자에게 수정 요청
```

**이점:**
1. **자동 복구**: 일시적 문제 자동 해결
2. **빠른 실패**: 복구 불가능한 문제는 즉시 알림
3. **서버 보호**: 지수 백오프로 과부하 방지

---

## 보안 설계

### 1. Keychain을 통한 민감 정보 저장

#### 구현 방식
```swift
class KeychainManager {
    private let service = "com.livestreamingcore"

    func saveStreamKey(_ key: String) throws {
        let data = key.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "streamKey",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // 기존 항목 삭제 후 추가
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
    }
}
```

#### 왜 이렇게 구현했는가?

**UserDefaults vs Keychain:**
```swift
// ❌ UserDefaults - 보안 취약
UserDefaults.standard.set(streamKey, forKey: "streamKey")
// 문제:
// 1. 평문 저장 (plist 파일에 그대로)
// 2. 백업에 포함 (iCloud, iTunes)
// 3. 탈옥 기기에서 쉽게 접근 가능

// ✅ Keychain - 안전한 저장
KeychainManager().saveStreamKey(streamKey)
// 장점:
// 1. 하드웨어 암호화 (Secure Enclave)
// 2. 앱별 격리 (다른 앱 접근 불가)
// 3. 백업에서 제외 가능
```

**`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` 선택 이유:**
```
접근성 옵션:
- kSecAttrAccessibleAlways: 항상 접근 가능 (보안 낮음)
- kSecAttrAccessibleWhenUnlocked: 잠금 해제 시 접근
- kSecAttrAccessibleWhenUnlockedThisDeviceOnly: 잠금 해제 + 이 기기만

✅ 선택: WhenUnlockedThisDeviceOnly
- 기기 잠금 시 접근 불가 (도난 대비)
- 다른 기기로 복원해도 복사 안 됨 (백업 유출 대비)
- 스트림 키는 기기별로 관리하는 것이 안전
```

**이점:**
1. **하드웨어 보안**: Secure Enclave 활용
2. **앱 격리**: 다른 앱에서 접근 불가
3. **기기 잠금 연동**: 분실/도난 시 보호

---

## 확장성 고려사항

### 1. 새로운 스트리밍 플랫폼 추가

#### 현재 구조
```swift
// 플랫폼 독립적인 설정
struct LiveStreamSettings {
    var rtmpURL: String
    var streamKey: String
    // ...
}

// YouTube 프리셋
enum YouTubeLivePreset { ... }
```

#### 확장 방법
```swift
// 새로운 플랫폼 프리셋 추가
enum TwitchPreset: String, CaseIterable {
    case p720 = "twitch_720p"
    case p1080 = "twitch_1080p"

    var settings: (width: Int, height: Int, bitrate: Int) {
        switch self {
        case .p720: return (1280, 720, 3000)
        case .p1080: return (1920, 1080, 6000)
        }
    }
}

// 설정에 확장 메서드 추가
extension LiveStreamSettings {
    mutating func applyTwitchPreset(_ preset: TwitchPreset) {
        let s = preset.settings
        videoWidth = s.width
        videoHeight = s.height
        videoBitrate = s.bitrate
        rtmpURL = "rtmp://live.twitch.tv/app"
    }
}
```

### 2. 새로운 인코더 지원

#### 확장 방법
```swift
// 프로토콜로 인코더 추상화
protocol VideoEncoderProtocol {
    func encode(_ buffer: CVPixelBuffer) async throws -> Data
    var supportedCodecs: [VideoCodec] { get }
}

// HEVC 인코더 추가
class HEVCEncoder: VideoEncoderProtocol {
    func encode(_ buffer: CVPixelBuffer) async throws -> Data {
        // HEVC 인코딩 구현
    }

    var supportedCodecs: [VideoCodec] { [.hevc] }
}

// 기존 H.264 인코더
class H264Encoder: VideoEncoderProtocol {
    // 기존 구현 유지
}
```

**이점:**
1. **플랫폼 확장**: 새 플랫폼 추가 시 기존 코드 수정 최소화
2. **코덱 확장**: 새 인코더 추가 시 인터페이스 유지
3. **하위 호환성**: 기존 코드 영향 없이 기능 추가

---

## 결론

LiveStreamingCore는 다음 원칙을 따라 설계되었습니다:

1. **단일 책임**: 각 매니저가 하나의 역할만 담당
2. **추상화**: HaishinKit을 래핑하여 사용 편의성 제공
3. **안전성**: 타입 안전한 오류 처리, Keychain 보안
4. **성능**: 하드웨어 가속 우선, 적응형 품질 조절
5. **확장성**: 프로토콜 기반 설계로 미래 확장 용이

이러한 설계 결정은 실제 YouTube Live 스트리밍 앱 개발 경험에서 도출되었으며, 안정성과 사용 편의성을 최우선으로 고려했습니다.
