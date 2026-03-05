import Foundation

/// Simple word-based chunking strategy
/// Used internally as fallback for edge cases (very long sentences, etc.)
struct WordChunker: ChunkingStrategy {
    func chunk(text: String, config: ChunkingConfig) throws -> [Chunk] {
        try ChunkingHelper.validateChunkSize(config.chunkSize)

        guard !text.isEmpty else { return [] }

        var words: [(word: String, range: Range<String.Index>)] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { substring, range, _, _ in
            if let word = substring {
                words.append((word, range))
            }
        }

        guard !words.isEmpty else { return [] }

        var chunks: [Chunk] = []
        var currentWords: ArraySlice<(word: String, range: Range<String.Index>)> = []
        var currentSize = 0

        for wordData in words {
            let word = wordData.word
            let wordSize = word.count
            let separatorSize = currentWords.isEmpty ? 0 : ChunkingHelper.Constants.spaceSeparatorSize

            // If adding this word would exceed the chunk size, flush the current chunk.
            if currentSize + wordSize + separatorSize > config.chunkSize && !currentWords.isEmpty {
                flushChunk(from: currentWords, to: &chunks, text: text, config: config, hasNext: true)

                // Handle overlap for next chunk
                if config.overlapSize > 0 {
                    let overlap = ChunkingHelper.calculateOverlapMetrics(
                        currentWords,
                        targetSize: config.overlapSize,
                        segmentSize: { $0.word.count }
                    )
                    let overlapCount = overlap.count
                    currentWords = overlapCount > 0 ? currentWords.suffix(overlapCount) : []
                    currentSize = overlap.size
                } else {
                    currentWords = []
                    currentSize = 0
                }
            }

            // Trim words from the front until there's room for the next word.
            ChunkingHelper.trimFrontForNextSegment(
                segments: &currentWords,
                currentSize: &currentSize,
                nextSegmentSize: wordSize,
                chunkSize: config.chunkSize,
                separatorSize: ChunkingHelper.Constants.spaceSeparatorSize,
                segmentSize: { $0.word.count }
            )

            currentWords.append(wordData)
            currentSize += wordSize + (currentWords.count > 1 ? ChunkingHelper.Constants.spaceSeparatorSize : 0)
        }

        // Add remaining words as final chunk
        if !currentWords.isEmpty {
            flushChunk(from: currentWords, to: &chunks, text: text, config: config, hasNext: false)
        }

        return chunks
    }

    private func flushChunk(
        from words: ArraySlice<(word: String, range: Range<String.Index>)>,
        to chunks: inout [Chunk],
        text: String,
        config: ChunkingConfig,
        hasNext: Bool
    ) {
        let context = ChunkContext(config: config, chunks: chunks, hasNext: hasNext)
        let parameters = SegmentChunkParameters(
            segments: words,
            separator: ChunkingHelper.Constants.spaceSeparator,
            textExtractor: { $0.word },
            rangeExtractor: { $0.range }
        )
        guard let chunk = ChunkingHelper.createChunkFromSegments(
            parameters: parameters,
            text: text,
            context: context
        ) else {
            return
        }
        chunks.append(chunk)
    }
}
