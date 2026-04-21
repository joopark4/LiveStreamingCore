import XCTest
import SwiftUI
@testable import LiveStreamingSampleApp
@testable import LiveStreamingCore

final class SampleAppTests: XCTestCase {

    // MARK: - Settings Example Tests

    func testCreateDefaultSettings() {
        let settings = SettingsExample.createDefaultSettings()

        XCTAssertEqual(settings.rtmpURL, "rtmp://a.rtmp.youtube.com/live2")
        XCTAssertEqual(settings.streamKey, "your-stream-key")
        XCTAssertEqual(settings.videoBitrate, 2500)
        XCTAssertEqual(settings.audioBitrate, 128)
        XCTAssertEqual(settings.videoWidth, 1280)
        XCTAssertEqual(settings.videoHeight, 720)
        XCTAssertEqual(settings.frameRate, 30)
    }

    func testApplyYouTubePreset() {
        let settings = SettingsExample.applyYouTubePreset(.hd720p)

        XCTAssertEqual(settings.videoWidth, 1280)
        XCTAssertEqual(settings.videoHeight, 720)
        XCTAssertEqual(settings.frameRate, 30)
        XCTAssertEqual(settings.videoBitrate, 2500)
    }

    func testDetectPreset() {
        var settings = LiveStreamingCoreNamespace.LiveStreamSettings()
        settings.applyYouTubeLivePreset(.fhd1080p)

        let detected = SettingsExample.detectPreset(from: settings)
        XCTAssertEqual(detected, .fhd1080p)
    }

    // MARK: - Preset Example Tests

    func testGetAllPresets() {
        let presets = PresetExample.getAllPresets()

        XCTAssertEqual(presets.count, 3)
        XCTAssertEqual(presets[0].preset, .sd480p)
        XCTAssertEqual(presets[1].preset, .hd720p)
        XCTAssertEqual(presets[2].preset, .fhd1080p)
    }

    // MARK: - Statistics Example Tests

    func testCreateStreamStats() {
        let stats = StatisticsExample.createStreamStats()

        XCTAssertNotNil(stats)
        XCTAssertNil(stats.startTime) // 아직 스트리밍 시작 전이므로 startTime이 nil
    }

    func testSimulateStats() {
        let stats = StatisticsExample.createStreamStats()
        StatisticsExample.simulateStats(stats)

        XCTAssertNotNil(stats.startTime) // isStreaming이 없으므로 startTime으로 확인
        XCTAssertEqual(stats.videoBitrate, 2450.0)
        XCTAssertEqual(stats.audioBitrate, 128.0)
        XCTAssertEqual(stats.frameRate, 29.8)
        XCTAssertEqual(stats.droppedFrames, 3)
        XCTAssertEqual(stats.latency, 45.0)
    }

    func testQualityDescription() {
        let stats = StatisticsExample.createStreamStats()
        StatisticsExample.simulateStats(stats)

        let description = StatisticsExample.getQualityDescription(stats)
        XCTAssertFalse(description.isEmpty)
    }

    // MARK: - Validation Example Tests

    func testValidateURL() {
        XCTAssertTrue(ValidationExample.validateURL("rtmp://a.rtmp.youtube.com/live2"))
        XCTAssertTrue(ValidationExample.validateURL("rtmps://secure.stream.com/live"))
        XCTAssertFalse(ValidationExample.validateURL("http://example.com"))
        XCTAssertFalse(ValidationExample.validateURL(""))
    }

    func testValidateBitrate() {
        XCTAssertTrue(ValidationExample.validateBitrate(2500))
        XCTAssertTrue(ValidationExample.validateBitrate(1000))
        XCTAssertFalse(ValidationExample.validateBitrate(0))
        XCTAssertFalse(ValidationExample.validateBitrate(-100))
    }

    func testValidateResolution() {
        XCTAssertTrue(ValidationExample.validateResolution(width: 1280, height: 720))
        XCTAssertTrue(ValidationExample.validateResolution(width: 1920, height: 1080))
        XCTAssertFalse(ValidationExample.validateResolution(width: 0, height: 0))
    }

    func testValidateFrameRate() {
        XCTAssertTrue(ValidationExample.validateFrameRate(30))
        XCTAssertTrue(ValidationExample.validateFrameRate(60))
        XCTAssertFalse(ValidationExample.validateFrameRate(0))
        XCTAssertFalse(ValidationExample.validateFrameRate(240))
    }

    func testValidateSettings() {
        var settings = SettingsExample.createDefaultSettings()
        settings.rtmpURL = "rtmp://valid.url/live"
        settings.streamKey = "valid-key"

        let (isValid, issues) = ValidationExample.validateSettings(settings)
        XCTAssertTrue(isValid)
        XCTAssertTrue(issues.isEmpty)
    }

    func testValidateSettingsWithIssues() {
        var settings = LiveStreamingCoreNamespace.LiveStreamSettings()
        settings.rtmpURL = "invalid"
        settings.streamKey = ""

        let (isValid, issues) = ValidationExample.validateSettings(settings)
        XCTAssertFalse(isValid)
        XCTAssertFalse(issues.isEmpty)
    }

    // MARK: - Diagnosis Example Tests

    func testCreateSampleReport() {
        let report = DiagnosisExample.createSampleReport()

        XCTAssertEqual(report.overallScore, 100)
        XCTAssertEqual(report.overallGrade, "A")
        XCTAssertTrue(report.configValidation.isValid)
        XCTAssertTrue(report.networkStatus.isValid)
    }

    func testGetReportSummary() {
        let report = DiagnosisExample.createSampleReport()
        let summary = DiagnosisExample.getReportSummary(report)

        XCTAssertTrue(summary.contains("Score: 100/100"))
        XCTAssertTrue(summary.contains("Grade: A"))
    }

    // MARK: - Text Overlay Example Tests

    func testCreateDefaultOverlay() {
        let overlay = TextOverlayExample.createDefaultOverlay()

        XCTAssertEqual(overlay.text, "LIVE")
        XCTAssertEqual(overlay.fontSize, 24.0)
        XCTAssertEqual(overlay.fontName, "System Bold")
        XCTAssertEqual(overlay.textColor, .red)
    }

    func testGetAvailableFonts() {
        let fonts = TextOverlayExample.getAvailableFonts()

        XCTAssertFalse(fonts.isEmpty)
        XCTAssertTrue(fonts.contains("System"))
        XCTAssertTrue(fonts.contains("System Bold"))
    }

    func testGetAvailableColors() {
        let colors = TextOverlayExample.getAvailableColors()

        XCTAssertFalse(colors.isEmpty)
        XCTAssertTrue(colors.contains("white"))
        XCTAssertTrue(colors.contains("red"))
    }

    // MARK: - Connection Example Tests

    func testCreateSampleConnectionInfo() {
        let info = ConnectionExample.createSampleConnectionInfo()

        XCTAssertEqual(info.status, .connected)
        XCTAssertEqual(info.serverAddress, "a.rtmp.youtube.com")
        XCTAssertEqual(info.port, 1935)
    }

    func testGetStatusDescription() {
        let info = ConnectionExample.createSampleConnectionInfo()
        let description = ConnectionExample.getStatusDescription(info)

        XCTAssertTrue(description.contains("Status:"), "Should contain Status")
        XCTAssertTrue(description.contains("Server:"), "Should contain Server")
        XCTAssertTrue(description.contains("Latency:"), "Should contain Latency")
        XCTAssertTrue(description.contains("Quality:"), "Should contain Quality")
    }
}
