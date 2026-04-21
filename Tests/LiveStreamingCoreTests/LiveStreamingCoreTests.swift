import XCTest
@testable import LiveStreamingCore

final class LiveStreamingCoreTests: XCTestCase {

    // MARK: - Settings Tests

    func testLiveStreamSettingsDefaults() {
        let settings = LiveStreamingCoreNamespace.LiveStreamSettings()

        XCTAssertEqual(settings.rtmpURL, "")
        XCTAssertEqual(settings.streamKey, "")
        XCTAssertEqual(settings.videoBitrate, 2500)
        XCTAssertEqual(settings.audioBitrate, 128)
        XCTAssertEqual(settings.videoWidth, 1280)
        XCTAssertEqual(settings.videoHeight, 720)
        XCTAssertEqual(settings.frameRate, 30)
    }

    func testLiveStreamSettingsConfiguration() {
        var settings = LiveStreamingCoreNamespace.LiveStreamSettings()

        settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
        settings.streamKey = "test-key-12345"
        settings.videoBitrate = 4500
        settings.audioBitrate = 192
        settings.videoWidth = 1920
        settings.videoHeight = 1080
        settings.frameRate = 60

        XCTAssertEqual(settings.rtmpURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(settings.streamKey, "test-key-12345")
        XCTAssertEqual(settings.videoBitrate, 4500)
        XCTAssertEqual(settings.audioBitrate, 192)
        XCTAssertEqual(settings.videoWidth, 1920)
        XCTAssertEqual(settings.videoHeight, 1080)
        XCTAssertEqual(settings.frameRate, 60)
    }

    // MARK: - YouTube Presets Tests

    func testYouTubePresetSD480p() {
        let preset = YouTubeLivePreset.sd480p

        XCTAssertEqual(preset.width, 848)
        XCTAssertEqual(preset.height, 480)
        XCTAssertEqual(preset.frameRate, 30)
        XCTAssertEqual(preset.videoBitrate, 1500)
        XCTAssertEqual(preset.bitrateRange, 500)
    }

    func testYouTubePresetHD720p() {
        let preset = YouTubeLivePreset.hd720p

        XCTAssertEqual(preset.width, 1280)
        XCTAssertEqual(preset.height, 720)
        XCTAssertEqual(preset.frameRate, 30)
        XCTAssertEqual(preset.videoBitrate, 2500)
        XCTAssertEqual(preset.bitrateRange, 2500)
    }

    func testYouTubePresetFHD1080p() {
        let preset = YouTubeLivePreset.fhd1080p

        XCTAssertEqual(preset.width, 1920)
        XCTAssertEqual(preset.height, 1080)
        XCTAssertEqual(preset.frameRate, 30)
        XCTAssertEqual(preset.videoBitrate, 4500)
        XCTAssertEqual(preset.bitrateRange, 4500)
    }

    func testApplyYouTubePreset() {
        var settings = LiveStreamingCoreNamespace.LiveStreamSettings()
        settings.applyYouTubeLivePreset(.hd720p)

        XCTAssertEqual(settings.videoWidth, 1280)
        XCTAssertEqual(settings.videoHeight, 720)
        XCTAssertEqual(settings.frameRate, 30)
        XCTAssertEqual(settings.videoBitrate, 2500)
    }

    func testDetectYouTubePreset() {
        var settings = LiveStreamingCoreNamespace.LiveStreamSettings()
        settings.videoWidth = 1920
        settings.videoHeight = 1080
        settings.frameRate = 30
        settings.videoBitrate = 4500

        let detected = settings.detectYouTubePreset()
        XCTAssertEqual(detected, .fhd1080p)
    }

    // MARK: - Validation Tests

    func testValidateRTMPURL() {
        XCTAssertTrue(StreamingValidation.validateRTMPURL("rtmp://a.rtmp.youtube.com/live2"))
        XCTAssertTrue(StreamingValidation.validateRTMPURL("rtmps://secure.stream.com/live"))
        XCTAssertFalse(StreamingValidation.validateRTMPURL("http://example.com"))
        XCTAssertFalse(StreamingValidation.validateRTMPURL(""))
        XCTAssertFalse(StreamingValidation.validateRTMPURL("invalid-url"))
    }

    func testValidateBitrate() {
        XCTAssertTrue(StreamingValidation.validateBitrate(1000))
        XCTAssertTrue(StreamingValidation.validateBitrate(2500))
        XCTAssertTrue(StreamingValidation.validateBitrate(8000))
        XCTAssertFalse(StreamingValidation.validateBitrate(0))
        XCTAssertFalse(StreamingValidation.validateBitrate(-100))
        XCTAssertFalse(StreamingValidation.validateBitrate(100000))
    }

    func testValidateResolution() {
        XCTAssertTrue(StreamingValidation.validateResolution(width: 1280, height: 720))
        XCTAssertTrue(StreamingValidation.validateResolution(width: 1920, height: 1080))
        XCTAssertTrue(StreamingValidation.validateResolution(width: 3840, height: 2160))
        XCTAssertFalse(StreamingValidation.validateResolution(width: 0, height: 0))
        XCTAssertFalse(StreamingValidation.validateResolution(width: -1, height: 720))
        XCTAssertFalse(StreamingValidation.validateResolution(width: 10000, height: 10000))
    }

    func testValidateFrameRate() {
        XCTAssertTrue(StreamingValidation.validateFrameRate(24))
        XCTAssertTrue(StreamingValidation.validateFrameRate(30))
        XCTAssertTrue(StreamingValidation.validateFrameRate(60))
        XCTAssertFalse(StreamingValidation.validateFrameRate(0))
        XCTAssertFalse(StreamingValidation.validateFrameRate(-1))
        XCTAssertFalse(StreamingValidation.validateFrameRate(240))
    }

    // MARK: - Stream Stats Tests

    func testStreamStatsInitialization() {
        let stats = StreamStats()

        XCTAssertEqual(stats.currentVideoBitrate, 0)
        XCTAssertEqual(stats.currentAudioBitrate, 0)
        XCTAssertEqual(stats.currentFrameRate, 0)
        XCTAssertEqual(stats.droppedFrames, 0)
        XCTAssertEqual(stats.totalFrames, 0)
        XCTAssertFalse(stats.isStreaming)
    }

    func testStreamStatsUpdate() {
        let stats = StreamStats()
        stats.startStreaming()

        stats.currentVideoBitrate = 2500
        stats.currentAudioBitrate = 128
        stats.currentFrameRate = 30
        stats.droppedFrames = 5
        stats.totalFrames = 1000
        stats.latency = 50
        stats.packetLoss = 0.5

        XCTAssertTrue(stats.isStreaming)
        XCTAssertEqual(stats.currentVideoBitrate, 2500)
        XCTAssertEqual(stats.currentAudioBitrate, 128)
        XCTAssertEqual(stats.currentFrameRate, 30)
        XCTAssertEqual(stats.droppedFrames, 5)
        XCTAssertEqual(stats.totalFrames, 1000)
        XCTAssertEqual(stats.latency, 50)
        XCTAssertEqual(stats.packetLoss, 0.5)
    }

    func testQualityStatus() {
        let stats = StreamStats()
        stats.startStreaming()

        // Test excellent quality
        stats.currentVideoBitrate = 2500
        stats.currentFrameRate = 30
        stats.droppedFrames = 0
        stats.totalFrames = 1000
        stats.latency = 20
        stats.packetLoss = 0
        XCTAssertEqual(stats.qualityStatus, .excellent)

        // Test poor quality
        stats.droppedFrames = 100
        stats.latency = 500
        stats.packetLoss = 5.0
        XCTAssertEqual(stats.qualityStatus, .poor)
    }

    // MARK: - Text Overlay Tests

    func testTextOverlaySettingsDefaults() {
        let overlay = TextOverlaySettings()

        XCTAssertEqual(overlay.text, "")
        XCTAssertFalse(overlay.isEnabled)
        XCTAssertEqual(overlay.fontSize, 16.0)
    }

    func testTextOverlaySettingsConfiguration() {
        var overlay = TextOverlaySettings()
        overlay.text = "LIVE"
        overlay.isEnabled = true
        overlay.fontSize = 24.0
        overlay.fontName = TextOverlaySettings.FontName.systemBold.rawValue
        overlay.textColor = TextOverlaySettings.TextColor.red.rawValue

        XCTAssertEqual(overlay.text, "LIVE")
        XCTAssertTrue(overlay.isEnabled)
        XCTAssertEqual(overlay.fontSize, 24.0)
        XCTAssertEqual(overlay.fontName, "System Bold")
        XCTAssertEqual(overlay.textColor, "red")
    }

    func testFontNameDisplayNames() {
        XCTAssertEqual(TextOverlaySettings.FontName.system.displayName, "System")
        XCTAssertEqual(TextOverlaySettings.FontName.systemBold.displayName, "System Bold")
        XCTAssertEqual(TextOverlaySettings.FontName.helvetica.displayName, "Helvetica")
        XCTAssertEqual(TextOverlaySettings.FontName.arial.displayName, "Arial")
    }

    // MARK: - Connection Info Tests

    func testConnectionInfoDefaults() {
        let info = ConnectionInfo()

        XCTAssertEqual(info.status, .disconnected)
        XCTAssertEqual(info.serverURL, "")
        XCTAssertEqual(info.latency, 0)
        XCTAssertEqual(info.quality, .unknown)
    }

    func testConnectionInfoConfiguration() {
        var info = ConnectionInfo()
        info.status = .connected
        info.serverURL = "rtmp://test.server.com/live"
        info.latency = 45.0
        info.quality = .good

        XCTAssertEqual(info.status, .connected)
        XCTAssertEqual(info.serverURL, "rtmp://test.server.com/live")
        XCTAssertEqual(info.latency, 45.0)
        XCTAssertEqual(info.quality, .good)
    }

    func testConnectionStatusDisplayNames() {
        XCTAssertNotNil(ConnectionStatus.disconnected.displayName)
        XCTAssertNotNil(ConnectionStatus.connecting.displayName)
        XCTAssertNotNil(ConnectionStatus.connected.displayName)
        XCTAssertNotNil(ConnectionStatus.failed.displayName)
    }

    func testConnectionQualityDisplayNames() {
        XCTAssertNotNil(ConnectionQuality.excellent.displayName)
        XCTAssertNotNil(ConnectionQuality.good.displayName)
        XCTAssertNotNil(ConnectionQuality.fair.displayName)
        XCTAssertNotNil(ConnectionQuality.poor.displayName)
        XCTAssertNotNil(ConnectionQuality.unknown.displayName)
    }

    // MARK: - Diagnosis Report Tests

    func testDiagnosisReportDefaults() {
        let report = StreamingDiagnosisReport()

        XCTAssertTrue(report.configValidation.isValid)
        XCTAssertTrue(report.networkStatus.isValid)
        XCTAssertEqual(report.overallScore, 0)
        XCTAssertEqual(report.overallGrade, "F")
    }

    func testDiagnosisReportCalculation() {
        var report = StreamingDiagnosisReport()

        // All valid
        report.configValidation.isValid = true
        report.mediaMixerStatus.isValid = true
        report.rtmpStreamStatus.isValid = true
        report.screenCaptureStatus.isValid = true
        report.networkStatus.isValid = true
        report.deviceStatus.isValid = true
        report.dataFlowStatus.isValid = true

        report.calculateOverallScore()

        XCTAssertEqual(report.overallScore, 100)
        XCTAssertEqual(report.overallGrade, "A")
    }

    func testDiagnosisReportPartialFailure() {
        var report = StreamingDiagnosisReport()

        // Some failures
        report.configValidation.isValid = true
        report.mediaMixerStatus.isValid = true
        report.rtmpStreamStatus.isValid = false
        report.screenCaptureStatus.isValid = true
        report.networkStatus.isValid = false
        report.deviceStatus.isValid = true
        report.dataFlowStatus.isValid = true

        report.calculateOverallScore()

        // 5/7 valid = ~71%
        XCTAssertEqual(report.overallGrade, "C")
    }

    func testDiagnosisReportRecommendation() {
        var report = StreamingDiagnosisReport()

        // Grade A
        report.configValidation.isValid = true
        report.mediaMixerStatus.isValid = true
        report.rtmpStreamStatus.isValid = true
        report.screenCaptureStatus.isValid = true
        report.networkStatus.isValid = true
        report.deviceStatus.isValid = true
        report.dataFlowStatus.isValid = true
        report.calculateOverallScore()

        XCTAssertNotNil(report.getRecommendation())
        XCTAssertFalse(report.getRecommendation().isEmpty)
    }

    // MARK: - Live Stream Status Tests

    func testLiveStreamStatusValues() {
        XCTAssertNotNil(LiveStreamStatus.idle.displayName)
        XCTAssertNotNil(LiveStreamStatus.connecting.displayName)
        XCTAssertNotNil(LiveStreamStatus.connected.displayName)
        XCTAssertNotNil(LiveStreamStatus.streaming.displayName)
        XCTAssertNotNil(LiveStreamStatus.disconnecting.displayName)
        XCTAssertNotNil(LiveStreamStatus.error.displayName)
    }

    func testLiveStreamStatusIcons() {
        XCTAssertNotNil(LiveStreamStatus.idle.icon)
        XCTAssertNotNil(LiveStreamStatus.connecting.icon)
        XCTAssertNotNil(LiveStreamStatus.connected.icon)
        XCTAssertNotNil(LiveStreamStatus.streaming.icon)
        XCTAssertNotNil(LiveStreamStatus.disconnecting.icon)
        XCTAssertNotNil(LiveStreamStatus.error.icon)
    }

    // MARK: - Quality Status Tests

    func testQualityStatusValues() {
        XCTAssertNotNil(QualityStatus.excellent.displayName)
        XCTAssertNotNil(QualityStatus.good.displayName)
        XCTAssertNotNil(QualityStatus.fair.displayName)
        XCTAssertNotNil(QualityStatus.poor.displayName)
    }

    func testQualityStatusColors() {
        XCTAssertEqual(QualityStatus.excellent.color, "green")
        XCTAssertEqual(QualityStatus.good.color, "blue")
        XCTAssertEqual(QualityStatus.fair.color, "orange")
        XCTAssertEqual(QualityStatus.poor.color, "red")
    }

    func testQualityStatusEmoji() {
        XCTAssertEqual(QualityStatus.excellent.emoji, "🟢")
        XCTAssertEqual(QualityStatus.good.emoji, "🔵")
        XCTAssertEqual(QualityStatus.fair.emoji, "🟡")
        XCTAssertEqual(QualityStatus.poor.emoji, "🔴")
    }
}
