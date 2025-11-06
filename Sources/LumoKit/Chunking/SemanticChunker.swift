import Foundation
import NaturalLanguage

/// Semantic chunking strategy with intelligent boundary detection
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
        // For prose, prefer paragraph boundaries, then sentences
        let paragraphs = extractParagraphs(from: text)

        if paragraphs.count > 1 {
            return try ParagraphChunker().chunk(text: text, config: config)
        } else {
            return try SentenceChunker().chunk(text: text, config: config)
        }
    }

    // MARK: - Code Chunking

    private func chunkCode(text: String, config: ChunkingConfig) throws -> [Chunk] {
        // For code, respect logical blocks (functions, classes, etc.)
        let lines = splitLinesWithRanges(from: text)
        let blocks = groupCodeIntoLogicalBlocks(lines)

        var chunks: [Chunk] = []
        var currentBlock: [(line: String, range: Range<String.Index>)] = []
        var currentSize = 0

        for (idx, block) in blocks.enumerated() {
            let blockText = block.map { $0.line }.joined(separator: "\n")
            let blockSize = blockText.count

            if blockSize > config.chunkSize {
                // Flush current
                if !currentBlock.isEmpty,
                   let firstRange = currentBlock.first?.range,
                   let lastRange = currentBlock.last?.range {
                    let chunkText = currentBlock.map { $0.line }.joined(separator: "\n")
                    let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
                    let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

                    chunks.append(createChunk(
                        text: chunkText,
                        index: chunks.count,
                        startPosition: startPos,
                        endPosition: endPos,
                        config: config
                    ))
                    currentBlock = []
                    currentSize = 0
                }

                // Split large block by lines
                if let firstRange = block.first?.range,
                   let lastRange = block.last?.range {
                    let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
                    let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)
                    chunks.append(createChunk(
                        text: blockText,
                        index: chunks.count,
                        startPosition: startPos,
                        endPosition: endPos,
                        config: config
                    ))
                }
                continue
            }

            if currentSize + blockSize > config.chunkSize && !currentBlock.isEmpty,
               let firstRange = currentBlock.first?.range,
               let lastRange = currentBlock.last?.range {
                let chunkText = currentBlock.map { $0.line }.joined(separator: "\n")
                let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
                let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

                chunks.append(createChunk(
                    text: chunkText,
                    index: chunks.count,
                    startPosition: startPos,
                    endPosition: endPos,
                    config: config
                ))

                // Overlap handling for code
                if config.overlapSize > 0 && idx < blocks.count - 1 {
                    let overlapLines = currentBlock.suffix(min(3, currentBlock.count))
                    currentBlock = Array(overlapLines)
                    currentSize = currentBlock.map { $0.line }.joined(separator: "\n").count
                } else {
                    currentBlock = []
                    currentSize = 0
                }
            }

            currentBlock.append(contentsOf: block)
            currentSize += blockSize + (currentBlock.count > 1 ? 1 : 0)
        }

        if !currentBlock.isEmpty,
           let firstRange = currentBlock.first?.range,
           let lastRange = currentBlock.last?.range {
            let chunkText = currentBlock.map { $0.line }.joined(separator: "\n")
            let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
            let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

            chunks.append(createChunk(
                text: chunkText,
                index: chunks.count,
                startPosition: startPos,
                endPosition: endPos,
                config: config
            ))
        }

        return chunks
    }

    // MARK: - Markdown Chunking

    private func chunkMarkdown(text: String, config: ChunkingConfig) throws -> [Chunk] {
        let sections = extractMarkdownSections(from: text)

        var chunks: [Chunk] = []
        var currentSections: [(section: String, range: Range<String.Index>)] = []
        var currentSize = 0

        for (idx, sectionData) in sections.enumerated() {
            let sectionSize = sectionData.section.count

            if sectionSize > config.chunkSize {
                // Flush current
                if !currentSections.isEmpty,
                   let firstRange = currentSections.first?.range,
                   let lastRange = currentSections.last?.range {
                    let chunkText = currentSections.map { $0.section }.joined(separator: "\n\n")
                    let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
                    let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

                    chunks.append(createChunk(
                        text: chunkText,
                        index: chunks.count,
                        startPosition: startPos,
                        endPosition: endPos,
                        config: config
                    ))
                    currentSections = []
                    currentSize = 0
                }

                // Use sentence chunking for large sections
                let sentenceChunks = try SentenceChunker().chunk(text: sectionData.section, config: config)
                let baseOffset = text.distance(from: text.startIndex, to: sectionData.range.lowerBound)
                for sentenceChunk in sentenceChunks {
                    chunks.append(Chunk(
                        text: sentenceChunk.text,
                        metadata: ChunkMetadata(
                            index: chunks.count,
                            startPosition: baseOffset + sentenceChunk.metadata.startPosition,
                            endPosition: baseOffset + sentenceChunk.metadata.endPosition,
                            hasOverlapWithPrevious: chunks.count > 0,
                            hasOverlapWithNext: true,
                            contentType: .markdown,
                            source: nil
                        )
                    ))
                }
                continue
            }

            if currentSize + sectionSize > config.chunkSize && !currentSections.isEmpty,
               let firstRange = currentSections.first?.range,
               let lastRange = currentSections.last?.range {
                let chunkText = currentSections.map { $0.section }.joined(separator: "\n\n")
                let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
                let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

                chunks.append(createChunk(
                    text: chunkText,
                    index: chunks.count,
                    startPosition: startPos,
                    endPosition: endPos,
                    config: config
                ))

                if config.overlapSize > 0 && idx < sections.count - 1 {
                    let overlap = currentSections.suffix(1)
                    currentSections = Array(overlap)
                    currentSize = currentSections.map { $0.section }.joined(separator: "\n\n").count
                } else {
                    currentSections = []
                    currentSize = 0
                }
            }

            currentSections.append(sectionData)
            currentSize += sectionSize + (currentSections.count > 1 ? 2 : 0)
        }

        if !currentSections.isEmpty,
           let firstRange = currentSections.first?.range,
           let lastRange = currentSections.last?.range {
            let chunkText = currentSections.map { $0.section }.joined(separator: "\n\n")
            let startPos = text.distance(from: text.startIndex, to: firstRange.lowerBound)
            let endPos = text.distance(from: text.startIndex, to: lastRange.upperBound)

            chunks.append(createChunk(
                text: chunkText,
                index: chunks.count,
                startPosition: startPos,
                endPosition: endPos,
                config: config
            ))
        }

        return chunks
    }

    // MARK: - Mixed Content Chunking

    private func chunkMixed(text: String, config: ChunkingConfig) throws -> [Chunk] {
        // Detect code blocks and split accordingly
        let segments = separateCodeAndProse(text)

        var chunks: [Chunk] = []

        for segment in segments {
            let segmentConfig = ChunkingConfig(
                chunkSize: config.chunkSize,
                overlapPercentage: config.overlapPercentage,
                strategy: config.strategy,
                contentType: segment.isCode ? .code : .prose
            )

            let segmentChunks = try chunk(text: segment.content, config: segmentConfig)
            let baseOffset = text.distance(from: text.startIndex, to: segment.range.lowerBound)

            for segmentChunk in segmentChunks {
                let adjustedMetadata = ChunkMetadata(
                    index: chunks.count,
                    startPosition: baseOffset + segmentChunk.metadata.startPosition,
                    endPosition: baseOffset + segmentChunk.metadata.endPosition,
                    hasOverlapWithPrevious: chunks.count > 0,
                    hasOverlapWithNext: true,
                    contentType: segment.isCode ? .code : .prose,
                    source: nil
                )
                chunks.append(Chunk(text: segmentChunk.text, metadata: adjustedMetadata))
            }
        }

        return chunks
    }

    // MARK: - Helper Methods

    private func splitLinesWithRanges(from text: String) -> [(line: String, range: Range<String.Index>)] {
        var result: [(line: String, range: Range<String.Index>)] = []
        var currentIndex = text.startIndex

        text.enumerateLines { line, _ in
            guard currentIndex < text.endIndex else { return }

            let lineEndIndex = text.index(
                currentIndex,
                offsetBy: line.utf16.count,
                limitedBy: text.endIndex
            ) ?? text.endIndex
            let range = currentIndex..<lineEndIndex
            result.append((line, range))

            // Move past the newline character if present
            if lineEndIndex < text.endIndex {
                currentIndex = text.index(after: lineEndIndex)
            } else {
                currentIndex = lineEndIndex
            }
        }

        return result
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

    private func groupCodeIntoLogicalBlocks(
        _ lines: [(line: String, range: Range<String.Index>)]
    ) -> [[(line: String, range: Range<String.Index>)]] {
        var blocks: [[(line: String, range: Range<String.Index>)]] = []
        var currentBlock: [(line: String, range: Range<String.Index>)] = []

        for lineData in lines {
            let trimmed = lineData.line.trimmingCharacters(in: .whitespaces)

            // Start new block on function/class definitions or empty lines
            if trimmed.isEmpty && !currentBlock.isEmpty {
                blocks.append(currentBlock)
                currentBlock = []
            } else {
                currentBlock.append(lineData)
            }
        }

        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }

        return blocks.isEmpty ? [lines] : blocks
    }

    private func extractMarkdownSections(from text: String) -> [(section: String, range: Range<String.Index>)] {
        let lines = splitLinesWithRanges(from: text)
        var sections: [(section: String, range: Range<String.Index>)] = []
        var currentSection: [(line: String, range: Range<String.Index>)] = []

        for lineData in lines {
            // New section starts with a header
            if lineData.line.hasPrefix("#") && !currentSection.isEmpty {
                let sectionText = currentSection.map { $0.line }.joined(separator: "\n")
                if let firstRange = currentSection.first?.range,
                   let lastRange = currentSection.last?.range {
                    sections.append((sectionText, firstRange.lowerBound..<lastRange.upperBound))
                }
                currentSection = [lineData]
            } else {
                currentSection.append(lineData)
            }
        }

        if !currentSection.isEmpty {
            let sectionText = currentSection.map { $0.line }.joined(separator: "\n")
            if let firstRange = currentSection.first?.range,
               let lastRange = currentSection.last?.range {
                sections.append((sectionText, firstRange.lowerBound..<lastRange.upperBound))
            }
        }

        return sections.isEmpty ? [(text, text.startIndex..<text.endIndex)] : sections
    }

    private struct ContentSegment {
        let content: String
        let range: Range<String.Index>
        let isCode: Bool
    }

    private func separateCodeAndProse(_ text: String) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        var currentContent: [(line: String, range: Range<String.Index>)] = []
        var inCodeBlock = false

        let lines = splitLinesWithRanges(from: text)

        for lineData in lines {
            if lineData.line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                // Save current segment
                if !currentContent.isEmpty,
                   let firstRange = currentContent.first?.range,
                   let lastRange = currentContent.last?.range {
                    segments.append(ContentSegment(
                        content: currentContent.map { $0.line }.joined(separator: "\n"),
                        range: firstRange.lowerBound..<lastRange.upperBound,
                        isCode: inCodeBlock
                    ))
                    currentContent = []
                }
                inCodeBlock.toggle()
                currentContent.append(lineData)
            } else {
                currentContent.append(lineData)
            }
        }

        if !currentContent.isEmpty,
           let firstRange = currentContent.first?.range,
           let lastRange = currentContent.last?.range {
            segments.append(ContentSegment(
                content: currentContent.map { $0.line }.joined(separator: "\n"),
                range: firstRange.lowerBound..<lastRange.upperBound,
                isCode: inCodeBlock
            ))
        }

        return segments.isEmpty
            ? [ContentSegment(content: text, range: text.startIndex..<text.endIndex, isCode: false)]
            : segments
    }

    private func createChunk(
        text: String,
        index: Int,
        startPosition: Int,
        endPosition: Int,
        config: ChunkingConfig
    ) -> Chunk {
        let metadata = ChunkMetadata(
            index: index,
            startPosition: startPosition,
            endPosition: endPosition,
            hasOverlapWithPrevious: index > 0 && config.overlapSize > 0,
            hasOverlapWithNext: false,
            contentType: config.contentType,
            source: nil
        )
        return Chunk(text: text, metadata: metadata)
    }
}
