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
        var currentWords: [(word: String, range: Range<String.Index>)] = []
        var currentSize = 0

        for (idx, wordData) in words.enumerated() {
            let word = wordData.word
            let wordSize = word.count

            // Check if adding this word would exceed the chunk size
            if currentSize + wordSize + ChunkingHelper.Constants.spaceSeparatorSize > config.chunkSize && !currentWords.isEmpty {
                // Create chunk from accumulated words
                guard let firstRange = currentWords.first?.range,
                      let lastRange = currentWords.last?.range else {
                    continue
                }
                // Build chunk text without intermediate array
                var chunkText = ""
                for (wordIdx, wordData) in currentWords.enumerated() {
                    if wordIdx > 0 {
                        chunkText += ChunkingHelper.Constants.spaceSeparator
                    }
                    chunkText += wordData.word
                }
                let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
                let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

                let metadata = ChunkMetadata(
                    index: chunks.count,
                    startPosition: startPos,
                    endPosition: endPos,
                    hasOverlapWithPrevious: chunks.count > 0 && config.overlapSize > 0,
                    hasOverlapWithNext: idx < words.count - 1,
                    contentType: config.contentType,
                    source: nil
                )

                chunks.append(Chunk(text: chunkText, metadata: metadata))

                // Handle overlap
                if config.overlapSize > 0 && idx < words.count - 1 {
                    let wordStrings = currentWords.map { $0.word }
                    let overlap = ChunkingHelper.calculateOverlap(wordStrings, targetSize: config.overlapSize)
                    let overlapCount = overlap.segments.count
                    currentWords = overlapCount > 0 ? Array(currentWords.suffix(overlapCount)) : []
                    currentSize = overlap.size
                } else {
                    currentWords = []
                    currentSize = 0
                }
            }

            currentWords.append(wordData)
            currentSize += wordSize + (currentWords.count > 1 ? ChunkingHelper.Constants.spaceSeparatorSize : 0)
        }

        // Add remaining words as final chunk
        if !currentWords.isEmpty,
           let firstRange = currentWords.first?.range,
           let lastRange = currentWords.last?.range {
            // Build chunk text without intermediate array
            var chunkText = ""
            for (wordIdx, wordData) in currentWords.enumerated() {
                if wordIdx > 0 {
                    chunkText += ChunkingHelper.Constants.spaceSeparator
                }
                chunkText += wordData.word
            }
            let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
            let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

            let metadata = ChunkMetadata(
                index: chunks.count,
                startPosition: startPos,
                endPosition: endPos,
                hasOverlapWithPrevious: chunks.count > 0 && config.overlapSize > 0,
                hasOverlapWithNext: false,
                contentType: config.contentType,
                source: nil
            )

            chunks.append(Chunk(text: chunkText, metadata: metadata))
        }

        return chunks
    }
}
