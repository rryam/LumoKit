import Foundation

/// Protocol for text chunking strategies
public protocol ChunkingStrategy: Sendable {
    /// Chunks the given text according to the strategy's algorithm
    /// - Parameters:
    ///   - text: The text to chunk
    ///   - config: Configuration for chunking
    /// - Returns: An array of chunks with metadata
    func chunk(text: String, config: ChunkingConfig) throws -> [Chunk]
}

/// Factory for creating chunking strategies
public struct ChunkingStrategyFactory {
    public static func strategy(for type: ChunkingStrategyType) -> ChunkingStrategy {
        switch type {
        case .sentence:
            return SentenceChunker()
        case .paragraph:
            return ParagraphChunker()
        case .semantic:
            return SemanticChunker()
        }
    }
}

/// Base functionality shared across chunking strategies
struct ChunkingHelper {
    /// Constants used for chunking calculations
    enum Constants {
        /// Paragraph separator string ("\n\n")
        static let paragraphSeparator = "\n\n"

        /// Paragraph separator size in characters (2 for "\n\n")
        static let paragraphSeparatorSize = 2

        /// Line separator string ("\n")
        static let lineSeparator = "\n"

        /// Line separator size in characters (1 for "\n")
        static let lineSeparatorSize = 1

        /// Space separator string (" ")
        static let spaceSeparator = " "

        /// Space separator size in characters (1 for " ")
        static let spaceSeparatorSize = 1

        /// Number of lines to use for code block overlap
        static let codeOverlapLineCount = 3
    }

    /// Validates chunk size configuration
    static func validateChunkSize(_ size: Int) throws {
        guard size > 0 else {
            throw LumoKitError.invalidChunkSize
        }
    }

    /// Wraps an error with context about which chunking strategy failed
    /// - Parameters:
    ///   - error: The underlying error that occurred
    ///   - strategyName: The name of the chunking strategy that failed
    /// - Returns: A wrapped error with context, or the original error if it's already a LumoKitError
    static func wrapChunkingError(_ error: Error, strategyName: String) -> Error {
        // If it's already a LumoKitError, return it as-is to avoid double-wrapping
        if error is LumoKitError {
            return error
        }
        return LumoKitError.chunkingFailed(strategy: strategyName, underlyingError: error)
    }

    /// Creates a chunk from segments with ranges.
    ///
    /// Builds chunk text without intermediate array allocations.
    ///
    /// - Parameters:
    ///   - segments: Array of text segments with their ranges
    ///   - separator: String separator to join segments (e.g., " ", "\n", "\n\n")
    ///   - textExtractor: Closure to extract text from each segment
    ///   - text: The original full text (for position calculation)
    ///   - chunks: The current chunks array (for index calculation)
    ///   - config: Chunking configuration
    ///   - hasNext: Whether there are more chunks coming
    /// - Returns: A new Chunk, or nil if segments are empty
    static func createChunkFromSegments<T>(
        segments: [T],
        separator: String,
        textExtractor: (T) -> String,
        rangeExtractor: (T) -> Range<String.Index>,
        text: String,
        chunks: [Chunk],
        config: ChunkingConfig,
        hasNext: Bool
    ) -> Chunk? {
        guard let firstSegment = segments.first,
              let lastSegment = segments.last else {
            return nil
        }

        let firstRange = rangeExtractor(firstSegment)
        let lastRange = rangeExtractor(lastSegment)

        // Build chunk text without intermediate array allocations
        var chunkText = ""
        for (idx, segment) in segments.enumerated() {
            if idx > 0 {
                chunkText += separator
            }
            chunkText += textExtractor(segment)
        }

        let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
        let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

        let metadata = ChunkMetadata(
            index: chunks.count,
            startPosition: startPos,
            endPosition: endPos,
            hasOverlapWithPrevious: chunks.count > 0 && config.overlapSize > 0,
            hasOverlapWithNext: hasNext,
            contentType: config.contentType,
            source: nil
        )

        return Chunk(text: chunkText, metadata: metadata)
    }

    /// Calculate overlap for text segments
    /// - Parameters:
    ///   - segments: Array of text segments
    ///   - targetSize: Target size for overlap in characters
    ///   - separator: Separator size between segments (default: 1 for space)
    /// - Returns: Tuple of overlapping segments and their total size
    static func calculateOverlap(
        _ segments: [String],
        targetSize: Int,
        separator: Int = Constants.spaceSeparatorSize
    ) -> (segments: [String], size: Int) {
        var overlapSegments: [String] = []
        var overlapSize = 0

        for segment in segments.reversed() {
            let requiredSize = segment.count + (overlapSegments.isEmpty ? 0 : separator)
            if overlapSize + requiredSize <= targetSize {
                overlapSegments.insert(segment, at: 0)
                overlapSize += requiredSize
            } else {
                break
            }
        }

        return (overlapSegments, overlapSize)
    }

    /// Creates a chunk with explicit position values
    /// - Parameters:
    ///   - text: The chunk text content
    ///   - index: The chunk index
    ///   - startPosition: Start position in the original text
    ///   - endPosition: End position in the original text
    ///   - config: Chunking configuration
    ///   - hasNext: Whether there are more chunks coming
    /// - Returns: A new Chunk
    static func createChunk(
        text: String,
        index: Int,
        startPosition: Int,
        endPosition: Int,
        config: ChunkingConfig,
        hasNext: Bool
    ) -> Chunk {
        let metadata = ChunkMetadata(
            index: index,
            startPosition: startPosition,
            endPosition: endPosition,
            hasOverlapWithPrevious: index > 0 && config.overlapSize > 0,
            hasOverlapWithNext: hasNext,
            contentType: config.contentType,
            source: nil
        )
        return Chunk(text: text, metadata: metadata)
    }
}
