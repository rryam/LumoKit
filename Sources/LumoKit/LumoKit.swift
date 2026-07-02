import PicoDocs
import VecturaKit
import VecturaEmbeddingsKit
import Foundation

/// Main entry point for LumoKit document parsing and semantic search.
///
/// LumoKit combines PicoDocs for document ingestion with VecturaKit for vector storage
/// and semantic search, providing an end-to-end pipeline for creating searchable knowledge bases.
public final class LumoKit {
    private let vectura: VecturaKit
    private let defaultChunkingConfig: ChunkingConfig
    private let chunkMetadataStore = IndexedChunkMetadataStore()

    /// Initializes a new LumoKit instance.
    ///
    /// - Parameters:
    ///   - config: Configuration for the VecturaKit vector database
    ///   - chunkingConfig: Configuration for text chunking (uses defaults if not provided)
    ///   - modelSource: The embedding model source used by `SwiftEmbedder`
    /// - Throws: Errors from VecturaKit initialization
    public convenience init(
        config: VecturaConfig,
        chunkingConfig: ChunkingConfig? = nil,
        modelSource: VecturaModelSource = .default
    ) async throws {
        let embedder = SwiftEmbedder(modelSource: modelSource)
        try await self.init(
            config: config,
            chunkingConfig: chunkingConfig,
            embedder: embedder
        )
    }

    /// Initializes a new LumoKit instance with a custom Vectura embedder.
    ///
    /// This overload unlocks the full range of embedders supported by VecturaKit,
    /// including `NLContextualEmbedder`, `OpenAICompatibleEmbedder`, `MLXEmbedder`,
    /// and custom `VecturaEmbedder` implementations.
    ///
    /// - Parameters:
    ///   - config: Configuration for the VecturaKit vector database
    ///   - chunkingConfig: Configuration for text chunking (uses defaults if not provided)
    ///   - embedder: The embedder used to generate vector embeddings
    /// - Throws: Errors from VecturaKit initialization
    public init(
        config: VecturaConfig,
        chunkingConfig: ChunkingConfig? = nil,
        embedder: VecturaEmbedder
    ) async throws {
        self.vectura = try await VecturaKit(config: config, embedder: embedder)
        self.defaultChunkingConfig = try chunkingConfig ?? ChunkingConfig()
    }

    /// Parse and index a document from a given file URL
    ///
    /// - Parameters:
    ///   - url: The file URL to parse
    ///   - chunkingConfig: Optional custom chunking configuration (uses default if not provided)
    /// - Returns: Array of document IDs that were indexed
    /// - Throws: `LumoKitError.invalidURL` if the URL is not a file URL
    /// - Throws: `LumoKitError.fileNotFound` if the file does not exist
    /// - Throws: `LumoKitError.emptyDocument` if the document has no valid content
    public func parseAndIndex(
        url: URL,
        chunkingConfig: ChunkingConfig? = nil
    ) async throws -> [UUID] {
        let chunks = try await parseDocument(from: url, chunkingConfig: chunkingConfig)
        let texts = chunks.map { $0.text }
        let ids = try await vectura.addDocuments(texts: texts)
        await chunkMetadataStore.store(chunks.map(\.metadata), for: ids)
        return ids
    }

    /// Parse a document from a file and return chunks with metadata.
    ///
    /// - Parameters:
    ///   - url: The file URL to parse
    ///   - chunkingConfig: Optional custom chunking configuration (uses default if not provided)
    /// - Returns: Array of chunks with metadata (text, position, overlap info, content type, etc.)
    /// - Throws: `LumoKitError.invalidURL` if the URL is not a file URL
    /// - Throws: `LumoKitError.fileNotFound` if the file does not exist
    /// - Throws: `LumoKitError.emptyDocument` if the document has no valid content
    /// - Throws: `LumoKitError.unsupportedFileType` if the file type is not supported
    public func parseDocument(
        from url: URL,
        chunkingConfig: ChunkingConfig? = nil
    ) async throws -> [Chunk] {
        let chunks = try await parseChunks(from: url, chunkingConfig: chunkingConfig)

        var chunksWithSource: [Chunk] = []
        chunksWithSource.reserveCapacity(chunks.count)

        let sourceName = url.lastPathComponent
        for chunk in chunks {
            chunksWithSource.append(
                Chunk(
                    text: chunk.text,
                    metadata: ChunkMetadata(
                        index: chunk.metadata.index,
                        startPosition: chunk.metadata.startPosition,
                        endPosition: chunk.metadata.endPosition,
                        hasOverlapWithPrevious: chunk.metadata.hasOverlapWithPrevious,
                        hasOverlapWithNext: chunk.metadata.hasOverlapWithNext,
                        contentType: chunk.metadata.contentType,
                        source: sourceName
                    )
                )
            )
        }
        return chunksWithSource
    }

    private func parseChunks(
        from url: URL,
        chunkingConfig: ChunkingConfig?
    ) async throws -> [Chunk] {
        try validateInputURL(url)
        let fullContent = try await loadDocumentContent(from: url)
        let config = chunkingConfig ?? defaultChunkingConfig
        let chunks = try chunkText(fullContent, config: config)
        guard !chunks.isEmpty else {
            throw LumoKitError.emptyDocument
        }
        return chunks
    }

    private func validateInputURL(_ url: URL) throws {
        guard url.isFileURL else {
            throw LumoKitError.invalidURL
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LumoKitError.fileNotFound
        }
    }

    private func loadDocumentContent(from url: URL) async throws -> String {
        let doc = await PicoDocument(url: url)

        // Check if file type is supported
        try await checkDocumentStatus(doc, stage: "initialization")

        await doc.fetch()
        try await checkDocumentStatus(doc, stage: "fetch")

        await doc.parse(to: .markdown)
        try await checkDocumentStatus(doc, stage: "parse")

        guard let exportedContent = await doc.exportedContent else {
            throw LumoKitError.emptyDocument
        }

        switch exportedContent.count {
        case 0:
            throw LumoKitError.emptyDocument
        case 1:
            return exportedContent[0]
        default:
            return exportedContent.joined(separator: "\n")
        }
    }

    /// Checks PicoDocument status and throws appropriate LumoKitError if failed
    /// - Parameters:
    ///   - doc: The PicoDocument to check
    ///   - stage: The stage name for error context
    private func checkDocumentStatus(_ doc: PicoDocument, stage: String) async throws {
        // Execute on MainActor to access main actor-isolated status
        let error = await MainActor.run { () -> Error? in
            guard case .failed(let err) = doc.status else {
                return nil
            }
            return err
        }
        guard let error = error else { return }

        if let picoError = error as? PicoDocsError {
            switch picoError {
            case .documentTypeNotSupported:
                throw LumoKitError.unsupportedFileType
            case .emptyDocument:
                throw LumoKitError.emptyDocument
            default:
                throw LumoKitError.chunkingFailed(strategy: "PicoDocs.\(stage)", underlyingError: error)
            }
        } else {
            throw LumoKitError.chunkingFailed(strategy: "PicoDocs.\(stage)", underlyingError: error)
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

    /// Search for indexed chunks and return any metadata captured during `parseAndIndex`.
    ///
    /// Raw documents added with `addDocuments(texts:)` do not have chunk metadata.
    public func semanticSearchChunks(
        query: String,
        numResults: Int = 5,
        threshold: Float = 0.7
    ) async throws -> [LumoSearchResult] {
        let results = try await semanticSearch(
            query: query,
            numResults: numResults,
            threshold: threshold
        )
        let metadataByID = await chunkMetadataStore.metadata(for: results.map(\.id))
        return results.map { result in
            LumoSearchResult(
                id: result.id,
                text: result.text,
                score: result.score,
                createdAt: result.createdAt,
                metadata: metadataByID[result.id]
            )
        }
    }

    /// Clears all indexed documents from the vector database.
    ///
    /// Use this method to remove all indexed content when you need to
    /// start fresh. Note that this operation cannot be undone.
    ///
    /// - Throws: `LumoKitError.databaseError` if the reset fails
    public func resetDB() async throws {
        try await vectura.reset()
        await chunkMetadataStore.removeAll()
    }

    /// Add raw text documents to the vector database
    ///
    /// - Parameters:
    ///   - texts: Array of text strings to index
    /// - Returns: Array of document IDs that were indexed
    /// - Throws: Errors from VecturaKit
    public func addDocuments(texts: [String]) async throws -> [UUID] {
        try await vectura.addDocuments(texts: texts)
    }

    /// Deletes chunks from the vector database.
    ///
    /// Use this method when you need to remove specific chunks, such as
    /// when a document is deleted in your app.
    ///
    /// - Parameters:
    ///   - ids: Array of chunk IDs to delete
    /// - Throws: Errors from VecturaKit
    public func deleteChunks(ids: [UUID]) async throws {
        try await vectura.deleteDocuments(ids: ids)
        await chunkMetadataStore.remove(ids: ids)
    }

    /// Returns the total number of indexed documents
    ///
    /// - Returns: The count of documents in the vector database
    public func documentCount() async throws -> Int {
        try await vectura.documentCount
    }
}

public struct LumoSearchResult: Identifiable, Sendable {
    public let id: UUID
    public let text: String
    public let score: Float
    public let createdAt: Date
    public let metadata: ChunkMetadata?
}

private actor IndexedChunkMetadataStore {
    private var metadataByID: [UUID: ChunkMetadata] = [:]

    func store(_ metadata: [ChunkMetadata], for ids: [UUID]) {
        for (id, chunkMetadata) in zip(ids, metadata) {
            metadataByID[id] = chunkMetadata
        }
    }

    func metadata(for ids: [UUID]) -> [UUID: ChunkMetadata] {
        var result: [UUID: ChunkMetadata] = [:]
        result.reserveCapacity(ids.count)
        for id in ids {
            result[id] = metadataByID[id]
        }
        return result
    }

    func remove(ids: [UUID]) {
        for id in ids {
            metadataByID.removeValue(forKey: id)
        }
    }

    func removeAll() {
        metadataByID.removeAll()
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
