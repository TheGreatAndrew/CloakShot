import Foundation

public enum CloakConstants {
    public static let appName = "CloakShot"

    public static let alwaysBlockedPaths: [String] = [
        "/.ssh",
        "/.gnupg",
        "/.gpg",
        "/.aws",
        "/.azure",
        "/.config/gcloud",
        "/Library/Keychains",
        "/.env",
        "/.netrc",
        "/.npmrc",
        "/.pypirc",
        "/.docker/config.json",
        "/.kube/config",
    ]

    public static let alwaysBlockedBundleIDs: Set<String> = [
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.lastpass.LastPass",
        "com.bitwarden.desktop",
        "com.dashlane.dashlanephonefinal",
    ]

    public static let mcpSocketPath: String = {
        let tmp = NSTemporaryDirectory()
        return (tmp as NSString).appendingPathComponent("cloakshot.sock")
    }()

    public static let mcpPort: UInt16 = 51983
}
