import Foundation
import ScreenCaptureKit
import CoreGraphics
import Shared

public final class ScreenShield: @unchecked Sendable {
    private var config: CloakConfig
    private let ruleEngine: AppRuleEngine

    public init(config: CloakConfig, ruleEngine: AppRuleEngine = AppRuleEngine()) {
        self.config = config
        self.ruleEngine = ruleEngine
        ruleEngine.loadBundledRules()
    }

    public func updateConfig(_ config: CloakConfig) {
        self.config = config
    }

    public func captureFilteredScreenshot() async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw CloakError.noDisplay
        }

        let blockedApps = content.applications.filter { app in
            !config.allowedBundleIDs.contains(app.bundleIdentifier) ||
            CloakConstants.alwaysBlockedBundleIDs.contains(app.bundleIdentifier)
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: blockedApps,
            exceptingWindows: []
        )

        let streamConfig = SCStreamConfiguration()
        streamConfig.width = display.width * 2
        streamConfig.height = display.height * 2
        streamConfig.scalesToFit = false
        streamConfig.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: streamConfig
        )

        let maskedImage = applyZoneMasks(to: image, windows: content.windows)
        return maskedImage
    }

    public func captureApp(bundleID: String) async throws -> CGImage {
        guard config.allowedBundleIDs.contains(bundleID),
              !CloakConstants.alwaysBlockedBundleIDs.contains(bundleID) else {
            throw CloakError.appBlocked(bundleID)
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw CloakError.noDisplay
        }

        guard let app = content.applications.first(where: { $0.bundleIdentifier == bundleID }) else {
            throw CloakError.appNotRunning(bundleID)
        }

        let appWindows = content.windows.filter { $0.owningApplication?.bundleIdentifier == bundleID }

        let filter = SCContentFilter(
            display: display,
            including: [app],
            exceptingWindows: []
        )

        let streamConfig = SCStreamConfiguration()
        streamConfig.width = display.width * 2
        streamConfig.height = display.height * 2

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: streamConfig
        )

        return applyZoneMasks(to: image, windows: appWindows)
    }

    public func listRunningApps() async throws -> [RunningApp] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return content.applications.map { app in
            RunningApp(
                name: app.applicationName,
                bundleID: app.bundleIdentifier,
                isAllowed: config.allowedBundleIDs.contains(app.bundleIdentifier),
                isAlwaysBlocked: CloakConstants.alwaysBlockedBundleIDs.contains(app.bundleIdentifier)
            )
        }
    }

    private func applyZoneMasks(to image: CGImage, windows: [SCWindow]) -> CGImage {
        let width = image.width
        let height = image.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        let fullRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(image, in: fullRect)

        context.setFillColor(CGColor(gray: 0.4, alpha: 1.0))

        for window in windows {
            guard let bundleID = window.owningApplication?.bundleIdentifier else { continue }
            let blockedZones = ruleEngine.blockedZones(for: bundleID)

            let windowFrame = window.frame
            for zone in blockedZones {
                let zoneRect = zone.resolveRect(in: windowFrame)
                let scaledRect = CGRect(
                    x: zoneRect.origin.x * CGFloat(width) / CGFloat(windowFrame.width),
                    y: zoneRect.origin.y * CGFloat(height) / CGFloat(windowFrame.height),
                    width: zoneRect.width * CGFloat(width) / CGFloat(windowFrame.width),
                    height: zoneRect.height * CGFloat(height) / CGFloat(windowFrame.height)
                )
                context.fill(scaledRect)
            }
        }

        return context.makeImage() ?? image
    }
}

public struct RunningApp: Sendable {
    public let name: String
    public let bundleID: String
    public let isAllowed: Bool
    public let isAlwaysBlocked: Bool
}

public enum CloakError: Error, LocalizedError {
    case noDisplay
    case appBlocked(String)
    case appNotRunning(String)
    case fileBlocked(String)
    case captureError(String)

    public var errorDescription: String? {
        switch self {
        case .noDisplay: return "No display found"
        case .appBlocked(let id): return "App blocked by CloakShot: \(id)"
        case .appNotRunning(let id): return "App not running: \(id)"
        case .fileBlocked(let path): return "File blocked by CloakShot: \(path)"
        case .captureError(let msg): return "Capture error: \(msg)"
        }
    }
}
