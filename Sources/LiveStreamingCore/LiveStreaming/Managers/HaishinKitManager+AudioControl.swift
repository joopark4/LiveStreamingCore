import AVFoundation
import Foundation
import HaishinKit
import RTMPHaishinKit

extension HaishinKitManager {

  // MARK: - Audio peak observer
  //
  // 소비자 앱이 `RTMPStream` 의 `addOutput(_:)` 를 직접 호출하지 않고도 오디오 피크만
  // 받아갈 수 있도록 attach/detach 를 HaishinKitManager 가 캡슐화한다.
  // 과거에는 app 쪽에서 `import HaishinKit` 으로 `StreamOutput` 을 구현한 observer 를 직접
  // `getRTMPStream()?.addOutput(observer)` 로 붙였는데, 이는 HaishinKit 타입이 app layer 로
  // 새는 유일한 경로였음.

  /// 현재 스트리밍 중인 RTMPStream 에 오디오 피크 옵저버를 붙이고 콜백으로 결과를 전달.
  /// 이미 붙어 있는 경우 기존 옵저버를 교체한다.
  /// - Parameter onPeak: `(normalizedLevel 0~1, decibels -80~0)` 가 전달되는 클로저.
  ///   콜 사이트가 어느 actor 에 있든 안전하게 호출될 수 있도록 `@Sendable`.
  public func attachAudioPeakObserver(
    onPeak: @escaping @Sendable (_ level: Float, _ decibels: Float) -> Void
  ) async {
    guard let stream = await streamSwitcher.stream else { return }
    if let existing = audioPeakStreamOutput {
      await stream.removeOutput(existing)
    }
    let observer = AudioPeakStreamOutput(onPeak: onPeak)
    await stream.addOutput(observer)
    audioPeakStreamOutput = observer
    logger.info("🎵 오디오 피크 옵저버 연결", category: .audio)
  }

  /// 옵저버를 떼어 피크 콜백을 중단.
  public func detachAudioPeakObserver() async {
    guard let observer = audioPeakStreamOutput else { return }
    if let stream = await streamSwitcher.stream {
      await stream.removeOutput(observer)
    }
    audioPeakStreamOutput = nil
    logger.info("🎵 오디오 피크 옵저버 해제", category: .audio)
  }

  /// 현재 스트림에 옵저버가 연결되어 있는지 여부 — 소비자 앱이 재연결 필요 여부를 판단할 때 사용.
  public var isAudioPeakObserverAttached: Bool {
    audioPeakStreamOutput != nil
  }

  // MARK: - Microphone mute

  @discardableResult
  public func setMicrophoneMuted(_ muted: Bool) async -> Bool {
    isMicrophoneMuted = muted

    let primaryApplied = await applyMicrophoneMuteState(to: mixer, muted: muted)

    let legacyApplied: Bool
    if let mediaMixer {
      legacyApplied = await applyMicrophoneMuteState(to: mediaMixer, muted: muted)
    } else {
      legacyApplied = true
    }

    logger.info(
      "🎤 송출 마이크 \(muted ? "음소거" : "음소거 해제") 적용",
      category: .audio
    )
    return primaryApplied && legacyApplied
  }

  func applyCurrentMicrophoneMuteState() async {
    _ = await setMicrophoneMuted(isMicrophoneMuted)
  }

  private func applyMicrophoneMuteState(to mixer: MediaMixer, muted: Bool) async -> Bool {
    var audioMixerSettings = await mixer.audioMixerSettings
    audioMixerSettings.isMuted = false
    audioMixerSettings.mainTrack = 0

    var trackSettings = audioMixerSettings.tracks[0] ?? AudioMixerTrackSettings()
    trackSettings.isMuted = muted
    audioMixerSettings.tracks[0] = trackSettings

    await mixer.setAudioMixerSettings(audioMixerSettings)
    return true
  }
}
