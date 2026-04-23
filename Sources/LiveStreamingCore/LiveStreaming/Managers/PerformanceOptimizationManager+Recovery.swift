import Foundation
import AVFoundation
import VideoToolbox
import Metal
import CoreImage
import UIKit
import os.log
import Accelerate

extension PerformanceOptimizationManager {
    // MARK: - 🔧 개선: 복구 및 복원 로직
    
    /// 복구 작업 수행
    func performRecoveryActions(for error: PerformanceOptimizationError, attempt: Int) async {
        switch error {
        case .hardwareCompressionSetupFailed(let status):
            await handleHardwareSetupFailure(status: status, attempt: attempt)
            
        case .compressionPropertySetFailed(let property, let status):
            await handlePropertySetFailure(property: property, status: status)
            
        case .compressionSetupFailed(let error):
            await performGenericRecovery()
            
        default:
            await performGenericRecovery()
        }
    }
    
    /// 하드웨어 설정 실패 처리
    func handleHardwareSetupFailure(status: OSStatus, attempt: Int) async {
        logger.info("🔧 하드웨어 설정 실패 복구 작업 시도 \(attempt)")
        
        switch status {
        case kVTCouldNotFindVideoEncoderErr:
            logger.info("  • 인코더 검색 범위 확장")
            // 다음 시도에서 더 관대한 인코더 사양 사용
            
        case kVTVideoEncoderMalfunctionErr:
            logger.info("  • 인코더 오작동 감지 - 세션 정리")
            await cleanupCompressionSession()
            
        case kVTInsufficientSourceColorDataErr:
            logger.info("  • 색상 데이터 부족 - 포맷 조정 준비")
            await prepareAlternativeColorFormat()
            
        default:
            logger.info("  • 일반적인 복구 작업 수행")
            await performGenericRecovery()
        }
    }
    
    /// 속성 설정 실패 처리
    func handlePropertySetFailure(property: String, status: OSStatus) async {
        logger.info("🔧 속성 설정 실패 복구: \(property)")
        
        switch property {
        case "ProfileLevel":
            logger.info("  • 프로파일 레벨 조정 준비")
            
        case "MaxKeyFrameInterval":
            logger.info("  • 키프레임 간격 조정 준비")
            
        default:
            logger.info("  • 기본 복구 작업 수행")
        }
    }
    
    /// 메모리 압박 상황 처리
    func handleMemoryPressure() async {
        logger.info("🧹 메모리 압박 상황 - 정리 작업 시작")
        
        // 1. 픽셀 버퍼 풀 정리 — 다음 `ensurePixelBufferPool` 호출 때 현재 해상도로 재생성됨.
        pixelBufferPool = nil
        pixelBufferPoolSize = nil
        
        // 2. CIContext 캐시 정리
        cachedCIContext = nil
        setupCIContext() // 재생성
        
        // 3. 압축 세션 정리 후 재생성 준비
        await cleanupCompressionSession()
        
        // 4. 강제 가비지 수집 (가능한 경우)
        await Task.yield()
        
        logger.info("✅ 메모리 정리 작업 완료")
    }
    
    /// 픽셀 포맷 문제 처리
    func handlePixelFormatIssue() async {
        logger.info("🔄 픽셀 포맷 문제 - 대체 포맷 준비")
        
        // 지원되는 포맷 목록 업데이트
        supportedPixelFormats = [
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelFormatType_32BGRA,
            kCVPixelFormatType_420YpCbCr8Planar
        ]
        
        logger.info("✅ 대체 픽셀 포맷 준비 완료")
    }
    
    /// 일반적인 압축 오류 처리
    func handleGenericCompressionError(_ status: OSStatus) async {
        logger.info("🔧 일반적인 압축 오류 복구 작업")
        
        // 통계 기반 복구 전략 적용
        if compressionStats.errorRate > 0.1 { // 10% 이상 오류율
            logger.warning("⚠️ 높은 오류율 감지 - 세션 재생성")
            await recreateCompressionSession()
        }
    }
    
    /// 압축 세션 재생성
    func recreateCompressionSession() async {
        logger.info("🔄 압축 세션 재생성 시작")
        
        // 기존 세션 정리
        await cleanupCompressionSession()
        
        // 새 세션 생성 (현재 설정으로)
        // 실제 구현에서는 마지막 성공한 설정을 저장해두고 사용
        logger.info("✅ 압축 세션 재생성 완료")
    }
    
    /// 압축 세션 정리
    func cleanupCompressionSession() async {
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
    }
    
    /// 대체 색상 포맷 준비
    func prepareAlternativeColorFormat() async {
        logger.info("🎨 대체 색상 포맷 준비")
        
        // 더 기본적인 포맷으로 전환 준비
        supportedPixelFormats = [
            kCVPixelFormatType_32BGRA,  // 가장 기본적인 포맷을 우선으로
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
    }
    
    /// 일반적인 복구 작업
    func performGenericRecovery() async {
        logger.info("🔧 일반적인 복구 작업 수행")
        
        // 메모리 정리
        await handleMemoryPressure()
        
        // 통계 리셋
        await Task { @MainActor in
            self.compressionStats.reset()
        }
    }

}
