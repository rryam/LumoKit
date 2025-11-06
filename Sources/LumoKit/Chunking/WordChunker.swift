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
            if currentSize + wordSize + 1 > config.chunkSize && !currentWords.isEmpty {
                // Create chunk from accumulated words
                guard let firstRange = currentWords.first?.range,
                      let lastRange = currentWords.last?.range else {
                    continue
                }
                let chunkText = currentWords.map { $0.word }.joined(separator: " ")
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
                    let overlap = calculateOverlap(currentWords, targetSize: config.overlapSize)
                    currentWords = overlap.words
                    currentSize = overlap.size
                } else {
                    currentWords = []
                    currentSize = 0
                }
            }

            currentWords.append(wordData)
            currentSize += wordSize + (currentWords.count > 1 ? 1 : 0) // +1 for space between words
        }

        // Add remaining words as final chunk
        if !currentWords.isEmpty,
           let firstRange = currentWords.first?.range,
           let lastRange = currentWords.last?.range {
            let chunkText = currentWords.map { $0.word }.joined(separator: " ")
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

    private func calculateOverlap(_ words: [(word: String, range: Range<String.Index>)], targetSize: Int) -> (words: [(word: String, range: Range<String.Index>)], size: Int) {
        var overlapWords: [(word: String, range: Range<String.Index>)] = []
        var overlapSize = 0

        for wordData in words.reversed() {
            if overlapSize + wordData.word.count <= targetSize {
                overlapWords.insert(wordData, at: 0)
                overlapSize += wordData.word.count + (overlapWords.count > 1 ? 1 : 0)
            } else {
                break
            }
        }

        return (overlapWords, overlapSize)
    }
}
