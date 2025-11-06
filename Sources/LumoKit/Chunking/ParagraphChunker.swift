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
            return try SentenceChunker().chunk(text: text, config: config)
        }

        var chunks: [Chunk] = []
        var currentParagraphs: [String] = []
        var currentSize = 0
        var chunkStartPosition = 0

        for (idx, paragraph) in paragraphs.enumerated() {
            let paragraphSize = paragraph.count

            // If a single paragraph exceeds chunk size, use sentence chunking
            if paragraphSize > config.chunkSize {
                // Flush current chunk if any
                if !currentParagraphs.isEmpty {
                    let chunkText = currentParagraphs.joined(separator: "\n\n")
                    let chunkEndPosition = chunkStartPosition + chunkText.count

                    chunks.append(createChunk(
                        text: chunkText,
                        index: chunks.count,
                        startPosition: chunkStartPosition,
                        endPosition: chunkEndPosition,
                        hasNext: true,
                        config: config
                    ))

                    currentParagraphs = []
                    currentSize = 0
                    chunkStartPosition = chunkEndPosition + 2 // +2 for double newline
                }

                // Split long paragraph using sentence chunker
                let sentenceChunks = try SentenceChunker().chunk(
                    text: paragraph,
                    config: config
                )

                for sentenceChunk in sentenceChunks {
                    let adjustedMetadata = ChunkMetadata(
                        index: chunks.count,
                        startPosition: chunkStartPosition,
                        endPosition: chunkStartPosition + sentenceChunk.text.count,
                        hasOverlapWithPrevious: chunks.count > 0,
                        hasOverlapWithNext: true,
                        contentType: config.contentType,
                        source: nil
                    )
                    chunks.append(Chunk(text: sentenceChunk.text, metadata: adjustedMetadata))
                    chunkStartPosition += sentenceChunk.text.count + 2
                }
                continue
            }

            // Check if adding this paragraph would exceed the chunk size
            if currentSize + paragraphSize > config.chunkSize && !currentParagraphs.isEmpty {
                // Create chunk from accumulated paragraphs
                let chunkText = currentParagraphs.joined(separator: "\n\n")
                let chunkEndPosition = chunkStartPosition + chunkText.count

                chunks.append(createChunk(
                    text: chunkText,
                    index: chunks.count,
                    startPosition: chunkStartPosition,
                    endPosition: chunkEndPosition,
                    hasNext: idx < paragraphs.count - 1,
                    config: config
                ))

                // Handle overlap
                if config.overlapSize > 0 && idx < paragraphs.count - 1 {
                    let overlap = calculateOverlap(currentParagraphs, targetSize: config.overlapSize)
                    currentParagraphs = overlap.paragraphs
                    currentSize = overlap.size
                    chunkStartPosition = chunkEndPosition - currentSize
                } else {
                    currentParagraphs = []
                    currentSize = 0
                    chunkStartPosition = chunkEndPosition + 2
                }
            }

            currentParagraphs.append(paragraph)
            currentSize += paragraphSize + (currentParagraphs.count > 1 ? 2 : 0) // +2 for \n\n
        }

        // Add remaining paragraphs as final chunk
        if !currentParagraphs.isEmpty {
            let chunkText = currentParagraphs.joined(separator: "\n\n")
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

    private func extractParagraphs(from text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .paragraph)
        tokenizer.string = text

        var paragraphs: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let paragraph = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !paragraph.isEmpty {
                paragraphs.append(paragraph)
            }
            return true
        }

        return paragraphs
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

    private func calculateOverlap(_ paragraphs: [String], targetSize: Int) -> (paragraphs: [String], size: Int) {
        var overlapParagraphs: [String] = []
        var overlapSize = 0

        for paragraph in paragraphs.reversed() {
            if overlapSize + paragraph.count <= targetSize {
                overlapParagraphs.insert(paragraph, at: 0)
                overlapSize += paragraph.count + (overlapParagraphs.count > 1 ? 2 : 0)
            } else {
                break
            }
        }

        return (overlapParagraphs, overlapSize)
    }
}
