import Foundation

/// Line-by-line JSONL file reader
public struct JSONLReader: Sendable {
    public init() {}

    /// Read all lines from a JSONL file
    public func readLines(from url: URL) throws -> [Data] {
        let content = try Data(contentsOf: url)
        return parseLines(from: content)
    }

    /// Read all lines from a file path
    public func readLines(from path: String) throws -> [Data] {
        let url = URL(fileURLWithPath: path)
        return try readLines(from: url)
    }

    /// Parse JSONL content into line data (optimized using Data.range for fast memchr)
    public func parseLines(from data: Data) -> [Data] {
        let newline = Data([0x0A])  // \n
        var lines: [Data] = []
        lines.reserveCapacity(max(100, data.count / 50000))  // Rough estimate

        var searchStart = data.startIndex
        while let newlineRange = data.range(of: newline, in: searchStart..<data.endIndex) {
            if newlineRange.lowerBound > searchStart {
                lines.append(data[searchStart..<newlineRange.lowerBound])
            }
            searchStart = newlineRange.upperBound
        }

        // Handle last line without trailing newline
        if searchStart < data.endIndex {
            lines.append(data[searchStart..<data.endIndex])
        }

        return lines
    }

    /// Stream lines from a large file
    public func streamLines(from path: String) throws -> AsyncThrowingStream<Data, Error> {
        let url = URL(fileURLWithPath: path)

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() }

                    var buffer = Data()
                    let chunkSize = 64 * 1024  // 64KB chunks

                    while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
                        buffer.append(chunk)

                        // Find complete lines
                        while let newlineIndex = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                            let lineData = buffer.prefix(upTo: newlineIndex)
                            buffer.removeSubrange(...newlineIndex)

                            if !lineData.isEmpty {
                                continuation.yield(Data(lineData))
                            }
                        }
                    }

                    // Handle any remaining data
                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

/// JSONL decoder with support for partial/streaming decoding
public struct JSONLDecoder: Sendable {
    private let decoder: JSONDecoder

    public init(dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .iso8601) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        self.decoder = decoder
    }

    /// Decode a single line to a type
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try decoder.decode(type, from: data)
    }

    /// Decode all lines to an array
    public func decodeAll<T: Decodable>(_ type: T.Type, from lines: [Data]) -> [T] {
        lines.compactMap { data in
            try? decoder.decode(type, from: data)
        }
    }

    /// Decode lines with error handling
    public func decodeAllWithErrors<T: Decodable>(
        _ type: T.Type,
        from lines: [Data]
    ) -> [(index: Int, result: Result<T, Error>)] {
        lines.enumerated().map { index, data in
            do {
                let value = try decoder.decode(type, from: data)
                return (index, .success(value))
            } catch {
                return (index, .failure(error))
            }
        }
    }
}
