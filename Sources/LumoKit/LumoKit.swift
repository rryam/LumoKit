import PicoDocs
import VecturaKit
import Foundation

/// Main entry point for LumoKit document parsing and semantic search.
///
/// LumoKit combines PicoDocs for document ingestion with VecturaKit for vector storage
/// and semantic search, providing an end-to-end pipeline for creating searchable knowledge bases.
public final class LumoKit {
    private let vectura: VecturaKit
    private let defaultChunkingConfig: ChunkingConfig

    /// Initializes a new LumoKit instance.
    ///
    /// - Parameters:
    ///   - config: Configuration for the VecturaKit vector database
    ///   - chunkingConfig: Configuration for text chunking (uses defaults if not provided)
    /// - Throws: Errors from VecturaKit initialization
    public init(
        config: VecturaConfig,
        chunkingConfig: ChunkingConfig? = nil
    ) async throws {
        let embedder = SwiftEmbedder()
        self.vectura = try await VecturaKit(config: config, embedder: embedder)
        self.defaultChunkingConfig = try chunkingConfig ?? ChunkingConfig()
    }

    /// Parse and index a document from a given file URL
    ///
    /// - Parameters:
    ///   - url: The file URL to parse
    ///   - chunkingConfig: Optional custom chunking configuration (uses default if not provided)
    /// - Throws: `LumoKitError.invalidURL` if the URL is not a file URL
    /// - Throws: `LumoKitError.fileNotFound` if the file does not exist
    /// - Throws: `LumoKitError.emptyDocument` if the document has no valid content
    public func parseAndIndex(
        url: URL,
        chunkingConfig: ChunkingConfig? = nil
    ) async throws {
        // Validate URL
        guard url.isFileURL else {
            throw LumoKitError.invalidURL
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LumoKitError.fileNotFound
        }

        let chunks = try await parseDocument(
            from: url,
            chunkingConfig: chunkingConfig
        )

        guard !chunks.isEmpty else {
            throw LumoKitError.emptyDocument
        }
        let texts = chunks.map { $0.text }
        _ = try await vectura.addDocuments(texts: texts)
    }

    /// Parse a document from a file and return chunks with metadata.
    ///
    /// - Parameters:
    ///   - url: The file URL to parse
    ///   - chunkingConfig: Optional custom chunking configuration (uses default if not provided)
    /// - Returns: Array of chunks with metadata (text, position, overlap info, content type, etc.)
    /// - Throws: `LumoKitError.invalidURL` if the URL is not a file URL
    /// - Throws: `LumoKitError.fileNotFound` if the file does not exist
    /// - Throws: `LumoKitError.unsupportedFileType` if the file type is not supported
    public func parseDocument(
        from url: URL,
        chunkingConfig: ChunkingConfig? = nil
    ) async throws -> [Chunk] {
        // Validate URL
        guard url.isFileURL else {
            throw LumoKitError.invalidURL
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LumoKitError.fileNotFound
        }

        let doc = await PicoDocument(url: url)

        // Check if file type is supported
        try await checkDocumentStatus(doc, stage: "initialization")

        await doc.fetch()

        // Check status after fetch
        try await checkDocumentStatus(doc, stage: "fetch")

        await doc.parse(to: .markdown)

        // Check status after parse
        try await checkDocumentStatus(doc, stage: "parse")

        guard let fullContent = await doc.exportedContent?.joined(separator: "\n") else {
            throw LumoKitError.emptyDocument
        }

        let config = chunkingConfig ?? defaultChunkingConfig
        let chunks = try chunkText(fullContent, config: config)

        // Populate source metadata from URL
        let source = url.lastPathComponent
        return chunks.map { chunk in
            Chunk(
                text: chunk.text,
                metadata: ChunkMetadata(
                    index: chunk.metadata.index,
                    startPosition: chunk.metadata.startPosition,
                    endPosition: chunk.metadata.endPosition,
                    hasOverlapWithPrevious: chunk.metadata.hasOverlapWithPrevious,
                    hasOverlapWithNext: chunk.metadata.hasOverlapWithNext,
                    contentType: chunk.metadata.contentType,
                    source: source
                )
            )
        }
    }

    /// Checks PicoDocument status and throws appropriate LumoKitError if failed
    /// - Parameters:
    ///   - doc: The PicoDocument to check
    ///   - stage: The stage name for error context
    private func checkDocumentStatus(_ doc: PicoDocument, stage: String) async throws {
        let status = doc.status
        guard case .failed(let error) = status else {
            return
        }

        if let picoError = error as? PicoDocsError {
            switch picoError {
            case .documentTypeNotSupported:
                throw LumoKitError.unsupportedFileType
            case .emptyDocument:
                throw LumoKitError.emptyDocument
            default:
                throw LumoKitError.chunkingFailed(strategy: "PicoDocs", underlyingError: error)
            }
        } else {
            throw LumoKitError.chunkingFailed(strategy: "PicoDocs", underlyingError: error)
        }
    }

    /// Splits text into chunks with metadata.
    ///
    /// - Parameters:
    ///   - text: The text to chunk
    ///   - config: Chunking configuration
    /// - Returns: Array of chunks with metadata (text, position, overlap info, content type, etc.)
    public func chunkText(_ text: String, config: ChunkingConfig) throws -> [Chunk] {
        let strategy = ChunkingStrategyFactory.strategy(for: config.strategy)
        return try strategy.chunk(text: text, config: config)
    }

    /// Search for relevant documents in the vector database
    ///
    /// - Parameters:
    ///   - query: The search query string
    ///   - numResults: Maximum number of results to return (must be > 0)
    ///   - threshold: Minimum similarity threshold (must be 0.0-1.0)
    /// - Returns: Array of search results ordered by relevance
    /// - Throws: `LumoKitError.invalidSearchParameters` if parameters are invalid
    public func semanticSearch(
        query: String,
        numResults: Int = 5,
        threshold: Float = 0.7
    ) async throws -> [VecturaSearchResult] {
        guard numResults > 0 else {
            throw LumoKitError.invalidSearchParameters
        }
        guard (0.0...1.0).contains(threshold) else {
            throw LumoKitError.invalidSearchParameters
        }
        return try await vectura.search(query: .text(query), numResults: numResults, threshold: threshold)
    }

    /// Clears all indexed documents from the vector database.
    ///
    /// Use this method to remove all indexed content when you need to
    /// start fresh. Note that this operation cannot be undone.
    ///
    /// - Throws: `LumoKitError.databaseError` if the reset fails
    public func resetDB() async throws {
        try await vectura.reset()
    }

    /// Add raw text documents to the vector database
    ///
    /// - Parameters:
    ///   - texts: Array of text strings to index
    /// - Throws: Errors from VecturaKit
    public func addDocuments(texts: [String]) async throws {
        _ = try await vectura.addDocuments(texts: texts)
    }
}

public enum LumoKitError: Error, Equatable {
    /// Thrown when the document has no valid content to parse.
    case emptyDocument

    /// Thrown when the specified chunk size is invalid (non-positive).
    case invalidChunkSize

    /// Thrown when the provided URL is not a valid file URL.
    case invalidURL

    /// Thrown when the file at the provided URL does not exist.
    case fileNotFound

    /// Thrown when the file type is not supported by PicoDocs.
    case unsupportedFileType

    /// Thrown when search parameters are invalid (numResults <= 0 or threshold outside 0.0-1.0).
    case invalidSearchParameters

    /// Thrown when chunking fails, with context about which strategy failed.
    /// - strategy: The name of the chunking strategy that failed
    /// - underlyingError: The underlying error that caused the failure
    case chunkingFailed(strategy: String, underlyingError: Error)

    public static func == (lhs: LumoKitError, rhs: LumoKitError) -> Bool {
        switch (lhs, rhs) {
        case (.emptyDocument, .emptyDocument),
             (.invalidChunkSize, .invalidChunkSize),
             (.invalidURL, .invalidURL),
             (.fileNotFound, .fileNotFound),
             (.unsupportedFileType, .unsupportedFileType),
             (.invalidSearchParameters, .invalidSearchParameters):
            return true
        case (.chunkingFailed(let lhsStrategy, _), .chunkingFailed(let rhsStrategy, _)):
            return lhsStrategy == rhsStrategy
        default:
            return false
        }
    }
}
