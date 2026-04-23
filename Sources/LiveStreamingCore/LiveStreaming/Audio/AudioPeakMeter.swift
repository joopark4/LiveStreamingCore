import AVFoundation
import Foundation

/// AVAudioPCMBuffer 에서 피크 레벨을 계산하는 순수 유틸. 스트림 경로(stream audio)와
/// 대기 경로(AVAudioEngine tap) 모두에서 동일한 sensitivity 커브를 쓰기 위해
/// LiveStreamingCore 에 공용으로 둔다.
public enum AudioPeakMeter {

    /// - Parameter buffer: 입력 PCM 버퍼. float / int16 / int32 채널 데이터를 지원.
    /// - Returns: `(normalizedLevel, decibels)` 튜플.
    ///   - `normalizedLevel`: 0.0 ~ 1.0 사이로 정규화된 UI 표시용 값.
    ///   - `decibels`: -80 ~ 0 dBFS 범위의 원본 피크.
    public static func measurePeak(from buffer: AVAudioPCMBuffer) -> (level: Float, decibels: Float) {
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return (0, -80) }

        let channelCount = Int(buffer.format.channelCount)
        guard channelCount > 0 else { return (0, -80) }

        let sampleStep = max(1, frameCount / 1024)
        var peak: Float = 0

        if let channels = buffer.floatChannelData {
            for channel in 0..<channelCount {
                let samples = channels[channel]
                var index = 0
                while index < frameCount {
                    peak = max(peak, abs(samples[index]))
                    index += sampleStep
                }
            }
        } else if let channels = buffer.int16ChannelData {
            let scale = Float(Int16.max)
            for channel in 0..<channelCount {
                let samples = channels[channel]
                var index = 0
                while index < frameCount {
                    peak = max(peak, abs(Float(samples[index])) / scale)
                    index += sampleStep
                }
            }
        } else if let channels = buffer.int32ChannelData {
            let scale = Float(Int32.max)
            for channel in 0..<channelCount {
                let samples = channels[channel]
                var index = 0
                while index < frameCount {
                    peak = max(peak, abs(Float(samples[index])) / scale)
                    index += sampleStep
                }
            }
        }

        let safePeak = max(peak, 0.0001)
        let decibels = max(-80, min(0, 20 * log10(safePeak)))
        let normalized = normalizedLevel(from: decibels)

        return (normalized, decibels)
    }

    /// 작은 음성도 잘 보이도록 감도를 보정한 노이즈 플로어·헤드룸·감마 커브.
    /// 이전에는 `StreamAudioPeakOutputObserver` 와 `IdleMicrophonePeakMonitor` 양쪽에서
    /// 같은 상수들이 복제되어 있어 한쪽만 고치면 큰 회귀를 유발했다.
    public static func normalizedLevel(from decibels: Float) -> Float {
        let noiseFloor: Float = -72
        let headroom: Float = -6
        let gamma: Float = 0.72

        if decibels <= noiseFloor {
            return 0
        }

        let linear = ((decibels - noiseFloor) / (headroom - noiseFloor)).clamped(to: 0...1)
        return pow(linear, gamma).clamped(to: 0...1)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
