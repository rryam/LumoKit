import Foundation

/// Configuration for text chunking strategies
public struct ChunkingConfig {
    /// The target maximum size for each chunk in characters
    public let chunkSize: Int

    /// The overlap between chunks as a percentage (0.0 to 1.0)
    /// For example, 0.2 means 20% overlap
    public let overlapPercentage: Double

    /// The chunking strategy to use
    public let strategy: ChunkingStrategyType

    /// The type of content being chunked (affects chunking behavior)
    public let contentType: ContentType

    public init(
        chunkSize: Int = 500,
        overlapPercentage: Double = 0.1,
        strategy: ChunkingStrategyType = .semantic,
        contentType: ContentType = .prose
    ) {
        self.chunkSize = chunkSize
        self.overlapPercentage = max(0.0, min(1.0, overlapPercentage))
        self.strategy = strategy
        self.contentType = contentType
    }

    /// The overlap size in characters
    var overlapSize: Int {
        Int(Double(chunkSize) * overlapPercentage)
    }
}

/// Available chunking strategies
public enum ChunkingStrategyType {
    /// Sentence-aware chunking using natural language processing
    case sentence

    /// Paragraph-based chunking
    case paragraph

    /// Semantic chunking with content-aware boundary detection (recommended)
    case semantic
}

/// Content type hints for specialized chunking
public enum ContentType: Sendable {
    /// Regular prose text
    case prose

    /// Source code
    case code

    /// Markdown formatted text
    case markdown

    /// Mixed content (prose + code)
    case mixed
}
