import Foundation
import AVFoundation
import VideoToolbox
import Metal
import CoreImage
import UIKit
import os.log
import Accelerate

extension PerformanceOptimizationManager {
    // MARK: - 성능 모니터링
    
    /// 성능 모니터링 시작 (백그라운드에서 실행)
    func startPerformanceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            // 🔧 개선: 성능 측정은 백그라운드에서 실행
            self?.performanceQueue.async {
                self?.updatePerformanceMetrics()
            }
        }
    }
    
    /// 성능 메트릭스 업데이트 (백그라운드에서 측정, 메인 스레드에서 UI 업데이트)
    func updatePerformanceMetrics() {
        // 백그라운드에서 성능 측정 (CPU 집약적 작업)
        let cpuUsage = getCurrentCPUUsage()
        let memoryUsage = getCurrentMemoryUsage()
        
        // 메인 스레드에서 UI 업데이트
        Task { @MainActor in
            let gpuUsage = self.getCurrentGPUUsage()
            
            self.currentCPUUsage = cpuUsage
            self.currentMemoryUsage = memoryUsage
            self.currentGPUUsage = gpuUsage
            
            // 임계값 초과 시 경고
            if cpuUsage > self.performanceThresholds.cpuCriticalThreshold {
                self.logger.error("🔥 CPU 사용량 위험 수준: \(String(format: "%.1f", cpuUsage))%")
            }
            
            if memoryUsage > self.performanceThresholds.memoryCriticalThreshold {
                self.logger.error("🔥 메모리 사용량 위험 수준: \(String(format: "%.1f", memoryUsage))MB")
            }
        }
    }
    
    /// CPU 사용량 추정 (메모리 기반 간접 추정)
    /// - Note: 실제 CPU 사용량이 아닌 메모리 크기 기반 추정치 반환
    func getCurrentCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            // 메모리 크기 기반 CPU 사용률 추정 (실제 CPU 측정 아님)
            return Double(info.resident_size) / 1024.0 / 1024.0 * 0.1
        }
        return 0.0
    }
    
    /// 메모리 사용량 측정
    func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // MB
        }
        return 0.0
    }
    
    /// GPU 사용량 측정 (추정)
    @MainActor
    func getCurrentGPUUsage() -> Double {
        // Metal 성능 카운터를 통한 GPU 사용량 추정
        // 실제 구현에서는 Metal Performance Shaders 활용
        return min(currentCPUUsage * 0.6, 90.0) // 추정치
    }
    
}
