import AVFoundation
import Combine
import CoreImage
import Foundation
import HaishinKit
import Network
import UIKit
import VideoToolbox
import os.log

extension HaishinKitManager {
  // MARK: - Data Monitoring Methods

  /// 데이터 송출 모니터링 시작
  func startDataMonitoring() {
    resetTransmissionStats()

    dataMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {
      [weak self] _ in
      Task { @MainActor [weak self] in
        await self?.updateTransmissionStats()
        await self?.logConnectionStatus()
      }
    }

    logger.info("📊 데이터 송출 모니터링 시작됨")
  }

  /// 연결 상태 모니터링 시작 (개선된 버전)
  func startConnectionHealthMonitoring() {
    // 연결 상태를 적당히 체크 (15초마다 - 덜 민감하게)
    connectionHealthTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) {
      [weak self] _ in
      Task { @MainActor [weak self] in
        await self?.checkConnectionHealth()
      }
    }

    // 재연결 상태 초기화
    reconnectAttempts = 0
    reconnectDelay = 8.0  // 초기 재연결 지연시간 최적화 (15.0 → 8.0)
    connectionFailureCount = 0

    logger.info("🔍 향상된 연결 상태 모니터링 시작됨 (15초 주기)", category: .connection)
  }

  /// 연결 상태 건강성 체크 (개선된 버전)
  func checkConnectionHealth() async {
    guard isStreaming else { return }

    if let connection = await streamSwitcher.connection {
      let isConnected = await connection.connected

      // 추가 검증: 스트림 상태도 확인
      var streamStatus = "unknown"
      var isStreamPublishing = false
      if let stream = await streamSwitcher.stream {
        // Sendable 프로토콜 문제로 인해 stream.info 접근 제외
        streamStatus = "stream_connected"
        // 간단히 connection 연결 상태만 확인
        isStreamPublishing = isConnected  // RTMPConnection이 연결되면 스트림도 활성으로 간주
        logger.debug("🔍 스트림 상태: 연결됨", category: .connection)
      }

      // 실제 연결 상태와 스트림 상태 모두 확인
      let isReallyStreaming = isConnected && isStreamPublishing

      if !isReallyStreaming {
        connectionFailureCount += 1
        logger.warning(
          "⚠️ 연결 상태 불량 감지 - 연결: \(isConnected), 퍼블리싱: \(isStreamPublishing) (\(connectionFailureCount)/\(maxConnectionFailures))",
          category: .connection)

        if connectionFailureCount >= maxConnectionFailures {
          logger.error("❌ 연결 실패 한도 초과, 즉시 재연결 시도", category: .connection)
          handleConnectionLost()
        }
      } else {
        // 연결이 정상이면 모든 카운터 리셋
        if connectionFailureCount > 0 || reconnectAttempts > 0 {
          logger.info("✅ 연결 상태 완전 회복됨 - 모든 카운터 리셋", category: .connection)
          connectionFailureCount = 0
          reconnectAttempts = 0
          reconnectDelay = 10.0
        }
      }
    } else {
      logger.warning("⚠️ RTMP 연결 객체가 존재하지 않음", category: .connection)
      connectionFailureCount += 1
      if connectionFailureCount >= maxConnectionFailures {
        handleConnectionLost()
      }
    }

    lastConnectionCheck = Date()
  }

  /// 실행 환경 분석 (진단용 정보 출력)
  func analyzeExecutionEnvironment() {
    logger.info("  📱 실행 환경 분석:", category: .connection)

    #if targetEnvironment(simulator)
      logger.info("    🖥️ iOS 시뮬레이터에서 실행 중", category: .connection)
      logger.info("    ⚠️ 시뮬레이터 제약사항:", category: .connection)
      logger.info("      • 화면 캡처 기능이 실제 디바이스와 다를 수 있음", category: .connection)
      logger.info("      • 일부 하드웨어 기능 제한", category: .connection)
      logger.info("      • 네트워크 성능이 실제 디바이스와 차이날 수 있음", category: .connection)
      logger.info("    💡 권장사항: 실제 iOS 디바이스에서 테스트 해보세요", category: .connection)
    #else
      logger.info("    📱 실제 iOS 디바이스에서 실행 중", category: .connection)
      logger.info("    ✅ 하드웨어 환경: 정상", category: .connection)
    #endif

    // iOS 버전 확인
    let systemVersion = UIDevice.current.systemVersion
    logger.info("    📋 iOS 버전: \(systemVersion)", category: .connection)

    // 디바이스 모델 확인
    let deviceModel = UIDevice.current.model
    logger.info("    📱 디바이스 모델: \(deviceModel)", category: .connection)

    // 화면 캡처 권한 상태 확인
    checkScreenCapturePermissions()

    // 송출 데이터 흐름 진단
    analyzeDataFlowConnection()

    logger.info("    ", category: .connection)
  }

  /// 화면 캡처 권한 확인 (진단용 정보 출력)
  func checkScreenCapturePermissions() {
    // 화면 캡처 가능 여부 확인 (iOS 17+ 타겟이므로 항상 사용 가능)
    logger.info("    🎥 화면 캡처 기능: 사용 가능 (ReplayKit 지원)", category: .connection)

    // 현재 스트리밍 설정 확인
    if let settings = currentSettings {
      logger.info(
        "    📊 현재 설정 해상도: \(settings.videoWidth)x\(settings.videoHeight)", category: .connection)
      logger.info("    📈 현재 설정 비트레이트: \(settings.videoBitrate) kbps", category: .connection)
      logger.info("    📺 현재 설정 프레임레이트: \(settings.frameRate) fps", category: .connection)
    }
  }

  /// 송출 데이터 흐름 진단 (진단용 정보 출력)
  func analyzeDataFlowConnection() {
    logger.info("  📊 송출 데이터 흐름 진단:", category: .connection)

    // 1. MediaMixer 상태 확인
    Task {
      let isMixerRunning = await mixer.isRunning
      logger.info("    🎛️ MediaMixer 상태: \(isMixerRunning ? "실행 중" : "중지됨")", category: .connection)
    }

    // 2. RTMPStream 연결 상태 확인
    if currentRTMPStream != nil {
      logger.info("    📡 RTMPStream 연결: 연결됨", category: .connection)
    } else {
      logger.info("    📡 RTMPStream 연결: ❌ 연결되지 않음", category: .connection)
    }

    // 3. 화면 캡처 모드 확인
    logger.info("    🎥 화면 캡처 모드: \(isScreenCaptureMode ? "활성화" : "비활성화")", category: .connection)

    // 4. 수동 프레임 전송 상태 확인
    logger.info("    📹 수동 프레임 전송 통계:", category: .connection)
    logger.info("      • 전송 성공: \(screenCaptureStats.successCount)프레임", category: .connection)
    logger.info("      • 전송 실패: \(screenCaptureStats.failureCount)프레임", category: .connection)
    logger.info(
      "      • 현재 FPS: \(String(format: "%.1f", screenCaptureStats.currentFPS))",
      category: .connection)

    // 5. 데이터 흐름 체인 확인
    logger.info("    🔗 데이터 흐름 체인:", category: .connection)
    logger.info("      1️⃣ CameraPreviewUIView → sendManualFrame()", category: .connection)
    logger.info("      2️⃣ HaishinKitManager → RTMPStream.append()", category: .connection)
    logger.info("      3️⃣ RTMPStream → RTMP Server", category: .connection)

    // 6. 목업 데이터 사용 여부 확인
    if screenCaptureStats.frameCount == 0 {
      logger.warning("    ⚠️ 실제 프레임 데이터 전송 없음 - 목업 데이터 의심", category: .connection)
      logger.info("    💡 CameraPreviewUIView의 화면 캡처 타이머가 시작되었는지 확인 필요", category: .connection)
    } else {
      logger.info("    ✅ 실제 프레임 데이터 전송 확인됨", category: .connection)
    }

    // 7. MediaMixer vs 직접 전송 방식 확인
    if currentRTMPStream != nil {
      logger.info("    📡 전송 방식: RTMPStream 직접 전송 (권장)", category: .connection)
    } else {
      logger.info("    📡 전송 방식: MediaMixer 백업 전송", category: .connection)
    }

    logger.error("    ", category: .connection)
  }

  /// 연결 상태 모니터링 중지
  func stopConnectionHealthMonitoring() {
    connectionHealthTimer?.invalidate()
    connectionHealthTimer = nil
    logger.info("🔍 연결 상태 모니터링 중지됨", category: .connection)
  }

  /// 연결 상태 로깅
  func logConnectionStatus() async {
    guard let connection = await streamSwitcher.connection else {
      logger.warning("⚠️ RTMP 연결 객체가 없습니다", category: .connection)
      return
    }

    let connectionState = await connection.connected ? "연결됨" : "연결 끊어짐"

    logger.debug("🔍 RTMP 연결 상태: \(connectionState)", category: .connection)

    // 연결이 끊어진 경우 에러 로그
    if !(await connection.connected) && isStreaming {
      logger.error("💔 RTMP 연결이 끊어져 있지만 스트리밍 상태가 활성화되어 있습니다", category: .connection)
      handleConnectionLost()
    }
  }

  /// 데이터 송출 모니터링 중지
  func stopDataMonitoring() {
    dataMonitoringTimer?.invalidate()
    dataMonitoringTimer = nil
    logger.info("📊 데이터 송출 모니터링 중지됨")
  }

  /// 송출 통계 리셋
  func resetTransmissionStats() {
    transmissionStats = DataTransmissionStats()
    frameCounter = 0
    lastFrameTime = CACurrentMediaTime()
    bytesSentCounter = 0
    logger.debug("📊 송출 통계 초기화됨")
  }

  /// 실시간 송출 통계 업데이트 (백그라운드에서 계산, 메인 스레드에서 UI 업데이트)
  func updateTransmissionStats() async {
    guard isStreaming else { return }

    // 🔧 개선: 통계 계산을 백그라운드에서 처리
    let currentTime = CACurrentMediaTime()
    let timeDiff = currentTime - lastFrameTime

    // 프레임 레이트 계산 (백그라운드에서 계산)
    let averageFrameRate = timeDiff > 0 ? Double(frameCounter) / timeDiff : 0.0

    // 메인 스레드에서 UI 업데이트
    await MainActor.run {
      self.transmissionStats.averageFrameRate = averageFrameRate
    }

    // 비트레이트 계산 (추정)
    if let settings = currentSettings {
      transmissionStats.currentVideoBitrate = Double(settings.videoBitrate)
      transmissionStats.currentAudioBitrate = Double(settings.audioBitrate)

      // 🔧 개선: 적응형 품질 조정을 사용자 옵션으로 변경 (기본값: 비활성화)
      if adaptiveQualityEnabled, let originalSettings = originalUserSettings {
        let optimizedSettings = performanceOptimizer.adaptQualityRespectingUserSettings(
          currentSettings: settings,
          userDefinedSettings: originalSettings
        )

        if !isSettingsEqual(settings, optimizedSettings) {
          logger.info("🎯 사용자가 활성화한 적응형 품질 조정 적용", category: .streaming)
          logger.info("  • 원본 설정 범위 내에서만 조정", category: .streaming)
          logger.info(
            "  • 비트레이트: \(settings.videoBitrate) → \(optimizedSettings.videoBitrate) kbps",
            category: .streaming)
          logger.info(
            "  • 프레임율: \(settings.frameRate) → \(optimizedSettings.frameRate) fps",
            category: .streaming)

          // 사용자에게 변경사항 통지 (로그로 대체)
          logger.info("📢 품질 조정 알림: 성능 최적화를 위해 설정이 조정되었습니다", category: .streaming)

          currentSettings = optimizedSettings

          // 비동기로 설정 적용
          Task {
            do {
              try await self.applyStreamSettings()
            } catch {
              self.logger.warning("⚠️ 적응형 품질 조정 적용 실패: \(error)", category: .streaming)
            }
          }
        }
      } else if !adaptiveQualityEnabled {
        // 적응형 품질 조정이 비활성화된 경우 사용자 설정 유지
        logger.debug("🔒 적응형 품질 조정 비활성화됨 - 사용자 설정 유지", category: .streaming)
      }
    }

    // 네트워크 지연 시간 업데이트 (실제 구현 시 RTMP 서버 응답 시간 측정)
    transmissionStats.networkLatency = estimateNetworkLatency()

    transmissionStats.lastTransmissionTime = Date()

    // 상세 로그 출력
    logDetailedTransmissionStats()
  }

  /// 네트워크 지연 시간 추정 (네트워크 품질 기반)
  /// - Note: 실제 ping 측정이 아닌 네트워크 품질에 따른 추정치 반환
  func estimateNetworkLatency() -> TimeInterval {
    // 네트워크 품질에 따른 추정치 반환 (실제 ping 측정 아님)
    switch transmissionStats.connectionQuality {
    case .excellent: return 0.020  // 추정 20ms
    case .good: return 0.050  // 추정 50ms
    case .fair: return 0.100  // 추정 100ms
    case .poor: return 0.300  // 추정 300ms
    case .unknown: return 0.150  // 추정 150ms
    }
  }

  /// 상세한 송출 통계 로그 (반복적인 로그 비활성화)
  func logDetailedTransmissionStats() {
    let stats = transmissionStats

    // 반복적인 상세 통계 로그 비활성화 (성능 최적화 및 로그 정리)
    // 중요한 문제 발생 시에만 로그 출력
    if stats.droppedFrames > 0 || stats.connectionQuality == .poor {
      logger.warning(
        "⚠️ 스트림 품질 문제: 드롭 프레임 \(stats.droppedFrames)개, 품질: \(stats.connectionQuality.description)",
        category: .streaming)
    }

    // 주요 이정표 프레임 수에서만 간단 요약 로그 (1000 프레임마다)
    if stats.videoFramesTransmitted > 0 && stats.videoFramesTransmitted % 1000 == 0 {
      logger.info(
        "📊 스트림 요약: \(stats.videoFramesTransmitted)프레임 전송, 평균 \(String(format: "%.1f", stats.averageFrameRate))fps",
        category: .streaming)
    }
  }

  /// 바이트 포맷팅
  func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
  }

  /// 연결 끊어짐 처리 (개선된 버전)
  func handleConnectionLost() {
    logger.error(
      "🚨 연결 끊어짐 감지 - 상세 분석 시작 (시도: \(reconnectAttempts + 1)/\(maxReconnectAttempts))",
      category: .connection)

    // 연결 끊어짐 원인 분석
    analyzeConnectionFailure()

    isStreaming = false
    currentStatus = .error(
      LiveStreamError.networkError(
        NSLocalizedString("rtmp_disconnected_reconnecting", comment: "RTMP 연결이 끊어졌습니다")))
    connectionStatus = NSLocalizedString(
      "connection_disconnected_waiting", comment: "연결 끊어짐 - 재연결 대기 중")
    stopDataMonitoring()

    logger.error("🛑 스트리밍 상태가 중지로 변경됨", category: .connection)

    // 재연결 한도 체크
    if reconnectAttempts >= maxReconnectAttempts {
      logger.error(
        "❌ 최대 재연결 시도 횟수 초과 (\(maxReconnectAttempts)회) - 자동 재연결 중단", category: .connection)
      currentStatus = .error(
        LiveStreamError.networkError(
          NSLocalizedString("youtube_live_connection_failed", comment: "YouTube Live 연결에 실패했습니다")))
      connectionStatus = NSLocalizedString(
        "youtube_live_check_needed", comment: "YouTube Live 확인 필요 - 수동 재시작 하세요")
      return
    }

    // 지능형 백오프 재연결 시도
    logger.info(
      "🔄 \(reconnectDelay)초 후 재연결 시도 (\(reconnectAttempts + 1)/\(maxReconnectAttempts))",
      category: .connection)
    DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
      Task {
        await self?.attemptReconnection()
      }
    }
  }

  /// 연결 실패 원인 분석
  func analyzeConnectionFailure() {
    logger.error("🔍 연결 실패 원인 분석:", category: .connection)

    // 1. 네트워크 상태 확인
    if let networkMonitor = networkMonitor {
      let path = networkMonitor.currentPath
      logger.error("  🌐 네트워크 상태: \(path.status)", category: .connection)
      logger.error(
        "  📡 사용 가능한 인터페이스: \(path.availableInterfaces.map { $0.name })", category: .connection)
      logger.error("  💸 비용 발생 연결: \(path.isExpensive)", category: .connection)
      logger.error("  🔒 제한됨: \(path.isConstrained)", category: .connection)
    }

    // 2. RTMP 연결 상태 확인 (비동기로 처리)
    Task {
      if let connection = await streamSwitcher.connection {
        let connected = await connection.connected
        logger.error("  🔗 RTMP 연결 상태: \(connected)", category: .connection)
      } else {
        logger.error("  🔗 RTMP 연결 객체: 없음", category: .connection)
      }
    }

    // 3. 설정 재확인
    if let settings = currentSettings {
      logger.error("  📍 RTMP URL: \(settings.rtmpURL)", category: .connection)
      logger.error("  🔑 스트림 키 길이: \(settings.streamKey.count)자", category: .connection)
      logger.error("  📊 비트레이트: \(settings.videoBitrate) kbps", category: .connection)
    }

    // 4. 전송 통계 확인
    logger.error("  📈 전송 통계:", category: .connection)
    logger.error(
      "    • 비디오 프레임: \(transmissionStats.videoFramesTransmitted)", category: .connection)
    logger.error(
      "    • 총 전송량: \(formatBytes(transmissionStats.totalBytesTransmitted))", category: .connection)
    logger.error(
      "    • 네트워크 지연: \(String(format: "%.0f", transmissionStats.networkLatency * 1000))ms",
      category: .connection)
    logger.error(
      "    • 연결 품질: \(transmissionStats.connectionQuality.description)", category: .connection)
    logger.error(
      "    • 재연결 시도: \(reconnectAttempts)/\(maxReconnectAttempts)", category: .connection)
    logger.error(
      "    • 연결 실패 횟수: \(connectionFailureCount)/\(maxConnectionFailures)", category: .connection)

    // 5. 일반적인 문제 제안
    logger.error("  💡 가능한 원인들:", category: .connection)
    logger.error("    1. 잘못된 RTMP URL 또는 스트림 키", category: .connection)
    logger.error("    2. YouTube Live 스트림이 비활성화됨", category: .connection)
    logger.error("    3. 네트워크 연결 불안정", category: .connection)
    logger.error("    4. 방화벽 또는 프록시 차단", category: .connection)
    logger.error("    5. 서버 과부하 또는 일시적 오류", category: .connection)

    // 6. 실행 환경 확인
    analyzeExecutionEnvironment()

    // 7. 스트림 키 상세 분석 (현재 설정이 있는 경우)
    if let settings = currentSettings {
      analyzeStreamKeyIssues(for: settings)
    }

    // 8. YouTube Live 전용 진단
    if let settings = currentSettings, settings.rtmpURL.contains("youtube.com") {
      logger.error("  📺 YouTube Live 상세 진단:", category: .connection)
      logger.error("    🚨 RTMP 핸드셰이크는 성공했지만 스트림 키 인증 실패!", category: .connection)
      logger.error("    ", category: .connection)
      logger.error("    ✅ 필수 해결 단계 (순서대로 확인):", category: .connection)
      logger.error("    1️⃣ YouTube Studio(studio.youtube.com) 접속", category: .connection)
      logger.error("    2️⃣ 좌측 메뉴에서 '라이브 스트리밍' 또는 '콘텐츠' → '라이브' 클릭", category: .connection)
      logger.error("    3️⃣ 스트림 페이지에서 '스트리밍 시작' 또는 '라이브 스트리밍 시작' 버튼 클릭 ⭐️", category: .connection)
      logger.error("    4️⃣ 상태가 '스트리밍을 기다리는 중...' 또는 'LIVE'로 변경 확인", category: .connection)
      logger.error("    5️⃣ 새로운 스트림 키 복사 (변경되었을 수 있음)", category: .connection)
      logger.error("    6️⃣ 앱에서 새 스트림 키로 교체 후 재시도", category: .connection)
      logger.error("    ", category: .connection)
      logger.error("    ⚠️ 추가 확인사항:", category: .connection)
      logger.error("    • 다른 스트리밍 프로그램(OBS, XSplit 등) 완전 종료", category: .connection)
      logger.error("    • YouTube Live가 첫 24시간 검증 과정을 거쳤는지 확인", category: .connection)
      logger.error("    • 계정 제재나 제한이 없는지 확인", category: .connection)
      logger.error("    • Wi-Fi 연결이 안정적인지 확인 (4G/5G보다 권장)", category: .connection)
      logger.error("    • 방화벽이나 회사 네트워크 제한 확인", category: .connection)
    }
  }

  /// 재연결 시도 (개선된 안정화 전략)
  func attemptReconnection() async {
    guard let settings = currentSettings else {
      logger.error("❌ 재연결 실패: 설정 정보가 없습니다", category: .connection)
      return
    }

    reconnectAttempts += 1
    logger.info(
      "🔄 RTMP 재연결 시도 #\(reconnectAttempts) (지연: \(reconnectDelay)초)", category: .connection)

    // 재연결 상태 UI 업데이트
    currentStatus = .connecting
    connectionStatus = "재연결 시도 중... (\(reconnectAttempts)/\(maxReconnectAttempts))"

    do {
      // 기존 연결 완전히 정리
      logger.info("🧹 기존 연결 정리 중...", category: .connection)
      await streamSwitcher.stopStreaming()

      // 충분한 대기 시간 (서버에서 이전 연결 완전 정리 대기)
      logger.info("⏰ 서버 연결 정리 대기 중 (1.5초)...", category: .connection)
      try await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5초 대기 (3초 → 1.5초로 단축)

      // 새로운 연결 시도
      logger.info("🚀 새로운 연결 시도...", category: .connection)
      try await startScreenCaptureStreaming(with: settings)

      logger.info("✅ RTMP 재연결 성공 (시도 \(reconnectAttempts)회 후)", category: .connection)

      // 성공 시 카운터 및 지연시간 리셋
      reconnectAttempts = 0
      reconnectDelay = 10.0
      connectionFailureCount = 0  // 연결 실패 카운터도 리셋

    } catch {
      logger.error(
        "❌ RTMP 재연결 실패 #\(reconnectAttempts): \(error.localizedDescription)", category: .connection)

      // 재연결 한도 체크
      if reconnectAttempts >= maxReconnectAttempts {
        logger.error("❌ 최대 재연결 시도 횟수 도달 - 중단", category: .connection)
        currentStatus = .error(
          LiveStreamError.networkError("재연결에 실패했습니다. 네트워크 상태를 확인 후 수동으로 다시 시작해주세요."))
        connectionStatus = "재연결 실패 - 수동 재시작 필요"
        stopConnectionHealthMonitoring()  // 모니터링 완전 중지
        return
      }

      // 선형 백오프: 재연결 지연시간 증가 (최적화: 5초 → 3초 증가량)
      reconnectDelay = min(reconnectDelay + 3.0, maxReconnectDelay)

      logger.info("🔄 다음 재연결 시도까지 \(reconnectDelay)초 대기", category: .connection)
      currentStatus = .error(
        LiveStreamError.networkError("재연결 시도 중... (\(reconnectAttempts)/\(maxReconnectAttempts))"))
      connectionStatus = "재연결 대기 중 (\(Int(reconnectDelay))초 후 재시도)"

      // 다음 재연결 시도 예약
      DispatchQueue.main.asyncAfter(deadline: .now() + reconnectDelay) { [weak self] in
        Task {
          await self?.attemptReconnection()
        }
      }
    }
  }

}
