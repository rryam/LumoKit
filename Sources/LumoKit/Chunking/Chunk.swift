import Foundation

/// A text chunk with associated metadata
public struct Chunk: Sendable {
    /// The text content of this chunk
    public let text: String

    /// Metadata about this chunk
    public let metadata: ChunkMetadata

    public init(text: String, metadata: ChunkMetadata) {
        self.text = text
        self.metadata = metadata
    }
}

/// Metadata associated with a text chunk
public struct ChunkMetadata: Sendable {
    /// The index of this chunk in the sequence
    public let index: Int

    /// The character position where this chunk starts in the original text
    public let startPosition: Int

    /// The character position where this chunk ends in the original text
    public let endPosition: Int

    /// Whether this chunk has overlap with the previous chunk
    public let hasOverlapWithPrevious: Bool

    /// Whether this chunk has overlap with the next chunk
    public let hasOverlapWithNext: Bool

    /// The type of content in this chunk
    public let contentType: ContentType

    /// Optional source identifier (e.g., filename)
    public let source: String?

    public init(
        index: Int,
        startPosition: Int,
        endPosition: Int,
        hasOverlapWithPrevious: Bool = false,
        hasOverlapWithNext: Bool = false,
        contentType: ContentType = .prose,
        source: String? = nil
    ) {
        self.index = index
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.hasOverlapWithPrevious = hasOverlapWithPrevious
        self.hasOverlapWithNext = hasOverlapWithNext
        self.contentType = contentType
        self.source = source
    }
}
