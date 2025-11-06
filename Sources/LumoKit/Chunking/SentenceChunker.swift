import Foundation
import NaturalLanguage

/// Sentence-aware chunking strategy using NLTokenizer
struct SentenceChunker: ChunkingStrategy {
    func chunk(text: String, config: ChunkingConfig) throws -> [Chunk] {
        try ChunkingHelper.validateChunkSize(config.chunkSize)

        guard !text.isEmpty else { return [] }

        // Extract sentences using NLTokenizer
        let sentences = extractSentences(from: text)
        guard !sentences.isEmpty else {
            // Fallback to word chunking if no sentences detected
            return try WordChunker().chunk(text: text, config: config)
        }

        var chunks: [Chunk] = []
        var currentSentences: [String] = []
        var currentSize = 0
        var chunkStartPosition = 0

        for (idx, sentence) in sentences.enumerated() {
            let sentenceSize = sentence.count

            // If a single sentence exceeds chunk size, split it by words
            if sentenceSize > config.chunkSize {
                // Flush current chunk if any
                if !currentSentences.isEmpty {
                    let chunkText = currentSentences.joined(separator: " ")
                    let chunkEndPosition = chunkStartPosition + chunkText.count

                    chunks.append(createChunk(
                        text: chunkText,
                        index: chunks.count,
                        startPosition: chunkStartPosition,
                        endPosition: chunkEndPosition,
                        hasNext: true,
                        config: config
                    ))

                    currentSentences = []
                    currentSize = 0
                    chunkStartPosition = chunkEndPosition + 1
                }

                // Split long sentence into word-based chunks
                let wordChunks = try WordChunker().chunk(text: sentence, config: config)

                for wordChunk in wordChunks {
                    let adjustedMetadata = ChunkMetadata(
                        index: chunks.count,
                        startPosition: chunkStartPosition,
                        endPosition: chunkStartPosition + wordChunk.text.count,
                        hasOverlapWithPrevious: chunks.count > 0,
                        hasOverlapWithNext: true,
                        contentType: config.contentType,
                        source: nil
                    )
                    chunks.append(Chunk(text: wordChunk.text, metadata: adjustedMetadata))
                    chunkStartPosition += wordChunk.text.count + 1
                }
                continue
            }

            // Check if adding this sentence would exceed the chunk size
            if currentSize + sentenceSize > config.chunkSize && !currentSentences.isEmpty {
                // Create chunk from accumulated sentences
                let chunkText = currentSentences.joined(separator: " ")
                let chunkEndPosition = chunkStartPosition + chunkText.count

                chunks.append(createChunk(
                    text: chunkText,
                    index: chunks.count,
                    startPosition: chunkStartPosition,
                    endPosition: chunkEndPosition,
                    hasNext: idx < sentences.count - 1,
                    config: config
                ))

                // Handle overlap
                if config.overlapSize > 0 && idx < sentences.count - 1 {
                    let overlap = calculateOverlap(currentSentences, targetSize: config.overlapSize)
                    currentSentences = overlap.sentences
                    currentSize = overlap.size
                    chunkStartPosition = chunkEndPosition - currentSize
                } else {
                    currentSentences = []
                    currentSize = 0
                    chunkStartPosition = chunkEndPosition + 1
                }
            }

            currentSentences.append(sentence)
            currentSize += sentenceSize + (currentSentences.count > 1 ? 1 : 0)
        }

        // Add remaining sentences as final chunk
        if !currentSentences.isEmpty {
            let chunkText = currentSentences.joined(separator: " ")
            let chunkEndPosition = chunkStartPosition + chunkText.count

            chunks.append(createChunk(
                text: chunkText,
                index: chunks.count,
                startPosition: chunkStartPosition,
                endPosition: chunkEndPosition,
                hasNext: false,
                config: config
            ))
        }

        return chunks
    }

    private func extractSentences(from text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }

        return sentences
    }

    private func createChunk(
        text: String,
        index: Int,
        startPosition: Int,
        endPosition: Int,
        hasNext: Bool,
        config: ChunkingConfig
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

    private func calculateOverlap(_ sentences: [String], targetSize: Int) -> (sentences: [String], size: Int) {
        var overlapSentences: [String] = []
        var overlapSize = 0

        for sentence in sentences.reversed() {
            if overlapSize + sentence.count <= targetSize {
                overlapSentences.insert(sentence, at: 0)
                overlapSize += sentence.count + (overlapSentences.count > 1 ? 1 : 0)
            } else {
                break
            }
        }

        return (overlapSentences, overlapSize)
    }
}
