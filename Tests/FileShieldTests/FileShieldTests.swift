import Testing
@testable import FileShield
@testable import Shared

@Suite("FileShield")
struct FileShieldTests {

    @Test func allowedPath() {
        let config = CloakConfig(allowedFolders: ["/Users/test/Projects"])
        let shield = FileShield(config: config)

        #expect(shield.isPathAllowed("/Users/test/Projects/app/main.swift") == true)
        #expect(shield.isPathAllowed("/Users/test/Projects") == true)
        #expect(shield.isPathAllowed("/Users/test/Documents/taxes.pdf") == false)
    }

    @Test func alwaysBlockedPaths() {
        let config = CloakConfig(allowedFolders: ["/Users/test"])
        let shield = FileShield(config: config)

        #expect(shield.isPathAllowed("/Users/test/.ssh/id_rsa") == false)
        #expect(shield.isPathAllowed("/Users/test/.aws/credentials") == false)
        #expect(shield.isPathAllowed("/Users/test/.gnupg/private-keys") == false)
        #expect(shield.isPathAllowed("/Users/test/.env") == false)
    }

    @Test func emptyAllowlistBlocksEverything() {
        let config = CloakConfig()
        let shield = FileShield(config: config)

        #expect(shield.isPathAllowed("/Users/test/anything") == false)
        #expect(shield.isPathAllowed("/tmp/test") == false)
    }

    @Test func filterPaths() {
        let config = CloakConfig(allowedFolders: ["/Users/test/Projects"])
        let shield = FileShield(config: config)

        let result = shield.filterPaths([
            "/Users/test/Projects/app.swift",
            "/Users/test/Documents/secret.txt",
            "/Users/test/Projects/lib/util.swift",
        ])

        #expect(result.allowed.count == 2)
        #expect(result.blocked.count == 1)
    }

    @Test func extractPathsFromCommand() {
        let config = CloakConfig()
        let shield = FileShield(config: config)

        let paths = shield.extractPathsFromCommand("cat /Users/test/file.txt")
        #expect(paths == ["/Users/test/file.txt"])

        let paths2 = shield.extractPathsFromCommand("grep -r 'pattern' /Users/test/src/")
        #expect(paths2 == ["/Users/test/src/"])

        let paths3 = shield.extractPathsFromCommand("ls ~/Documents")
        #expect(paths3 == ["~/Documents"])
    }

    @Test func checkCommandBlocked() {
        let config = CloakConfig(allowedFolders: ["/Users/test/Projects"])
        let shield = FileShield(config: config)

        let result = shield.checkCommand("cat /Users/test/.ssh/id_rsa")
        if case .blocked(let paths) = result {
            #expect(paths.contains("/Users/test/.ssh/id_rsa"))
        } else {
            Issue.record("Expected blocked result")
        }
    }

    @Test func checkCommandAllowed() {
        let config = CloakConfig(allowedFolders: ["/Users/test/Projects"])
        let shield = FileShield(config: config)

        let result = shield.checkCommand("cat /Users/test/Projects/main.swift")
        if case .allowed = result {
            // pass
        } else {
            Issue.record("Expected allowed result")
        }
    }

    @Test func checkCommandNoPaths() {
        let config = CloakConfig()
        let shield = FileShield(config: config)

        let result = shield.checkCommand("echo hello")
        if case .noPaths = result {
            // pass
        } else {
            Issue.record("Expected noPaths result")
        }
    }

    @Test func tildePath() {
        let config = CloakConfig(allowedFolders: ["~/Projects"])
        let shield = FileShield(config: config)

        let home = NSHomeDirectory()
        #expect(shield.isPathAllowed("\(home)/Projects/app.swift") == true)
    }
}
