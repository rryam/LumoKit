import Foundation
import NaturalLanguage

/// Paragraph-based chunking strategy
struct ParagraphChunker: ChunkingStrategy {
    func chunk(text: String, config: ChunkingConfig) throws -> [Chunk] {
        try ChunkingHelper.validateChunkSize(config.chunkSize)

        guard !text.isEmpty else { return [] }

        // Extract paragraphs
        let paragraphs = extractParagraphs(from: text)
        guard !paragraphs.isEmpty else {
            // Fallback to sentence chunking if no paragraphs detected
            do {
                return try SentenceChunker().chunk(text: text, config: config)
            } catch {
                throw ChunkingHelper.wrapChunkingError(
                    error,
                    strategyName: "ParagraphChunker (fallback to SentenceChunker)"
                )
            }
        }

        var chunks: [Chunk] = []
        var currentParagraphs: [(text: String, range: Range<String.Index>)] = []
        var currentSize = 0

        for (idx, paragraphData) in paragraphs.enumerated() {
            let paragraph = paragraphData.paragraph
            let paragraphSize = paragraph.count

            // If a single paragraph exceeds chunk size, use sentence chunking
            if paragraphSize > config.chunkSize {
                // Flush current chunk if any
                if !currentParagraphs.isEmpty {
                    flushChunk(from: currentParagraphs, to: &chunks, text: text, config: config, hasNext: true)
                    currentParagraphs = []
                    currentSize = 0
                }

                // Split long paragraph using sentence chunker
                do {
                    let sentenceChunks = try SentenceChunker().chunk(
                        text: paragraph,
                        config: config
                    )

                    for sentenceChunk in sentenceChunks {
                        let baseOffset = text.distance(from: text.startIndex, to: paragraphData.range.lowerBound)
                        let adjustedMetadata = ChunkMetadata(
                            index: chunks.count,
                            startPosition: baseOffset + sentenceChunk.metadata.startPosition,
                            endPosition: baseOffset + sentenceChunk.metadata.endPosition,
                            hasOverlapWithPrevious: chunks.count > 0,
                            hasOverlapWithNext: true,
                            contentType: config.contentType,
                            source: nil
                        )
                        chunks.append(Chunk(text: sentenceChunk.text, metadata: adjustedMetadata))
                    }
                } catch {
                    throw ChunkingHelper.wrapChunkingError(
                        error,
                        strategyName: "ParagraphChunker (fallback to SentenceChunker for oversized paragraph)"
                    )
                }
            }

            // Check if adding this paragraph would exceed the chunk size
            if currentSize + paragraphSize > config.chunkSize && !currentParagraphs.isEmpty {
                flushChunk(
                    from: currentParagraphs,
                    to: &chunks,
                    text: text,
                    config: config,
                    hasNext: idx < paragraphs.count - 1
                )

                // Handle overlap
                if config.overlapSize > 0 && idx < paragraphs.count - 1 {
                    let overlap = ChunkingHelper.calculateOverlap(
                        currentParagraphs.map { $0.text },
                        targetSize: config.overlapSize,
                        separator: 2
                    )
                    let overlapCount = overlap.segments.count
                    currentParagraphs = overlapCount > 0 ? Array(currentParagraphs.suffix(overlapCount)) : []
                    currentSize = overlap.size
                } else {
                    currentParagraphs = []
                    currentSize = 0
                }
            }

            currentParagraphs.append((paragraph, paragraphData.range))
            currentSize += paragraphSize + (currentParagraphs.count > 1 ? 2 : 0) // +2 for \n\n
        }

        // Add remaining paragraphs as final chunk
        if !currentParagraphs.isEmpty {
            flushChunk(from: currentParagraphs, to: &chunks, text: text, config: config, hasNext: false)
        }

        return chunks
    }

    private func extractParagraphs(from text: String) -> [(paragraph: String, range: Range<String.Index>)] {
        let tokenizer = NLTokenizer(unit: .paragraph)
        tokenizer.string = text

        var paragraphs: [(paragraph: String, range: Range<String.Index>)] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let paragraph = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                paragraphs.append((paragraph, range))
            }
            return true
        }

        return paragraphs
    }

    private func flushChunk(
        from paragraphs: [(text: String, range: Range<String.Index>)],
        to chunks: inout [Chunk],
        text: String,
        config: ChunkingConfig,
        hasNext: Bool
    ) {
        guard let firstRange = paragraphs.first?.range,
              let lastRange = paragraphs.last?.range else {
            return
        }

        let chunkText = paragraphs.map { $0.text }.joined(separator: "\n\n")
        let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
        let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

        let metadata = ChunkMetadata(
            index: chunks.count,
            startPosition: startPos,
            endPosition: endPos,
            hasOverlapWithPrevious: chunks.count > 0 && config.overlapSize > 0,
            hasOverlapWithNext: hasNext,
            contentType: config.contentType,
            source: nil
        )
        chunks.append(Chunk(text: chunkText, metadata: metadata))
    }

}
