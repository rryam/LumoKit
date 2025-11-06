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
        var currentParagraphs: [(text: String, range: Range<String.Index>)] = []
        var currentSize = 0

        for (idx, paragraphData) in paragraphs.enumerated() {
            let paragraph = paragraphData.paragraph
            let paragraphSize = paragraph.count

            // If a single paragraph exceeds chunk size, use sentence chunking
            if paragraphSize > config.chunkSize {
                // Flush current chunk if any
                if !currentParagraphs.isEmpty {
                    let firstRange = currentParagraphs.first!.range
                    let lastRange = currentParagraphs.last!.range
                    let chunkText = currentParagraphs.map { $0.text }.joined(separator: "\n\n")
                    let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
                    let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

                    let metadata = ChunkMetadata(
                        index: chunks.count,
                        startPosition: startPos,
                        endPosition: endPos,
                        hasOverlapWithPrevious: chunks.count > 0 && config.overlapSize > 0,
                        hasOverlapWithNext: true,
                        contentType: config.contentType,
                        source: nil
                    )
                    chunks.append(Chunk(text: chunkText, metadata: metadata))

                    currentParagraphs = []
                    currentSize = 0
                }

                // Split long paragraph using sentence chunker
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
                continue
            }

            // Check if adding this paragraph would exceed the chunk size
            if currentSize + paragraphSize > config.chunkSize && !currentParagraphs.isEmpty {
                // Create chunk from accumulated paragraphs
                let firstRange = currentParagraphs.first!.range
                let lastRange = currentParagraphs.last!.range
                let chunkText = currentParagraphs.map { $0.text }.joined(separator: "\n\n")
                let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
                let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

                let metadata = ChunkMetadata(
                    index: chunks.count,
                    startPosition: startPos,
                    endPosition: endPos,
                    hasOverlapWithPrevious: chunks.count > 0 && config.overlapSize > 0,
                    hasOverlapWithNext: idx < paragraphs.count - 1,
                    contentType: config.contentType,
                    source: nil
                )
                chunks.append(Chunk(text: chunkText, metadata: metadata))

                // Handle overlap
                if config.overlapSize > 0 && idx < paragraphs.count - 1 {
                    let overlap = calculateOverlap(currentParagraphs.map { $0.text }, targetSize: config.overlapSize)
                    let overlapCount = overlap.paragraphs.count
                    currentParagraphs = Array(currentParagraphs.suffix(overlapCount))
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
            let firstRange = currentParagraphs.first!.range
            let lastRange = currentParagraphs.last!.range
            let chunkText = currentParagraphs.map { $0.text }.joined(separator: "\n\n")
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
