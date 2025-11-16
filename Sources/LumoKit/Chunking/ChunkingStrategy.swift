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

/// Context information for chunk creation
struct ChunkContext {
    let config: ChunkingConfig
    let chunks: [Chunk]
    let hasNext: Bool
}

/// Parameters for creating a chunk from segments
struct SegmentChunkParameters<T> {
    let segments: [T]
    let separator: String
    let textExtractor: (T) -> String
    let rangeExtractor: (T) -> Range<String.Index>
}

/// Parameters for creating a simple chunk
struct ChunkParameters {
    let text: String
    let index: Int
    let startPosition: Int
    let endPosition: Int
    let hasNext: Bool
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
    ///   - parameters: Segment parameters containing segments, separator, and extractors
    ///   - text: The original full text (for position calculation)
    ///   - context: Context containing config, chunks, and hasNext info
    /// - Returns: A new Chunk, or nil if segments are empty
    static func createChunkFromSegments<T>(
        parameters: SegmentChunkParameters<T>,
        text: String,
        context: ChunkContext
    ) -> Chunk? {
        guard let firstSegment = parameters.segments.first,
              let lastSegment = parameters.segments.last else {
            return nil
        }

        let firstRange = parameters.rangeExtractor(firstSegment)
        let lastRange = parameters.rangeExtractor(lastSegment)

        // Build chunk text without intermediate array allocations
        var chunkText = ""
        for (idx, segment) in parameters.segments.enumerated() {
            if idx > 0 {
                chunkText += parameters.separator
            }
            chunkText += parameters.textExtractor(segment)
        }

        let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
        let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

        let metadata = ChunkMetadata(
            index: context.chunks.count,
            startPosition: startPos,
            endPosition: endPos,
            hasOverlapWithPrevious: context.chunks.count > 0 && context.config.overlapSize > 0,
            hasOverlapWithNext: context.hasNext,
            contentType: context.config.contentType,
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
    ///   - parameters: Chunk creation parameters
    ///   - config: Chunking configuration
    /// - Returns: A new Chunk
    static func createChunk(
        parameters: ChunkParameters,
        config: ChunkingConfig
    ) -> Chunk {
        let metadata = ChunkMetadata(
            index: parameters.index,
            startPosition: parameters.startPosition,
            endPosition: parameters.endPosition,
            hasOverlapWithPrevious: parameters.index > 0 && config.overlapSize > 0,
            hasOverlapWithNext: parameters.hasNext,
            contentType: config.contentType,
            source: nil
        )
        return Chunk(text: parameters.text, metadata: metadata)
    }
}
