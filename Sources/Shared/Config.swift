import Foundation

public struct CloakConfig: Codable, Equatable {
    public var allowedBundleIDs: Set<String>
    public var allowedFolders: [String]
    public var secretStrings: [String]
    public var shieldEnabled: Bool

    public init(
        allowedBundleIDs: Set<String> = [],
        allowedFolders: [String] = [],
        secretStrings: [String] = [],
        shieldEnabled: Bool = true
    ) {
        self.allowedBundleIDs = allowedBundleIDs
        self.allowedFolders = allowedFolders
        self.secretStrings = secretStrings
        self.shieldEnabled = shieldEnabled
    }

    public static let configDirectory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("CloakShot")
    }()

    private static var configFileURL: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    public static func load() -> CloakConfig {
        guard let data = try? Data(contentsOf: configFileURL),
              let config = try? JSONDecoder().decode(CloakConfig.self, from: data) else {
            return CloakConfig()
        }
        return config
    }

    public func save() throws {
        try FileManager.default.createDirectory(at: Self.configDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: Self.configFileURL, options: .atomic)
    }
}
