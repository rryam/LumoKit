import PicoDocs
import VecturaKit
import Foundation

public final class LumoKit {
    private let vectura: VecturaKit
    private let defaultChunkingConfig: ChunkingConfig

    public init(
        config: VecturaConfig,
        chunkingConfig: ChunkingConfig = ChunkingConfig()
    ) async throws {
        let embedder = SwiftEmbedder()
        self.vectura = try await VecturaKit(config: config, embedder: embedder)
        self.defaultChunkingConfig = chunkingConfig
    }

    /// Parse and index a document from a given file URL
    /// - Parameters:
    ///   - url: The file URL to parse
    ///   - chunkingConfig: Optional custom chunking configuration (uses default if not provided)
    public func parseAndIndex(
        url: URL,
        chunkingConfig: ChunkingConfig? = nil
    ) async throws {
        let chunks = try await parseDocument(
            from: url,
            chunkingConfig: chunkingConfig
        )

        guard !chunks.isEmpty else {
            print("LumoKit: No valid content to index from document at \(url.path).")
            return
        }
        _ = try await vectura.addDocuments(texts: chunks)
    }

    /// Parse a document from a file and return its content in chunks
    /// - Parameters:
    ///   - url: The file URL to parse
    ///   - chunkingConfig: Optional custom chunking configuration (uses default if not provided)
    /// - Returns: Array of text chunks
    public func parseDocument(
        from url: URL,
        chunkingConfig: ChunkingConfig? = nil
    ) async throws -> [String] {
        let doc = await PicoDocument(url: url)
        await doc.fetch()
        await doc.parse(to: .markdown)

        guard let fullContent = await doc.exportedContent?.joined(separator: "\n") else {
            throw LumoKitError.emptyDocument
        }

        let config = chunkingConfig ?? defaultChunkingConfig
        return try chunkText(fullContent, config: config)
    }

    /// Parse a document and return chunks with metadata
    /// - Parameters:
    ///   - url: The file URL to parse
    ///   - chunkingConfig: Optional custom chunking configuration
    /// - Returns: Array of chunks with metadata
    public func parseDocumentWithMetadata(
        from url: URL,
        chunkingConfig: ChunkingConfig? = nil
    ) async throws -> [Chunk] {
        let doc = await PicoDocument(url: url)
        await doc.fetch()
        await doc.parse(to: .markdown)

        guard let fullContent = await doc.exportedContent?.joined(separator: "\n") else {
            throw LumoKitError.emptyDocument
        }

        let config = chunkingConfig ?? defaultChunkingConfig
        return try chunkTextWithMetadata(fullContent, config: config)
    }

    /// Splits text into chunks using the new chunking system
    /// - Parameters:
    ///   - text: The text to chunk
    ///   - config: Chunking configuration
    /// - Returns: Array of text chunks
    public func chunkText(_ text: String, config: ChunkingConfig) throws -> [String] {
        let chunks = try chunkTextWithMetadata(text, config: config)
        return chunks.map { $0.text }
    }

    /// Splits text into chunks with metadata
    /// - Parameters:
    ///   - text: The text to chunk
    ///   - config: Chunking configuration
    /// - Returns: Array of chunks with metadata
    public func chunkTextWithMetadata(_ text: String, config: ChunkingConfig) throws -> [Chunk] {
        let strategy = ChunkingStrategyFactory.strategy(for: config.strategy)
        return try strategy.chunk(text: text, config: config)
    }

    /// Search for relevant documents in the vector database
    public func semanticSearch(
        query: String,
        numResults: Int = 5,
        threshold: Float = 0.7
    ) async throws -> [VecturaSearchResult] {
        try await vectura.search(query: .text(query), numResults: numResults, threshold: threshold)
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
