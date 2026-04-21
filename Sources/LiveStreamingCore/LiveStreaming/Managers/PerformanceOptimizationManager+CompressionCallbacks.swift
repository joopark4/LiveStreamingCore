import Foundation
import AVFoundation
import VideoToolbox
import Metal
import CoreImage
import UIKit
import os.log
import Accelerate

extension PerformanceOptimizationManager {
    // MARK: - 압축 콜백 처리 및 지원 메서드

    /// 압축 오류 처리
    func handleCompressionError(status: OSStatus, infoFlags: VTEncodeInfoFlags) {
        let errorDescription = compressionErrorDescription(status)
        logger.error("❌ VideoToolbox 압축 실패: \(errorDescription) (코드: \(status))")
        
        // 특정 오류에 대한 복구 시도
        switch status {
        case kVTInvalidSessionErr:
            logger.warning("⚠️ 압축 세션 무효화 - 재생성 시도")
            Task { await recreateCompressionSession() }
            
        case kVTAllocationFailedErr:
            logger.warning("⚠️ 메모리 할당 실패 - 메모리 정리 후 재시도")
            Task { await handleMemoryPressure() }
            
        case kVTPixelTransferNotSupportedErr:
            logger.warning("⚠️ 픽셀 전송 실패 - 포맷 변환 재시도")
            Task { await handlePixelFormatIssue() }
            
        default:
            logger.error("❌ 알 수 없는 압축 오류: \(status)")
            Task { await handleGenericCompressionError(status) }
        }
        
        // 통계 업데이트
        Task { @MainActor in
            self.compressionErrorCount += 1
            self.lastCompressionErrorTime = Date()
            self.updateCompressionSuccessRate()
        }
    }
    
    /// 압축 통계 수집
    func collectCompressionStatistics(sampleBuffer: CMSampleBuffer, infoFlags: VTEncodeInfoFlags) {
        // 1. 프레임 크기 통계
        let dataSize = CMSampleBufferGetTotalSampleSize(sampleBuffer)
        
        // 2. 키프레임 감지
        var isKeyFrame = false
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) {
            let array = attachments as! [CFDictionary]
            for attachment in array {
                let dict = attachment as! [CFString: Any]
                if let notSync = dict[kCMSampleAttachmentKey_NotSync] as? Bool {
                    isKeyFrame = !notSync
                    break
                } else {
                    isKeyFrame = true // NotSync가 없으면 키프레임으로 간주
                    break
                }
            }
        }
        
        // 3. 압축 품질 정보
        let compressionRatio = calculateCompressionRatio(sampleBuffer: sampleBuffer)
        
        // 4. 통계 업데이트 (백그라운드에서)
        Task { @MainActor in
            self.updateCompressionStatistics(
                dataSize: dataSize,
                isKeyFrame: isKeyFrame,
                compressionRatio: compressionRatio,
                infoFlags: infoFlags
            )
        }
        
        logger.debug("📊 압축 통계 - 크기: \(dataSize)bytes, 키프레임: \(isKeyFrame), 압축비: \(String(format: "%.2f", compressionRatio))")
    }
    
    /// 압축된 프레임을 HaishinKit으로 전달
    func forwardCompressedFrame(sampleBuffer: CMSampleBuffer) {
        // HaishinKitManager와의 연동 로직
        // 실제 구현에서는 delegate 패턴이나 클로저를 통해 전달
        NotificationCenter.default.post(
            name: .videoToolboxFrameReady,
            object: nil,
            userInfo: ["sampleBuffer": sampleBuffer]
        )
    }
    
}
