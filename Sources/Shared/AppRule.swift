import Foundation
import Yams

public enum ZoneAction: String, Codable {
    case allow
    case block
}

public enum RegionAnchor: String, Codable {
    case top
    case bottom
    case left
    case right
    case center
    case topLeft = "top_left"
    case topRight = "top_right"
    case bottomLeft = "bottom_left"
    case bottomRight = "bottom_right"
}

public struct AppZone: Codable {
    public let name: String
    public let action: ZoneAction
    public let region: RegionAnchor
    public var widthRatio: CGFloat?
    public var heightRatio: CGFloat?

    enum CodingKeys: String, CodingKey {
        case name, action, region
        case widthRatio = "width_ratio"
        case heightRatio = "height_ratio"
    }

    public func resolveRect(in windowFrame: CGRect) -> CGRect {
        let w = windowFrame.width
        let h = windowFrame.height

        let zoneW: CGFloat
        let zoneH: CGFloat
        let zoneX: CGFloat
        let zoneY: CGFloat

        switch region {
        case .top:
            zoneW = widthRatio.map { $0 * w } ?? w
            zoneH = heightRatio.map { $0 * h } ?? (h * 0.1)
            zoneX = (w - zoneW) / 2
            zoneY = 0
        case .bottom:
            zoneW = widthRatio.map { $0 * w } ?? w
            zoneH = heightRatio.map { $0 * h } ?? (h * 0.1)
            zoneX = (w - zoneW) / 2
            zoneY = h - zoneH
        case .left:
            zoneW = widthRatio.map { $0 * w } ?? (w * 0.25)
            zoneH = heightRatio.map { $0 * h } ?? h
            zoneX = 0
            zoneY = 0
        case .right:
            zoneW = widthRatio.map { $0 * w } ?? (w * 0.25)
            zoneH = heightRatio.map { $0 * h } ?? h
            zoneX = w - zoneW
            zoneY = 0
        case .center:
            zoneW = widthRatio.map { $0 * w } ?? (w * 0.5)
            zoneH = heightRatio.map { $0 * h } ?? (h * 0.8)
            zoneX = (w - zoneW) / 2
            zoneY = (h - zoneH) / 2
        case .topLeft:
            zoneW = widthRatio.map { $0 * w } ?? (w * 0.25)
            zoneH = heightRatio.map { $0 * h } ?? (h * 0.1)
            zoneX = 0
            zoneY = 0
        case .topRight:
            zoneW = widthRatio.map { $0 * w } ?? (w * 0.25)
            zoneH = heightRatio.map { $0 * h } ?? (h * 0.1)
            zoneX = w - zoneW
            zoneY = 0
        case .bottomLeft:
            zoneW = widthRatio.map { $0 * w } ?? (w * 0.25)
            zoneH = heightRatio.map { $0 * h } ?? (h * 0.1)
            zoneX = 0
            zoneY = h - zoneH
        case .bottomRight:
            zoneW = widthRatio.map { $0 * w } ?? (w * 0.25)
            zoneH = heightRatio.map { $0 * h } ?? (h * 0.1)
            zoneX = w - zoneW
            zoneY = h - zoneH
        }

        return CGRect(x: zoneX, y: zoneY, width: zoneW, height: zoneH)
    }
}

public struct AppRule: Codable {
    public let appName: String
    public let bundleID: String
    public let defaultAction: ZoneAction
    public let zones: [AppZone]

    enum CodingKeys: String, CodingKey {
        case appName = "app_name"
        case bundleID = "bundle_id"
        case defaultAction = "default"
        case zones
    }

    public init(appName: String, bundleID: String, defaultAction: ZoneAction, zones: [AppZone]) {
        self.appName = appName
        self.bundleID = bundleID
        self.defaultAction = defaultAction
        self.zones = zones
    }
}

public final class AppRuleEngine {
    public private(set) var rules: [String: AppRule] = [:]

    public init() {}

    public func loadRules(from directory: URL) throws {
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesConforming: nil
        )
        for file in files where file.pathExtension == "yaml" || file.pathExtension == "yml" {
            let contents = try String(contentsOf: file, encoding: .utf8)
            let rule = try YAMLDecoder().decode(AppRule.self, from: contents)
            rules[rule.bundleID] = rule
        }
    }

    public func loadBundledRules() {
        guard let resourceURL = Bundle.module.url(forResource: "AppRules", withExtension: nil) else { return }
        try? loadRules(from: resourceURL)
    }

    public func rule(for bundleID: String) -> AppRule? {
        rules[bundleID]
    }

    public func defaultAction(for bundleID: String) -> ZoneAction {
        rules[bundleID]?.defaultAction ?? .block
    }

    public func blockedZones(for bundleID: String) -> [AppZone] {
        guard let rule = rules[bundleID] else { return [] }
        return rule.zones.filter { $0.action == .block }
    }

    public func allowedZones(for bundleID: String) -> [AppZone] {
        guard let rule = rules[bundleID] else { return [] }
        return rule.zones.filter { $0.action == .allow }
    }
}
