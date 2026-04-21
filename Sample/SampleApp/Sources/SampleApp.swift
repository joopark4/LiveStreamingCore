// LiveStreamingSampleApp - Sample code demonstrating LiveStreamingCore usage
// This file shows how to use the LiveStreamingCore library in an iOS app

import Foundation
import SwiftUI
import LiveStreamingCore

// MARK: - Sample Usage Examples

/// Demonstrates how to configure streaming settings
public struct SettingsExample {

    /// Create default settings
    public static func createDefaultSettings() -> LiveStreamingCoreNamespace.LiveStreamSettings {
        var settings = LiveStreamingCoreNamespace.LiveStreamSettings()
        settings.rtmpURL = "rtmp://a.rtmp.youtube.com/live2"
        settings.streamKey = "your-stream-key"
        settings.videoBitrate = 2500
        settings.audioBitrate = 128
        settings.videoWidth = 1280
        settings.videoHeight = 720
        settings.frameRate = 30
        return settings
    }

    /// Apply YouTube preset
    public static func applyYouTubePreset(_ preset: YouTubeLivePreset) -> LiveStreamingCoreNamespace.LiveStreamSettings {
        var settings = LiveStreamingCoreNamespace.LiveStreamSettings()
        settings.applyYouTubeLivePreset(preset)
        return settings
    }

    /// Detect current preset from settings
    public static func detectPreset(from settings: LiveStreamingCoreNamespace.LiveStreamSettings) -> YouTubeLivePreset? {
        return settings.detectYouTubePreset()
    }
}

/// Demonstrates YouTube preset usage
public struct PresetExample {

    /// Get all available presets with their details
    public static func getAllPresets() -> [(preset: YouTubeLivePreset, details: String)] {
        let presets: [YouTubeLivePreset] = [.sd480p, .hd720p, .fhd1080p]

        return presets.map { preset in
            let s = preset.settings
            let details = "\(preset.displayName): \(s.width)x\(s.height) @ \(s.frameRate)fps, \(s.videoBitrate)kbps"
            return (preset, details)
        }
    }

    /// Print preset information
    public static func printPresetInfo() {
        print("Available YouTube Live Presets:")
        print("─────────────────────────────────")
        for (_, details) in getAllPresets() {
            print("  • \(details)")
        }
    }
}

/// Demonstrates stream statistics monitoring
public struct StatisticsExample {

    /// Create and configure stream stats
    public static func createStreamStats() -> StreamStats {
        let stats = StreamStats()
        return stats
    }

    /// Simulate updating stats
    public static func simulateStats(_ stats: StreamStats) {
        stats.startStreaming()
        stats.updateStats(
            videoBitrate: 2450.0,
            audioBitrate: 128.0,
            frameRate: 29.8,
            droppedFrames: 3,
            latency: 45.0,
            packetLoss: 0.1
        )
    }

    /// Get quality status description
    public static func getQualityDescription(_ stats: StreamStats) -> String {
        let status = stats.qualityStatus
        return "\(status.emoji) \(status.displayName)"
    }
}

/// Demonstrates validation usage
public struct ValidationExample {

    /// Validate RTMP URL using the library's throwing API
    public static func validateURL(_ url: String) -> Bool {
        do {
            try StreamingValidation.validateRTMPURL(url)
            return true
        } catch {
            return false
        }
    }

    /// Validate bitrate using the library's throwing API
    public static func validateBitrate(_ bitrate: Int) -> Bool {
        do {
            try StreamingValidation.validateBitrates(videoBitrate: bitrate, audioBitrate: 128)
            return true
        } catch {
            return false
        }
    }

    /// Validate resolution using the library's throwing API
    public static func validateResolution(width: Int, height: Int) -> Bool {
        do {
            try StreamingValidation.validateResolution(width: width, height: height)
            return true
        } catch {
            return false
        }
    }

    /// Validate frame rate using the library's throwing API
    public static func validateFrameRate(_ fps: Int) -> Bool {
        do {
            try StreamingValidation.validateFrameRate(fps)
            return true
        } catch {
            return false
        }
    }

    /// Validate all settings
    public static func validateSettings(_ settings: LiveStreamingCoreNamespace.LiveStreamSettings) -> (isValid: Bool, issues: [String]) {
        var issues: [String] = []

        if !validateURL(settings.rtmpURL) {
            issues.append("Invalid RTMP URL")
        }
        if settings.streamKey.isEmpty {
            issues.append("Stream key is empty")
        }
        if !validateBitrate(settings.videoBitrate) {
            issues.append("Invalid video bitrate")
        }
        if !validateResolution(width: settings.videoWidth, height: settings.videoHeight) {
            issues.append("Invalid resolution")
        }
        if !validateFrameRate(settings.frameRate) {
            issues.append("Invalid frame rate")
        }

        return (issues.isEmpty, issues)
    }
}

/// Demonstrates diagnosis report usage
public struct DiagnosisExample {

    /// Create a sample diagnosis report
    public static func createSampleReport() -> StreamingDiagnosisReport {
        var report = StreamingDiagnosisReport()

        // Simulate validation results
        report.configValidation.isValid = true
        report.configValidation.validItems = ["RTMP URL", "Stream Key", "Bitrate"]

        report.networkStatus.isValid = true
        report.networkStatus.validItems = ["Connection", "Latency"]

        report.mediaMixerStatus.isValid = true
        report.rtmpStreamStatus.isValid = true
        report.screenCaptureStatus.isValid = true
        report.deviceStatus.isValid = true
        report.dataFlowStatus.isValid = true

        report.calculateOverallScore()

        return report
    }

    /// Get report summary
    public static func getReportSummary(_ report: StreamingDiagnosisReport) -> String {
        return """
        Diagnosis Report:
          Score: \(report.overallScore)/100
          Grade: \(report.overallGrade)
          Recommendation: \(report.getRecommendation())
        """
    }
}

/// Demonstrates text overlay settings
public struct TextOverlayExample {

    /// Create default text overlay
    public static func createDefaultOverlay() -> TextOverlaySettings {
        return TextOverlaySettings(
            text: "LIVE",
            fontSize: 24.0,
            textColor: .red,
            fontName: "System Bold"
        )
    }

    /// Get all available fonts
    public static func getAvailableFonts() -> [String] {
        return ["System", "System Bold", "Helvetica", "Arial"]
    }

    /// Get all available colors
    public static func getAvailableColors() -> [String] {
        return ["white", "black", "red", "blue", "green", "yellow"]
    }
}

/// Demonstrates connection info usage
public struct ConnectionExample {

    /// Create sample connection info
    public static func createSampleConnectionInfo() -> ConnectionInfo {
        return ConnectionInfo(
            serverAddress: "a.rtmp.youtube.com",
            port: 1935,
            status: .connected
        )
    }

    /// Get connection status description
    public static func getStatusDescription(_ info: ConnectionInfo) -> String {
        return """
        Connection Status:
          Status: \(info.status.displayName)
          Server: \(info.serverAddress):\(info.port)
          Latency: \(info.connectionLatency)ms
          Quality: \(info.connectionQuality.displayName)
        """
    }
}

// MARK: - Demo Runner

/// Run all sample demonstrations
public struct SampleDemo {

    public static func runAllDemos() {
        print("╔═══════════════════════════════════════════════════════════════╗")
        print("║         LiveStreamingCore Sample Demonstrations                ║")
        print("╚═══════════════════════════════════════════════════════════════╝")
        print("")

        // 1. Settings Demo
        print("📋 1. Settings Configuration")
        print("─────────────────────────────")
        let settings = SettingsExample.createDefaultSettings()
        print("  RTMP URL: \(settings.rtmpURL)")
        print("  Resolution: \(settings.videoWidth)x\(settings.videoHeight)")
        print("  Bitrate: \(settings.videoBitrate) kbps")
        print("")

        // 2. Presets Demo
        print("🎬 2. YouTube Presets")
        print("─────────────────────")
        PresetExample.printPresetInfo()
        print("")

        // 3. Statistics Demo
        print("📊 3. Stream Statistics")
        print("───────────────────────")
        let stats = StatisticsExample.createStreamStats()
        StatisticsExample.simulateStats(stats)
        print("  Quality: \(StatisticsExample.getQualityDescription(stats))")
        print("  Bitrate: \(stats.videoBitrate) kbps")
        print("  FPS: \(stats.frameRate)")
        print("")

        // 4. Validation Demo
        print("✅ 4. Validation")
        print("────────────────")
        let (isValid, issues) = ValidationExample.validateSettings(settings)
        print("  Settings valid: \(isValid)")
        if !issues.isEmpty {
            print("  Issues: \(issues.joined(separator: ", "))")
        }
        print("")

        // 5. Diagnosis Demo
        print("📝 5. Diagnosis Report")
        print("──────────────────────")
        let report = DiagnosisExample.createSampleReport()
        print(DiagnosisExample.getReportSummary(report))
        print("")

        // 6. Text Overlay Demo
        print("🎨 6. Text Overlay")
        print("──────────────────")
        let overlay = TextOverlayExample.createDefaultOverlay()
        print("  Text: \(overlay.text)")
        print("  Font: \(overlay.fontName)")
        print("  Color: \(overlay.textColor)")
        print("  Available Fonts: \(TextOverlayExample.getAvailableFonts().joined(separator: ", "))")
        print("")

        // 7. Connection Demo
        print("🔗 7. Connection Info")
        print("─────────────────────")
        let connection = ConnectionExample.createSampleConnectionInfo()
        print(ConnectionExample.getStatusDescription(connection))
        print("")

        print("═══════════════════════════════════════════════════════════════")
        print("✅ All demonstrations completed successfully!")
        print("═══════════════════════════════════════════════════════════════")
    }
}
