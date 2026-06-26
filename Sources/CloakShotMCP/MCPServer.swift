import Foundation
import ScreenShield
import FileShield
import TextRedactor
import Shared

@main
struct CloakShotMCPServer {
    static let config = CloakConfig.load()
    static let screenShield = ScreenShield(config: config)
    static let fileShield = FileShield(config: config)
    static let textRedactor = TextRedactor(config: config)

    static func main() async {
        let stdin = FileHandle.standardInput
        let stdout = FileHandle.standardOutput

        var buffer = Data()

        while true {
            let chunk = stdin.availableData
            if chunk.isEmpty {
                break
            }
            buffer.append(chunk)

            while let message = extractMessage(from: &buffer) {
                let response = await handleMessage(message)
                if let responseData = try? JSONSerialization.data(withJSONObject: response),
                   let header = "Content-Length: \(responseData.count)\r\n\r\n".data(using: .utf8) {
                    stdout.write(header)
                    stdout.write(responseData)
                }
            }
        }
    }

    static func extractMessage(from buffer: inout Data) -> [String: Any]? {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else { return nil }

        let headerData = buffer[buffer.startIndex..<headerEnd.lowerBound]
        guard let headerStr = String(data: headerData, encoding: .utf8),
              let lengthLine = headerStr.components(separatedBy: "\r\n").first(where: { $0.hasPrefix("Content-Length:") }),
              let length = Int(lengthLine.replacingOccurrences(of: "Content-Length:", with: "").trimmingCharacters(in: .whitespaces)) else {
            return nil
        }

        let bodyStart = headerEnd.upperBound
        let bodyEnd = buffer.index(bodyStart, offsetBy: length, limitedBy: buffer.endIndex) ?? buffer.endIndex

        guard buffer.distance(from: bodyStart, to: buffer.endIndex) >= length else { return nil }

        let bodyData = buffer[bodyStart..<bodyEnd]
        buffer.removeSubrange(buffer.startIndex..<bodyEnd)

        return try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
    }

    static func handleMessage(_ message: [String: Any]) async -> [String: Any] {
        guard let method = message["method"] as? String,
              let id = message["id"] else {
            return errorResponse(id: message["id"], code: -32600, message: "Invalid request")
        }

        switch method {
        case "initialize":
            return initializeResponse(id: id)
        case "tools/list":
            return toolsListResponse(id: id)
        case "tools/call":
            return await toolsCallResponse(id: id, params: message["params"] as? [String: Any] ?? [:])
        default:
            return errorResponse(id: id, code: -32601, message: "Method not found: \(method)")
        }
    }

    static func initializeResponse(id: Any) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id,
            "result": [
                "protocolVersion": "2024-11-05",
                "capabilities": ["tools": [:]],
                "serverInfo": [
                    "name": "cloakshot",
                    "version": "0.1.0"
                ]
            ]
        ]
    }

    static func toolsListResponse(id: Any) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id,
            "result": [
                "tools": [
                    [
                        "name": "cloakshot_screenshot",
                        "description": "Take a screenshot with privacy filtering. Only shows apps the user has allowed. PII in text is redacted.",
                        "inputSchema": [
                            "type": "object",
                            "properties": [
                                "app": [
                                    "type": "string",
                                    "description": "Optional bundle ID to capture only a specific app"
                                ]
                            ]
                        ]
                    ],
                    [
                        "name": "cloakshot_read_file",
                        "description": "Read a file through CloakShot. Only reads from folders the user has allowed.",
                        "inputSchema": [
                            "type": "object",
                            "properties": [
                                "path": [
                                    "type": "string",
                                    "description": "Path to the file to read"
                                ]
                            ],
                            "required": ["path"]
                        ]
                    ],
                    [
                        "name": "cloakshot_list_directory",
                        "description": "List directory contents through CloakShot. Only lists folders the user has allowed.",
                        "inputSchema": [
                            "type": "object",
                            "properties": [
                                "path": [
                                    "type": "string",
                                    "description": "Path to the directory to list"
                                ]
                            ],
                            "required": ["path"]
                        ]
                    ],
                    [
                        "name": "cloakshot_check_command",
                        "description": "Check if a bash command accesses any blocked paths before running it.",
                        "inputSchema": [
                            "type": "object",
                            "properties": [
                                "command": [
                                    "type": "string",
                                    "description": "The bash command to check"
                                ]
                            ],
                            "required": ["command"]
                        ]
                    ],
                    [
                        "name": "cloakshot_status",
                        "description": "Get current CloakShot status: allowed apps, allowed folders, shield on/off.",
                        "inputSchema": [
                            "type": "object",
                            "properties": [:]
                        ]
                    ]
                ]
            ]
        ]
    }

    static func toolsCallResponse(id: Any, params: [String: Any]) async -> [String: Any] {
        guard let name = params["name"] as? String else {
            return errorResponse(id: id, code: -32602, message: "Missing tool name")
        }

        let arguments = params["arguments"] as? [String: Any] ?? [:]

        switch name {
        case "cloakshot_screenshot":
            return await handleScreenshot(id: id, arguments: arguments)
        case "cloakshot_read_file":
            return await handleReadFile(id: id, arguments: arguments)
        case "cloakshot_list_directory":
            return await handleListDirectory(id: id, arguments: arguments)
        case "cloakshot_check_command":
            return handleCheckCommand(id: id, arguments: arguments)
        case "cloakshot_status":
            return handleStatus(id: id)
        default:
            return errorResponse(id: id, code: -32602, message: "Unknown tool: \(name)")
        }
    }

    static func handleScreenshot(id: Any, arguments: [String: Any]) async -> [String: Any] {
        guard config.shieldEnabled else {
            return toolResult(id: id, text: "CloakShot shield is OFF. Enable it in the menu bar app.")
        }

        do {
            let image: CGImage
            if let bundleID = arguments["app"] as? String {
                image = try await screenShield.captureApp(bundleID: bundleID)
            } else {
                image = try await screenShield.captureFilteredScreenshot()
            }

            let result = try textRedactor.redactImage(image)

            guard let pngData = cgImageToPNG(result.image) else {
                return toolResult(id: id, text: "Failed to encode screenshot")
            }

            let base64 = pngData.base64EncodedString()
            var content: [[String: Any]] = [
                ["type": "image", "data": base64, "mimeType": "image/png"]
            ]

            if result.regionsRedacted > 0 {
                let summary = "CloakShot redacted \(result.regionsRedacted) region(s) containing: \(result.piiFound.map(\.type.rawValue).joined(separator: ", "))"
                content.append(["type": "text", "text": summary])
            }

            return ["jsonrpc": "2.0", "id": id, "result": ["content": content]]
        } catch {
            return toolResult(id: id, text: "CloakShot error: \(error.localizedDescription)")
        }
    }

    static func handleReadFile(id: Any, arguments: [String: Any]) async -> [String: Any] {
        guard let path = arguments["path"] as? String else {
            return toolResult(id: id, text: "Missing 'path' argument")
        }

        guard config.shieldEnabled else {
            return toolResult(id: id, text: "CloakShot shield is OFF. File read not filtered.")
        }

        do {
            var content = try fileShield.readFileAsString(at: path)
            let matches = textRedactor.scanText(content)
            if !matches.isEmpty {
                content = textRedactor.redactText(content)
                let summary = "\n\n[CloakShot: redacted \(matches.count) PII match(es) from file content]"
                content += summary
            }
            return toolResult(id: id, text: content)
        } catch let error as CloakError {
            return toolResult(id: id, text: error.localizedDescription ?? "Blocked")
        } catch {
            return toolResult(id: id, text: "Error reading file: \(error.localizedDescription)")
        }
    }

    static func handleListDirectory(id: Any, arguments: [String: Any]) async -> [String: Any] {
        guard let path = arguments["path"] as? String else {
            return toolResult(id: id, text: "Missing 'path' argument")
        }

        do {
            let entries = try fileShield.listDirectory(at: path)
            let lines = entries.map { entry in
                let type = entry.isDirectory ? "dir " : "file"
                let access = entry.isAllowed ? "" : " [BLOCKED]"
                return "\(type) \(entry.name)\(access)"
            }
            return toolResult(id: id, text: lines.joined(separator: "\n"))
        } catch let error as CloakError {
            return toolResult(id: id, text: error.localizedDescription ?? "Blocked")
        } catch {
            return toolResult(id: id, text: "Error listing directory: \(error.localizedDescription)")
        }
    }

    static func handleCheckCommand(id: Any, arguments: [String: Any]) -> [String: Any] {
        guard let command = arguments["command"] as? String else {
            return toolResult(id: id, text: "Missing 'command' argument")
        }

        switch fileShield.checkCommand(command) {
        case .allowed:
            return toolResult(id: id, text: "OK: all paths in this command are allowed")
        case .blocked(let paths):
            return toolResult(id: id, text: "BLOCKED: this command accesses blocked paths:\n\(paths.joined(separator: "\n"))")
        case .noPaths:
            return toolResult(id: id, text: "OK: no file paths detected in this command")
        }
    }

    static func handleStatus(id: Any) -> [String: Any] {
        let apps = config.allowedBundleIDs.sorted().joined(separator: "\n  - ")
        let folders = config.allowedFolders.joined(separator: "\n  - ")
        let status = """
        CloakShot Status:
          Shield: \(config.shieldEnabled ? "ON" : "OFF")
          Allowed apps (\(config.allowedBundleIDs.count)):
          - \(apps.isEmpty ? "(none)" : apps)
          Allowed folders (\(config.allowedFolders.count)):
          - \(folders.isEmpty ? "(none)" : folders)
          Secret strings: \(config.secretStrings.count) configured
        """
        return toolResult(id: id, text: status)
    }

    // MARK: - Helpers

    static func toolResult(id: Any, text: String) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id,
            "result": [
                "content": [["type": "text", "text": text]]
            ]
        ]
    }

    static func errorResponse(id: Any?, code: Int, message: String) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "error": ["code": code, "message": message]
        ]
    }

    static func cgImageToPNG(_ image: CGImage) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        return rep.representation(using: .png, properties: [:])
    }
}
