import Foundation

/// Simple word-based chunking strategy
/// Used internally as fallback for edge cases (very long sentences, etc.)
struct WordChunker: ChunkingStrategy {
    func chunk(text: String, config: ChunkingConfig) throws -> [Chunk] {
        try ChunkingHelper.validateChunkSize(config.chunkSize)

        let words = text.split(separator: " ").map { String($0) }
        guard !words.isEmpty else { return [] }

        var chunks: [Chunk] = []
        var currentWords: [String] = []
        var currentSize = 0
        var chunkStartPosition = 0

        for (idx, word) in words.enumerated() {
            let wordSize = word.count

            // Check if adding this word would exceed the chunk size
            if currentSize + wordSize + 1 > config.chunkSize && !currentWords.isEmpty {
                // Create chunk from accumulated words
                let chunkText = currentWords.joined(separator: " ")
                let chunkEndPosition = chunkStartPosition + chunkText.count

                let metadata = ChunkMetadata(
                    index: chunks.count,
                    startPosition: chunkStartPosition,
                    endPosition: chunkEndPosition,
                    hasOverlapWithPrevious: false,
                    hasOverlapWithNext: idx < words.count - 1,
                    contentType: config.contentType,
                    source: nil
                )

                chunks.append(Chunk(text: chunkText, metadata: metadata))

                // Start new chunk
                currentWords = []
                currentSize = 0
                chunkStartPosition = chunkEndPosition + 1 // +1 for space
            }

            currentWords.append(word)
            currentSize += wordSize + (currentWords.count > 1 ? 1 : 0) // +1 for space between words
        }

        // Add remaining words as final chunk
        if !currentWords.isEmpty {
            let chunkText = currentWords.joined(separator: " ")
            let chunkEndPosition = chunkStartPosition + chunkText.count

            let metadata = ChunkMetadata(
                index: chunks.count,
                startPosition: chunkStartPosition,
                endPosition: chunkEndPosition,
                hasOverlapWithPrevious: false,
                hasOverlapWithNext: false,
                contentType: config.contentType,
                source: nil
            )

            chunks.append(Chunk(text: chunkText, metadata: metadata))
        }

        return chunks
    }
}
