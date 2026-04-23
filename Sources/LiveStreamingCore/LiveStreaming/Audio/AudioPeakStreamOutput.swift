import AVFoundation
import CoreMedia
import Foundation
import HaishinKit
import RTMPHaishinKit

/// 스트리밍 중 `RTMPStream` 의 오디오 출력에 붙어 피크 레벨을 계산해 콜백으로 전달하는 `StreamOutput`.
/// 소비자 앱이 직접 `HaishinKit.StreamOutput` 을 구현하지 않고도 attach 할 수 있도록
/// LiveStreamingCore 내부에 캡슐화.
final class AudioPeakStreamOutput: NSObject, StreamOutput, @unchecked Sendable {
    typealias PeakHandler = @Sendable (_ level: Float, _ decibels: Float) -> Void

    private let onPeak: PeakHandler
    private let lock = NSLock()
    private var previousLevel: Float = 0

    init(onPeak: @escaping PeakHandler) {
        self.onPeak = onPeak
    }

    nonisolated func stream(_ stream: some StreamConvertible, didOutput audio: AVAudioBuffer, when: AVAudioTime) {
        guard let pcmBuffer = audio as? AVAudioPCMBuffer else { return }

        let (level, decibels) = AudioPeakMeter.measurePeak(from: pcmBuffer)

        lock.lock()
        let smoothed = max(level, previousLevel * 0.78)
        previousLevel = smoothed
        lock.unlock()

        onPeak(smoothed, decibels)
    }

    nonisolated func stream(_ stream: some StreamConvertible, didOutput video: CMSampleBuffer) {
        // peak 계산에는 비디오가 필요하지 않음.
    }
}
