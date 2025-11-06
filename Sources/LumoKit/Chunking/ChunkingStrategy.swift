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

    /// Calculate overlap for text segments
    /// - Parameters:
    ///   - segments: Array of text segments
    ///   - targetSize: Target size for overlap in characters
    ///   - separator: Separator size between segments (default: 1 for space)
    /// - Returns: Tuple of overlapping segments and their total size
    static func calculateOverlap(
        _ segments: [String],
        targetSize: Int,
        separator: Int = 1
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
}
