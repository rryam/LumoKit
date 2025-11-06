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
            do {
                return try WordChunker().chunk(text: text, config: config)
            } catch {
                throw ChunkingHelper.wrapChunkingError(error, strategyName: "SentenceChunker (fallback to WordChunker)")
            }
        }

        var chunks: [Chunk] = []
        var currentSentences: [(text: String, range: Range<String.Index>)] = []
        var currentSize = 0

        for (idx, sentenceData) in sentences.enumerated() {
            let sentence = sentenceData.sentence
            let sentenceSize = sentence.count

            // If a single sentence exceeds chunk size, split it by words
            if sentenceSize > config.chunkSize {
                // Flush current chunk if any
                if !currentSentences.isEmpty {
                    flushChunk(from: currentSentences, to: &chunks, text: text, config: config, hasNext: true)
                    currentSentences = []
                    currentSize = 0
                }

                // Split long sentence into word-based chunks
                do {
                    let wordChunks = try WordChunker().chunk(text: sentence, config: config)

                    for wordChunk in wordChunks {
                        let baseOffset = text.distance(from: text.startIndex, to: sentenceData.range.lowerBound)
                        let adjustedMetadata = ChunkMetadata(
                            index: chunks.count,
                            startPosition: baseOffset + wordChunk.metadata.startPosition,
                            endPosition: baseOffset + wordChunk.metadata.endPosition,
                            hasOverlapWithPrevious: chunks.count > 0,
                            hasOverlapWithNext: true,
                            contentType: config.contentType,
                            source: nil
                        )
                        chunks.append(Chunk(text: wordChunk.text, metadata: adjustedMetadata))
                    }
                } catch {
                    throw ChunkingHelper.wrapChunkingError(
                        error,
                        strategyName: "SentenceChunker (fallback to WordChunker for oversized sentence)"
                    )
                }
                continue
            }

            // Check if adding this sentence would exceed the chunk size
            if currentSize + sentenceSize > config.chunkSize && !currentSentences.isEmpty {
                flushChunk(
                    from: currentSentences,
                    to: &chunks,
                    text: text,
                    config: config,
                    hasNext: idx < sentences.count - 1
                )

                // Handle overlap
                if config.overlapSize > 0 && idx < sentences.count - 1 {
                    let overlap = ChunkingHelper.calculateOverlap(
                        currentSentences.map { $0.text },
                        targetSize: config.overlapSize
                    )
                    let overlapCount = overlap.segments.count
                    currentSentences = overlapCount > 0 ? Array(currentSentences.suffix(overlapCount)) : []
                    currentSize = overlap.size
                } else {
                    currentSentences = []
                    currentSize = 0
                }
            }

            currentSentences.append((sentence, sentenceData.range))
            currentSize += sentenceSize + (currentSentences.count > 1 ? ChunkingHelper.Constants.spaceSeparatorSize : 0)
        }

        // Add remaining sentences as final chunk
        if !currentSentences.isEmpty {
            flushChunk(from: currentSentences, to: &chunks, text: text, config: config, hasNext: false)
        }

        return chunks
    }

    private func extractSentences(from text: String) -> [(sentence: String, range: Range<String.Index>)] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [(sentence: String, range: Range<String.Index>)] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append((sentence, range))
            }
            return true
        }

        return sentences
    }

    private func flushChunk(
        from sentences: [(text: String, range: Range<String.Index>)],
        to chunks: inout [Chunk],
        text: String,
        config: ChunkingConfig,
        hasNext: Bool
    ) {
        guard let chunk = ChunkingHelper.createChunkFromSegments(
            segments: sentences,
            separator: ChunkingHelper.Constants.spaceSeparator,
            textExtractor: { $0.text },
            rangeExtractor: { $0.range },
            text: text,
            chunks: chunks,
            config: config,
            hasNext: hasNext
        ) else {
            return
        }
        chunks.append(chunk)
    }

}
