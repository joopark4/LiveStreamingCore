//
//  StreamingLogger.swift
//  USBExternalCamera
//
//  Created by EUN YEON on 6/5/25.
//

import Foundation
import os.log
import Combine

// MARK: - Streaming Logger

/// 스트리밍 전용 로깅 매니저
public class StreamingLogger: ObservableObject {
    
    /// 싱글톤 인스턴스
    public static let shared = StreamingLogger()
    
    /// 로그 레벨
    public enum LogLevel: String, CaseIterable {
        case debug = "🔍 DEBUG"
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"
        case critical = "🔥 CRITICAL"
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }
    
    /// 로그 카테고리
    public enum LogCategory: String, CaseIterable {
        case streaming = "🎥 STREAMING"
        case network = "📡 NETWORK"
        case audio = "🎵 AUDIO"
        case video = "📹 VIDEO"
        case connection = "🔗 CONNECTION"
        case performance = "⚡ PERFORMANCE"
        case ui = "🖼️ UI"
        case system = "⚙️ SYSTEM"
    }
    
    /// 로그 엔트리
    public struct LogEntry {
        public let id = UUID()
        public let timestamp: Date
        public let level: LogLevel
        public let category: LogCategory
        public let message: String
        public let function: String
        public let file: String
        public let line: Int
        
        public var formattedMessage: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            formatter.dateStyle = .none
            
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            return "[\(formatter.string(from: timestamp))] \(level.rawValue) \(category.rawValue) \(message) (\(fileName):\(line))"
        }
    }
    
    // MARK: - Properties
    
    /// 현재 로그 엔트리들
    @Published public private(set) var logEntries: [LogEntry] = []
    
    /// 최대 로그 저장 개수
    public var maxLogEntries: Int = 1000
    
    /// 로그 파일 URL
    private var logFileURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("streaming_logs.txt")
    }
    
    /// OS Logger
    private let osLogger = Logger(subsystem: "com.heavyarm.USBExternalCamera", category: "Streaming")
    
    // MARK: - Initialization
    
    private init() {
        setupLogFile()
    }
    
    // MARK: - Public Methods
    
    /// 로그 기록
    public func log(
        level: LogLevel,
        category: LogCategory,
        message: String,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            function: function,
            file: file,
            line: line
        )
        
        // UI 업데이트
        Task { @MainActor in
            addLogEntry(entry)
        }
        
        // OS 로그
        osLogger.log(level: level.osLogType, "\(category.rawValue) \(message)")
        
        // 파일 로그
        writeToFile(entry)
        
        // 콘솔 출력 (디버그 모드에서)
        #if DEBUG
                    print(entry.formattedMessage) // StreamingLogger에서는 직접 print 사용 (무한 루프 방지)
        #endif
    }
    
    /// 디버그 로그 (성능 최적화를 위해 비활성화됨)
    /// - Note: 릴리즈 빌드에서 로그 오버헤드 방지를 위해 구현 비활성화
    public func debug(
        _ message: String,
        category: LogCategory = .system,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        // 성능 최적화: 디버그 로그 비활성화
        // log(level: .debug, category: category, message: message, function: function, file: file, line: line)
    }
    
    /// 정보 로그
    public func info(
        _ message: String,
        category: LogCategory = .system,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .info, category: category, message: message, function: function, file: file, line: line)
    }
    
    /// 경고 로그
    public func warning(
        _ message: String,
        category: LogCategory = .system,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .warning, category: category, message: message, function: function, file: file, line: line)
    }
    
    /// 에러 로그
    public func error(
        _ message: String,
        category: LogCategory = .system,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .error, category: category, message: message, function: function, file: file, line: line)
    }
    
    /// 치명적 에러 로그
    public func critical(
        _ message: String,
        category: LogCategory = .system,
        function: String = #function,
        file: String = #file,
        line: Int = #line
    ) {
        log(level: .critical, category: category, message: message, function: function, file: file, line: line)
    }
    
    /// RTMP 연결 시작 로그
    public func logRTMPConnectionStart(url: String, streamKey: String) {
        info("🚀 RTMP 연결 시작", category: .connection)
        info("📍 RTMP URL: \(url)", category: .connection)
        info("🔑 Stream Key: \(streamKey.prefix(8))...", category: .connection)
    }
    
    /// RTMP 연결 성공 로그
    public func logRTMPConnectionSuccess(url: String, latency: Int) {
        info("✅ RTMP 연결 성공", category: .connection)
        info("📍 Connected to: \(url)", category: .connection)
        info("⏱️ Connection latency: \(latency)ms", category: .performance)
    }
    
    /// RTMP 연결 실패 로그
    public func logRTMPConnectionFailure(url: String, error: Error) {
        self.error("❌ RTMP 연결 실패", category: .connection)
        self.error("📍 Failed URL: \(url)", category: .connection)
        self.error("💥 Error: \(error.localizedDescription)", category: .connection)
    }
    
    /// 스트리밍 성능 로그
    public func logStreamingPerformance(
        videoBitrate: Double,
        audioBitrate: Double,
        fps: Double,
        droppedFrames: Int
    ) {
        info("📊 스트리밍 성능 통계", category: .performance)
        info("🎥 Video Bitrate: \(String(format: "%.1f", videoBitrate)) kbps", category: .performance)
        info("🎵 Audio Bitrate: \(String(format: "%.1f", audioBitrate)) kbps", category: .performance)
        info("🎞️ FPS: \(String(format: "%.1f", fps))", category: .performance)
        
        if droppedFrames > 0 {
            warning("⚠️ Dropped Frames: \(droppedFrames)", category: .performance)
        }
    }
    
    /// 네트워크 품질 로그
    public func logNetworkQuality(quality: NetworkQuality, latency: Int, bandwidth: Double) {
        info("📡 네트워크 품질: \(quality.displayName)", category: .network)
        info("⏱️ Latency: \(latency)ms", category: .network)
        info("📶 Bandwidth: \(String(format: "%.1f", bandwidth)) Mbps", category: .network)
    }
    
    /// 로그 초기화
    public func clearLogs() {
        Task { @MainActor in
            logEntries.removeAll()
        }
        try? FileManager.default.removeItem(at: logFileURL)
        setupLogFile()
        info("🗑️ 로그가 초기화되었습니다", category: .system)
    }
    
    /// 로그 내보내기
    public func exportLogs() -> String {
        return logEntries.map { $0.formattedMessage }.joined(separator: "\n")
    }
    
    /// 로그 파일 공유
    public func getLogFileURL() -> URL {
        return logFileURL
    }
    
    /// 특정 카테고리 로그 필터링
    public func getFilteredLogs(category: LogCategory) -> [LogEntry] {
        return logEntries.filter { $0.category == category }
    }
    
    /// 특정 레벨 이상 로그 필터링
    public func getFilteredLogs(minLevel: LogLevel) -> [LogEntry] {
        let levels: [LogLevel] = [.debug, .info, .warning, .error, .critical]
        guard let minIndex = levels.firstIndex(of: minLevel) else { return [] }
        
        let validLevels = Array(levels[minIndex...])
        return logEntries.filter { validLevels.contains($0.level) }
    }
    
    // MARK: - Private Methods
    
    /// 로그 엔트리 추가
    @MainActor
    private func addLogEntry(_ entry: LogEntry) {
        logEntries.append(entry)
        
        // 최대 개수 초과시 오래된 로그 삭제
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
    }
    
    /// 로그 파일 설정
    private func setupLogFile() {
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
    }
    
    /// 파일에 로그 작성
    private func writeToFile(_ entry: LogEntry) {
        let logLine = entry.formattedMessage + "\n"
        
        guard let data = logLine.data(using: .utf8) else { return }
        
        if let fileHandle = FileHandle(forWritingAtPath: logFileURL.path) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        }
    }
}

// MARK: - Convenience Extensions

extension StreamingLogger {
    
    /// HaishinKit 이벤트 로깅
    public func logHaishinKitEvent(_ event: String, details: [String: Any] = [:]) {
        var message = "📦 HaishinKit Event: \(event)"
        
        if !details.isEmpty {
            let detailsString = details.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            message += " - \(detailsString)"
        }
        
        info(message, category: .streaming)
    }
    
    /// 비디오 설정 로깅
    public func logVideoSettings(width: Int, height: Int, fps: Int, bitrate: Int) {
        info("📹 비디오 설정 구성", category: .video)
        info("📐 해상도: \(width)x\(height)", category: .video)
        info("🎞️ FPS: \(fps)", category: .video)
        info("📊 비트레이트: \(bitrate) kbps", category: .video)
    }
    
    /// 오디오 설정 로깅
    public func logAudioSettings(sampleRate: Int, channels: Int, bitrate: Int) {
        info("🎵 오디오 설정 구성", category: .audio)
        info("🔊 샘플레이트: \(sampleRate) Hz", category: .audio)
        info("📢 채널: \(channels)", category: .audio)
        info("📊 비트레이트: \(bitrate) kbps", category: .audio)
    }
} 
