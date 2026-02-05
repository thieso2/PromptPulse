import Foundation
import PromptWatchDomain

/// Raw JSONL entry structure from Claude session files
public struct RawSessionEntry: Codable, Sendable {
    public let type: String
    public let message: RawMessage?
    public let timestamp: String?
    public let sessionId: String?

    // Progress-specific fields
    public let content: AnyCodable?
    public let tool: String?

    enum CodingKeys: String, CodingKey {
        case type
        case message
        case timestamp
        case sessionId
        case content
        case tool
    }
}

/// Raw message structure
public struct RawMessage: Codable, Sendable {
    public let id: String?
    public let role: String?
    public let content: AnyCodable?
    public let model: String?
    public let stopReason: String?
    public let usage: RawUsage?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case model
        case stopReason = "stop_reason"
        case usage
    }
}

/// Raw usage statistics
public struct RawUsage: Codable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cacheReadInputTokens: Int?
    public let cacheCreationInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
    }
}

/// Type-erased Codable value for flexible JSON parsing
public struct AnyCodable: Codable, Equatable, @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map(\.value)
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            self.value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "Unable to encode value"
                )
            )
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull):
            return true
        case let (l as Bool, r as Bool):
            return l == r
        case let (l as Int, r as Int):
            return l == r
        case let (l as Double, r as Double):
            return l == r
        case let (l as String, r as String):
            return l == r
        default:
            return false
        }
    }

    /// Get as string
    public var stringValue: String? {
        value as? String
    }

    /// Get as array
    public var arrayValue: [Any]? {
        value as? [Any]
    }

    /// Get as dictionary
    public var dictionaryValue: [String: Any]? {
        value as? [String: Any]
    }
}

/// Parser for Claude session JSONL files
public struct SessionParser: @unchecked Sendable {
    private let reader: JSONLReader
    private let decoder: JSONDecoder

    /// Reusable date formatters (creating these is expensive)
    private let iso8601WithFractional: ISO8601DateFormatter
    private let iso8601Standard: ISO8601DateFormatter

    public init() {
        self.reader = JSONLReader()
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Pre-create date formatters
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.iso8601WithFractional = withFractional

        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        self.iso8601Standard = standard
    }

    /// Parse a session file and return messages
    public func parse(filePath: String) throws -> [Message] {
        let lines = try reader.readLines(from: filePath)
        return parseLines(lines)
    }

    /// Parse a session file and return a full Session object
    public func parseSession(filePath: String) throws -> Session {
        let url = URL(fileURLWithPath: filePath)
        let lines = try reader.readLines(from: url)
        let messages = parseLines(lines)

        // Extract session ID from filename
        let sessionId = url.deletingPathExtension().lastPathComponent

        // Get file attributes for timestamps
        let attrs = try? FileManager.default.attributesOfItem(atPath: filePath)
        let modDate = attrs?[.modificationDate] as? Date

        // Find earliest and latest timestamps from messages
        let timestamps = messages.compactMap(\.timestamp)
        let startTime = timestamps.min()

        return Session(
            id: sessionId,
            filePath: filePath,
            projectPath: nil,
            startTime: startTime,
            lastModified: modDate,
            messages: messages
        )
    }

    /// Parse JSONL data lines into messages (optimized)
    public func parseLines(_ lines: [Data]) -> [Message] {
        var messages: [Message] = []
        messages.reserveCapacity(lines.count / 4)  // Rough estimate: ~25% are actual messages
        var seenIds: Set<String> = []

        for (index, lineData) in lines.enumerated() {
            // Fast path: quick type check before full parse
            guard let message = parseLineFast(lineData, index: index) else {
                continue
            }

            // Ensure unique ID
            var finalMessage = message
            if seenIds.contains(message.id) {
                let uniqueId = "\(message.id)-\(index)"
                finalMessage = Message(
                    id: uniqueId,
                    role: message.role,
                    content: message.content,
                    timestamp: message.timestamp,
                    usage: message.usage,
                    model: message.model,
                    stopReason: message.stopReason
                )
            }
            seenIds.insert(finalMessage.id)
            messages.append(finalMessage)
        }

        return messages
    }

    /// Fast line parsing using JSONSerialization (faster than Codable)
    private func parseLineFast(_ data: Data, index: Int) -> Message? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return nil
        }

        // Early exit for types we don't care about
        guard type == "user" || type == "human" || type == "assistant" || type == "system" else {
            return nil
        }

        guard let messageDict = json["message"] as? [String: Any] else {
            return nil
        }

        let role: MessageRole
        switch type {
        case "user", "human":
            role = .user
        case "assistant":
            role = .assistant
        case "system":
            role = .system
        default:
            return nil
        }

        let id = (messageDict["id"] as? String) ?? "msg-\(index)"
        let content = parseContentFast(messageDict["content"])
        let timestamp = (json["timestamp"] as? String).flatMap { parseTimestamp($0) }
        let usage = parseUsageFast(messageDict["usage"] as? [String: Any])
        let model = messageDict["model"] as? String
        let stopReason = messageDict["stop_reason"] as? String

        return Message(
            id: id,
            role: role,
            content: content,
            timestamp: timestamp,
            usage: usage,
            model: model,
            stopReason: stopReason
        )
    }

    /// Maximum content size to store (truncate larger content for performance)
    private static let maxContentSize = 50_000  // 50KB per content block

    /// Truncate large strings for display performance
    private func truncateIfNeeded(_ text: String) -> String {
        if text.count > Self.maxContentSize {
            let truncated = String(text.prefix(Self.maxContentSize))
            return truncated + "\n\n[... truncated \(text.count - Self.maxContentSize) characters ...]"
        }
        return text
    }

    /// Fast content parsing directly from Any
    private func parseContentFast(_ content: Any?) -> [ContentBlock] {
        guard let content = content else { return [] }

        // String content
        if let text = content as? String {
            return [.text(truncateIfNeeded(text))]
        }

        // Array of content blocks
        guard let array = content as? [[String: Any]] else { return [] }

        var blocks: [ContentBlock] = []
        blocks.reserveCapacity(array.count)

        for item in array {
            guard let type = item["type"] as? String else { continue }

            switch type {
            case "text":
                if let text = item["text"] as? String {
                    blocks.append(.text(truncateIfNeeded(text)))
                }

            case "tool_use":
                if let id = item["id"] as? String,
                   let name = item["name"] as? String {
                    let input: String
                    if let inputDict = item["input"] {
                        input = (try? JSONSerialization.data(withJSONObject: inputDict))
                            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                    } else {
                        input = "{}"
                    }
                    // Truncate large tool inputs
                    blocks.append(.toolUse(id: id, name: name, input: truncateIfNeeded(input)))
                }

            case "tool_result":
                if let toolUseId = item["tool_use_id"] as? String {
                    let resultContent = (item["content"] as? String) ?? ""
                    let isError = (item["is_error"] as? Bool) ?? false
                    // Truncate large tool results (these are often huge)
                    blocks.append(.toolResult(toolUseId: toolUseId, content: truncateIfNeeded(resultContent), isError: isError))
                }

            case "thinking":
                if let text = item["thinking"] as? String {
                    blocks.append(.thinking(truncateIfNeeded(text)))
                }

            default:
                break
            }
        }

        return blocks
    }

    /// Fast usage parsing
    private func parseUsageFast(_ usage: [String: Any]?) -> TokenUsage {
        guard let usage = usage else { return .zero }

        return TokenUsage(
            inputTokens: usage["input_tokens"] as? Int ?? 0,
            outputTokens: usage["output_tokens"] as? Int ?? 0,
            cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0,
            cacheCreationTokens: usage["cache_creation_input_tokens"] as? Int ?? 0
        )
    }

    // MARK: - Legacy methods (kept for compatibility)

    /// Parse a single entry into a Message if applicable
    private func parseEntry(_ entry: RawSessionEntry) -> Message? {
        switch entry.type {
        case "user", "human":
            return parseUserEntry(entry)
        case "assistant":
            return parseAssistantEntry(entry)
        case "system":
            return parseSystemEntry(entry)
        default:
            // Skip progress, result, summary, etc.
            return nil
        }
    }

    private func parseUserEntry(_ entry: RawSessionEntry) -> Message? {
        guard let rawMessage = entry.message else { return nil }

        let content = parseContent(rawMessage.content)
        let timestamp = parseTimestamp(entry.timestamp)

        return Message(
            id: rawMessage.id ?? UUID().uuidString,
            role: .user,
            content: content,
            timestamp: timestamp,
            usage: .zero
        )
    }

    private func parseAssistantEntry(_ entry: RawSessionEntry) -> Message? {
        guard let rawMessage = entry.message else { return nil }

        let content = parseContent(rawMessage.content)
        let timestamp = parseTimestamp(entry.timestamp)
        let usage = parseUsage(rawMessage.usage)

        return Message(
            id: rawMessage.id ?? UUID().uuidString,
            role: .assistant,
            content: content,
            timestamp: timestamp,
            usage: usage,
            model: rawMessage.model,
            stopReason: rawMessage.stopReason
        )
    }

    private func parseSystemEntry(_ entry: RawSessionEntry) -> Message? {
        guard let rawMessage = entry.message else { return nil }

        let content = parseContent(rawMessage.content)
        let timestamp = parseTimestamp(entry.timestamp)

        return Message(
            id: rawMessage.id ?? UUID().uuidString,
            role: .system,
            content: content,
            timestamp: timestamp,
            usage: .zero
        )
    }

    private func parseContent(_ content: AnyCodable?) -> [ContentBlock] {
        guard let content = content else { return [] }

        // Content can be a string or an array of content blocks
        if let text = content.stringValue {
            return [.text(text)]
        }

        guard let array = content.arrayValue else { return [] }

        var blocks: [ContentBlock] = []

        for item in array {
            guard let dict = item as? [String: Any],
                  let type = dict["type"] as? String else {
                continue
            }

            switch type {
            case "text":
                if let text = dict["text"] as? String {
                    blocks.append(.text(text))
                }

            case "tool_use":
                if let id = dict["id"] as? String,
                   let name = dict["name"] as? String {
                    let input = (dict["input"] as? [String: Any])
                        .flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                        .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                    blocks.append(.toolUse(id: id, name: name, input: input))
                }

            case "tool_result":
                if let toolUseId = dict["tool_use_id"] as? String {
                    let content = (dict["content"] as? String) ?? ""
                    let isError = (dict["is_error"] as? Bool) ?? false
                    blocks.append(.toolResult(toolUseId: toolUseId, content: content, isError: isError))
                }

            case "thinking":
                if let text = dict["thinking"] as? String {
                    blocks.append(.thinking(text))
                }

            default:
                break
            }
        }

        return blocks
    }

    private func parseUsage(_ usage: RawUsage?) -> TokenUsage {
        guard let usage = usage else { return .zero }

        return TokenUsage(
            inputTokens: usage.inputTokens ?? 0,
            outputTokens: usage.outputTokens ?? 0,
            cacheReadTokens: usage.cacheReadInputTokens ?? 0,
            cacheCreationTokens: usage.cacheCreationInputTokens ?? 0
        )
    }

    private func parseTimestamp(_ timestamp: String?) -> Date? {
        guard let timestamp = timestamp else { return nil }

        // Try with fractional seconds first (most common)
        if let date = iso8601WithFractional.date(from: timestamp) {
            return date
        }

        // Fallback to standard format
        return iso8601Standard.date(from: timestamp)
    }
}
