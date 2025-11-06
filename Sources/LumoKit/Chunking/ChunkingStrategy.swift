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
    /// Creates chunks with overlap from an array of segments
    static func createChunksWithOverlap(
        segments: [String],
        segmentPositions: [Range<String.Index>],
        originalText: String,
        config: ChunkingConfig,
        contentType: ContentType,
        source: String? = nil
    ) -> [Chunk] {
        guard !segments.isEmpty else { return [] }

        var chunks: [Chunk] = []
        var currentSegments: [String] = []
        var currentSize = 0
        var chunkStartPosition = 0

        for (idx, segment) in segments.enumerated() {
            let segmentSize = segment.count

            // Check if adding this segment would exceed the chunk size
            if currentSize + segmentSize > config.chunkSize && !currentSegments.isEmpty {
                // Create a chunk from accumulated segments
                let chunkText = currentSegments.joined(separator: " ")
                let chunkEndPosition = chunkStartPosition + chunkText.count

                let metadata = ChunkMetadata(
                    index: chunks.count,
                    startPosition: chunkStartPosition,
                    endPosition: chunkEndPosition,
                    hasOverlapWithPrevious: chunks.count > 0 && config.overlapSize > 0,
                    hasOverlapWithNext: idx < segments.count - 1,
                    contentType: contentType,
                    source: source
                )

                chunks.append(Chunk(text: chunkText, metadata: metadata))

                // Calculate overlap: keep last N characters worth of segments
                if config.overlapSize > 0 && idx < segments.count - 1 {
                    var overlapSegments: [String] = []
                    var overlapSize = 0

                    // Work backwards to get segments for overlap
                    for overlapIdx in stride(from: currentSegments.count - 1, through: 0, by: -1) {
                        let seg = currentSegments[overlapIdx]
                        if overlapSize + seg.count <= config.overlapSize {
                            overlapSegments.insert(seg, at: 0)
                            overlapSize += seg.count
                        } else {
                            break
                        }
                    }

                    currentSegments = overlapSegments
                    currentSize = overlapSize
                    chunkStartPosition = chunkEndPosition - overlapSize
                } else {
                    currentSegments = []
                    currentSize = 0
                    chunkStartPosition = chunkEndPosition
                }
            }

            currentSegments.append(segment)
            currentSize += segmentSize + (currentSegments.count > 1 ? 1 : 0) // +1 for space
        }

        // Add remaining segments as final chunk
        if !currentSegments.isEmpty {
            let chunkText = currentSegments.joined(separator: " ")
            let chunkEndPosition = chunkStartPosition + chunkText.count

            let metadata = ChunkMetadata(
                index: chunks.count,
                startPosition: chunkStartPosition,
                endPosition: chunkEndPosition,
                hasOverlapWithPrevious: chunks.count > 0 && config.overlapSize > 0,
                hasOverlapWithNext: false,
                contentType: contentType,
                source: source
            )

            chunks.append(Chunk(text: chunkText, metadata: metadata))
        }

        return chunks
    }

    /// Validates chunk size configuration
    static func validateChunkSize(_ size: Int) throws {
        guard size > 0 else {
            throw LumoKitError.invalidChunkSize
        }
    }
}
