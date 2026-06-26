import Foundation
import Shared

public final class FileShield: @unchecked Sendable {
    private var config: CloakConfig

    public init(config: CloakConfig) {
        self.config = config
    }

    public func updateConfig(_ config: CloakConfig) {
        self.config = config
    }

    public func isPathAllowed(_ path: String) -> Bool {
        let resolved = resolvePath(path)

        for blocked in CloakConstants.alwaysBlockedPaths {
            if resolved.contains(blocked) {
                return false
            }
        }

        if config.allowedFolders.isEmpty {
            return false
        }

        return config.allowedFolders.contains { folder in
            let expandedFolder = resolvePath(folder)
            return resolved == expandedFolder || resolved.hasPrefix(expandedFolder + "/")
        }
    }

    public func readFile(at path: String) throws -> Data {
        guard isPathAllowed(path) else {
            throw CloakError.fileBlocked(path)
        }
        let resolved = resolvePath(path)
        return try Data(contentsOf: URL(fileURLWithPath: resolved))
    }

    public func readFileAsString(at path: String) throws -> String {
        guard isPathAllowed(path) else {
            throw CloakError.fileBlocked(path)
        }
        let resolved = resolvePath(path)
        return try String(contentsOfFile: resolved, encoding: .utf8)
    }

    public func listDirectory(at path: String) throws -> [FileEntry] {
        guard isPathAllowed(path) else {
            throw CloakError.fileBlocked(path)
        }
        let resolved = resolvePath(path)
        let url = URL(fileURLWithPath: resolved)
        let contents = try FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesConforming: [.isDirectoryKey, .fileSizeKey]
        )

        return contents.compactMap { itemURL in
            let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            return FileEntry(
                name: itemURL.lastPathComponent,
                path: itemURL.path,
                isDirectory: values?.isDirectory ?? false,
                size: values?.fileSize ?? 0,
                isAllowed: isPathAllowed(itemURL.path)
            )
        }
    }

    public func filterPaths(_ paths: [String]) -> (allowed: [String], blocked: [String]) {
        var allowed: [String] = []
        var blocked: [String] = []
        for path in paths {
            if isPathAllowed(path) {
                allowed.append(path)
            } else {
                blocked.append(path)
            }
        }
        return (allowed, blocked)
    }

    public func extractPathsFromCommand(_ command: String) -> [String] {
        let fileCommands = ["cat", "less", "more", "head", "tail", "wc", "grep", "find", "ls", "stat", "file", "open", "vim", "nano", "code"]
        var paths: [String] = []
        let parts = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        for (i, part) in parts.enumerated() {
            if part.hasPrefix("-") { continue }

            if i == 0 {
                let cmd = (part as NSString).lastPathComponent
                if !fileCommands.contains(cmd) { continue }
                continue
            }

            if part.hasPrefix("/") || part.hasPrefix("~") || part.hasPrefix("./") || part.hasPrefix("../") {
                paths.append(part)
            }
        }

        return paths
    }

    public func checkCommand(_ command: String) -> CommandCheckResult {
        let paths = extractPathsFromCommand(command)
        if paths.isEmpty {
            return .noPaths
        }

        let result = filterPaths(paths)
        if result.blocked.isEmpty {
            return .allowed
        }
        return .blocked(result.blocked)
    }

    private func resolvePath(_ path: String) -> String {
        let expanded = NSString(string: path).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardized.path
    }
}

public struct FileEntry {
    public let name: String
    public let path: String
    public let isDirectory: Bool
    public let size: Int
    public let isAllowed: Bool
}

public enum CommandCheckResult {
    case allowed
    case blocked([String])
    case noPaths
}
