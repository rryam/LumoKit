import Foundation
import NaturalLanguage

/// Semantic chunking strategy with content-aware boundary detection
/// This strategy adapts to content type and uses natural language boundaries
struct SemanticChunker: ChunkingStrategy {
    func chunk(text: String, config: ChunkingConfig) throws -> [Chunk] {
        try ChunkingHelper.validateChunkSize(config.chunkSize)

        guard !text.isEmpty else { return [] }

        // Route to specialized handlers based on content type
        switch config.contentType {
        case .code:
            return try chunkCode(text: text, config: config)
        case .markdown:
            return try chunkMarkdown(text: text, config: config)
        case .mixed:
            return try chunkMixed(text: text, config: config)
        case .prose:
            return try chunkProse(text: text, config: config)
        }
    }

    // MARK: - Prose Chunking

    private func chunkProse(text: String, config: ChunkingConfig) throws -> [Chunk] {
        // For prose, ParagraphChunker is preferred as it respects paragraph boundaries.
        // Falls back to SentenceChunker if no paragraphs are found.
        do {
            return try ParagraphChunker().chunk(text: text, config: config)
        } catch {
            throw ChunkingHelper.wrapChunkingError(error, strategyName: "SemanticChunker.prose (via ParagraphChunker)")
        }
    }

    // MARK: - Code Chunking

    private func chunkCode(text: String, config: ChunkingConfig) throws -> [Chunk] {
        return try SemanticCodeChunker().chunk(text: text, config: config)
    }

    // MARK: - Markdown Chunking

    private func chunkMarkdown(text: String, config: ChunkingConfig) throws -> [Chunk] {
        return try SemanticMarkdownChunker().chunk(text: text, config: config)
    }

    // MARK: - Mixed Content Chunking

    private func chunkMixed(text: String, config: ChunkingConfig) throws -> [Chunk] {
        // Detect code blocks and split accordingly
        let segments = SemanticTextHelpers.separateCodeAndProse(text)

        var chunks: [Chunk] = []

        for (segmentIdx, segment) in segments.enumerated() {
            let segmentConfig = ChunkingConfig(
                chunkSize: config.chunkSize,
                overlapPercentage: config.overlapPercentage,
                strategy: config.strategy,
                contentType: segment.isCode ? .code : .prose
            )

            let segmentChunks: [Chunk]
            do {
                segmentChunks = try chunk(text: segment.content, config: segmentConfig)
            } catch {
                throw ChunkingHelper.wrapChunkingError(
                    error,
                    strategyName: "SemanticChunker.mixed (segment: \(segment.isCode ? "code" : "prose"))"
                )
            }
            let baseOffset = text.distance(from: text.startIndex, to: segment.range.lowerBound)

            for (chunkIdx, segmentChunk) in segmentChunks.enumerated() {
                let isLastChunkOfLastSegment = segmentIdx == segments.count - 1 && chunkIdx == segmentChunks.count - 1
                let adjustedMetadata = ChunkMetadata(
                    index: chunks.count,
                    startPosition: baseOffset + segmentChunk.metadata.startPosition,
                    endPosition: baseOffset + segmentChunk.metadata.endPosition,
                    hasOverlapWithPrevious: segmentChunk.metadata.hasOverlapWithPrevious,
                    hasOverlapWithNext: !isLastChunkOfLastSegment,
                    contentType: segment.isCode ? .code : .prose,
                    source: nil
                )
                chunks.append(Chunk(text: segmentChunk.text, metadata: adjustedMetadata))
            }
        }

        return chunks
    }
}
