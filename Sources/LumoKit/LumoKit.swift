import PicoDocs
import VecturaKit
import Foundation

public final class LumoKit {
    private let vectura: VecturaKit

    public init(config: VecturaConfig) throws {
        self.vectura = try VecturaKit(config: config)
    }

    /// Parse and index a document from a given file URL
    public func parseAndIndex(url: URL, chunkSize: Int = 500) async throws {
        let parsedSections = try await parseDocument(from: url, chunkSize: chunkSize)

        guard !parsedSections.isEmpty else {
            print("No valid content to index from document.")
            return
        }
        _ = try await vectura.addDocuments(texts: parsedSections)
    }

    /// Parse a document from a file and return its content in chunks
    public func parseDocument(from url: URL, chunkSize: Int = 500) async throws -> [String] {
        let doc = await PicoDocument(url: url)
        await doc.fetch()
        await doc.parse(to: .markdown)

        guard let fullContent = await doc.exportedContent?.joined(separator: "\n") else {
            throw LumoKitError.emptyDocument
        }

        return try chunkText(fullContent, size: chunkSize)
    }

    /// Splits a given text into chunks of approximately `size` characters.
    /// - Parameters:
    ///   - text: The full text to split.
    ///   - size: The maximum character count per chunk. Must be greater than 0.
    /// - Returns: An array of text chunks.
    /// - Note: If `size` is non-positive, the original text is returned as a single chunk.
    public func chunkText(_ text: String, size: Int) throws -> [String] {
        // Validate the chunk size
        guard size > 0 else {
            throw LumoKitError.invalidChunkSize
        }

        let words = text.split(separator: " ")
        var chunks: [String] = []
        var currentChunk: [Substring] = []
        var currentSize = 0

        for word in words {
            // +1 accounts for the space separator
            if currentSize + word.count + 1 > size {
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = []
                currentSize = 0
            }
            currentChunk.append(word)
            currentSize += word.count + 1
        }
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }
        return chunks
    }

    /// Search for relevant documents in the vector database
    public func semanticSearch(
        query: String,
        numResults: Int = 5,
        threshold: Float = 0.7
    ) async throws -> [VecturaSearchResult] {
        try await vectura.search(query: query, numResults: numResults, threshold: threshold)
    }

    /// Reset the vector database
    public func resetDB() async throws {
        try await vectura.reset()
    }
}

public enum LumoKitError: Error {
    /// Thrown when the document has no valid content to parse.
    case emptyDocument

    /// Thrown when the specified chunk size is invalid (non-positive).
    case invalidChunkSize
}
