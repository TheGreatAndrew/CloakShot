import Testing
@testable import ScreenShield
@testable import Shared

@Suite("Config")
struct ConfigTests {

    @Test func defaultConfig() {
        let config = CloakConfig()
        #expect(config.allowedBundleIDs.isEmpty)
        #expect(config.allowedFolders.isEmpty)
        #expect(config.secretStrings.isEmpty)
        #expect(config.shieldEnabled == true)
    }

    @Test func addAndRemoveBundleID() {
        var config = CloakConfig()
        config.allowedBundleIDs.insert("com.google.Chrome")

        #expect(config.allowedBundleIDs.contains("com.google.Chrome"))
        #expect(!config.allowedBundleIDs.contains("com.apple.mail"))

        config.allowedBundleIDs.remove("com.google.Chrome")
        #expect(!config.allowedBundleIDs.contains("com.google.Chrome"))
    }

    @Test func configEquality() {
        let a = CloakConfig(allowedBundleIDs: ["com.test"], allowedFolders: ["/tmp"])
        let b = CloakConfig(allowedBundleIDs: ["com.test"], allowedFolders: ["/tmp"])
        #expect(a == b)
    }

    @Test func alwaysBlockedApps() {
        #expect(CloakConstants.alwaysBlockedBundleIDs.contains("com.1password.1password"))
        #expect(CloakConstants.alwaysBlockedBundleIDs.contains("com.bitwarden.desktop"))
    }
}

@Suite("AppRule")
struct AppRuleTests {

    @Test func zoneResolution() {
        let zone = AppZone(
            name: "sidebar",
            action: .block,
            region: .left,
            widthRatio: 0.25,
            heightRatio: nil
        )

        let windowFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let rect = zone.resolveRect(in: windowFrame)

        #expect(rect.origin.x == 0)
        #expect(rect.width == 250)
        #expect(rect.height == 800)
    }

    @Test func centerZone() {
        let zone = AppZone(
            name: "content",
            action: .allow,
            region: .center,
            widthRatio: 0.6,
            heightRatio: 0.8
        )

        let windowFrame = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let rect = zone.resolveRect(in: windowFrame)

        #expect(rect.width == 600)
        #expect(rect.height == 640)
        #expect(rect.origin.x == 200)
        #expect(rect.origin.y == 80)
    }
}
